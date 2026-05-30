#!/usr/bin/env bash
# semantic-cache.sh — Semantic caching, result deduplication, cache cleanup
#
# Functions:
#   check_cache_semantic    — Bigram-based fuzzy cache lookup
#   save_to_cache_semantic  — Save cache entry with bigrams for semantic matching
#   deduplicate_results     — Heading-based duplicate detection across result files
#   get_cache_key           — SHA-256 cache key from prompt text
#   check_cache             — Check if cached result exists and is within TTL
#   get_cached_result       — Read cached result file
#   save_to_cache           — Write result file to cache with timestamp
#   cleanup_cache           — Remove expired cache entries beyond TTL
#   cleanup_old_results     — Age-based cleanup of per-agent result files
#
# Extracted from orchestrate.sh (v9.7.8)
# Source-safe: no main execution block.

# ═══════════════════════════════════════════════════════════════════════════════
# PERFORMANCE: Semantic probe cache (v8.7.0)
# Bigram-based fuzzy matching for cache lookups
# Config: OCTOPUS_SEMANTIC_CACHE=false, OCTOPUS_CACHE_SIMILARITY_THRESHOLD=0.7
# ═══════════════════════════════════════════════════════════════════════════════
OCTOPUS_SEMANTIC_CACHE="${OCTOPUS_SEMANTIC_CACHE:-false}"
OCTOPUS_CACHE_SIMILARITY_THRESHOLD="${OCTOPUS_CACHE_SIMILARITY_THRESHOLD:-0.7}"

octopus_resolve_cache_dir() {
    if [[ -n "${CACHE_DIR:-}" && "$CACHE_DIR" != "/.cache/probe-results" ]]; then
        printf '%s\n' "$CACHE_DIR"
        return 0
    fi

    local base="${WORKSPACE_DIR:-}"
    if [[ -z "$base" || "$base" == "/" ]]; then
        base="${HOME:-}"
    fi
    if [[ -z "$base" || "$base" == "/" ]]; then
        base="$(pwd)"
    fi

    printf '%s/.cache/probe-results\n' "${base%/}"
}

check_cache_semantic() {
    local prompt="$1"

    [[ "$OCTOPUS_SEMANTIC_CACHE" != "true" ]] && return 1
    local cache_dir
    cache_dir=$(octopus_resolve_cache_dir)
    [[ ! -d "$cache_dir" ]] && return 1

    # Try exact match first
    local cache_key
    cache_key=$(get_cache_key "$prompt")
    if check_cache "$cache_key" 2>/dev/null; then
        echo "$cache_key"
        return 0
    fi

    # Scan bigram files for fuzzy matches
    local best_key=""
    local best_sim="0"
    local current_scope
    current_scope=$(octopus_cache_scope_key 2>/dev/null || echo "unknown")
    for bigram_file in "${cache_dir}"/*.bigrams; do
        [[ ! -f "$bigram_file" ]] && continue
        local scope_file="${bigram_file%.bigrams}.scope"
        [[ -f "$scope_file" ]] || continue
        [[ "$(cat "$scope_file" 2>/dev/null || true)" == "$current_scope" ]] || continue

        local cached_prompt
        cached_prompt=$(cat "$bigram_file" 2>/dev/null || true)
        [[ -z "$cached_prompt" ]] && continue

        local sim
        sim=$(bigram_similarity "$prompt" "$cached_prompt")

        if awk -v s="$sim" -v t="$OCTOPUS_CACHE_SIMILARITY_THRESHOLD" -v b="$best_sim" \
           'BEGIN { exit !(s >= t && s > b) }'; then
            best_sim="$sim"
            best_key="${bigram_file%.bigrams}"
            best_key="${best_key##*/}"
        fi
    done

    if [[ -n "$best_key" ]]; then
        log "DEBUG" "Semantic cache hit: similarity=$best_sim for key=$best_key"
        echo "$best_key"
        return 0
    fi

    return 1
}

save_to_cache_semantic() {
    local cache_key="$1"
    local result_file="$2"
    local prompt="$3"

    # Save regular cache entry
    save_to_cache "$cache_key" "$result_file"

    # Save bigrams file for semantic matching
    if [[ "$OCTOPUS_SEMANTIC_CACHE" == "true" ]]; then
        local cache_dir
        cache_dir=$(octopus_resolve_cache_dir)
        mkdir -p "$cache_dir"
        echo "$prompt" > "${cache_dir}/${cache_key}.bigrams"
        octopus_cache_scope_key > "${cache_dir}/${cache_key}.scope"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# PERFORMANCE: Result deduplication and context budget (v8.7.0)
# Dedup: Heading-based duplicate detection (log-only in v8.7.0)
# Context budget: Truncate prompts to token limit before sending to agents
# Config: OCTOPUS_DEDUP_ENABLED=false, OCTOPUS_CONTEXT_BUDGET=12000
# ═══════════════════════════════════════════════════════════════════════════════
OCTOPUS_DEDUP_ENABLED="${OCTOPUS_DEDUP_ENABLED:-false}"
OCTOPUS_CONTEXT_BUDGET="${OCTOPUS_CONTEXT_BUDGET:-12000}"

deduplicate_results() {
    local files=("$@")

    [[ "$OCTOPUS_DEDUP_ENABLED" != "true" ]] && return 0
    [[ ${#files[@]} -lt 2 ]] && return 0

    local i j
    for (( i=0; i < ${#files[@]}; i++ )); do
        [[ ! -f "${files[$i]}" ]] && continue
        for (( j=i+1; j < ${#files[@]}; j++ )); do
            [[ ! -f "${files[$j]}" ]] && continue
            local headings_a headings_b sim
            headings_a=$(extract_headings "${files[$i]}")
            headings_b=$(extract_headings "${files[$j]}")
            sim=$(jaccard_similarity "$headings_a" "$headings_b")
            if awk -v s="$sim" 'BEGIN { exit !(s >= 0.9) }'; then
                log "INFO" "DEDUP: High similarity ($sim) between ${files[$i]##*/} and ${files[$j]##*/} (log-only in v8.7.0)"
            fi
        done
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# CACHE: Core cache operations (v8.0.0)
# Key generation, freshness checks, storage, and cleanup
# Config: CACHE_DIR, CACHE_TTL
# ═══════════════════════════════════════════════════════════════════════════════

octopus_cache_scope_key() {
    local root="${WORKSPACE_DIR:-}"
    if [[ -z "$root" ]]; then
        root=$(git rev-parse --show-toplevel 2>/dev/null || true)
    fi
    [[ -z "$root" ]] && root="$(pwd)"

    local normalized_root
    normalized_root=$(cd "$root" 2>/dev/null && pwd -P) || normalized_root="$root"

    local branch="nogit"
    branch=$(git -C "$normalized_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "nogit")

    local commit="nogit"
    commit=$(git -C "$normalized_root" rev-parse --verify HEAD 2>/dev/null || echo "nogit")

    printf '%s|%s|%s' "$normalized_root" "$branch" "$commit"
}

get_cache_key() {
    local prompt="$1"
    printf '%s\n%s' "$(octopus_cache_scope_key)" "$prompt" | shasum -a 256 | cut -d' ' -f1
}

# Check if cached result exists and is fresh
check_cache() {
    local cache_key="$1"
    local cache_dir
    cache_dir=$(octopus_resolve_cache_dir)
    local cache_file="${cache_dir}/${cache_key}.md"
    local cache_meta="${cache_dir}/${cache_key}.meta"

    # Check if cache files exist
    [[ ! -f "$cache_file" ]] && return 1
    [[ ! -f "$cache_meta" ]] && return 1

    # Check if cache is still valid (within TTL)
    local cache_time
    cache_time=$(cat "$cache_meta" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))

    if [[ $age -lt $CACHE_TTL ]]; then
        log "INFO" "Cache hit! Age: ${age}s (TTL: ${CACHE_TTL}s)"
        return 0
    else
        log "DEBUG" "Cache expired. Age: ${age}s > TTL: ${CACHE_TTL}s"
        return 1
    fi
}

# Get cached result
get_cached_result() {
    local cache_key="$1"
    local cache_dir
    cache_dir=$(octopus_resolve_cache_dir)
    local cache_file="${cache_dir}/${cache_key}.md"
    cat "$cache_file"
}

# Save result to cache
save_to_cache() {
    local cache_key="$1"
    local result_file="$2"
    local cache_dir
    cache_dir=$(octopus_resolve_cache_dir)
    local cache_file="${cache_dir}/${cache_key}.md"
    local cache_meta="${cache_dir}/${cache_key}.meta"

    mkdir -p "$cache_dir"

    # Copy result to cache
    cp "$result_file" "$cache_file"

    # Store timestamp
    date +%s > "$cache_meta"

    log "DEBUG" "Saved to cache: $cache_key"
}

# Clean up expired cache entries
cleanup_cache() {
    local cache_dir
    cache_dir=$(octopus_resolve_cache_dir)
    [[ ! -d "$cache_dir" ]] && return 0

    local current_time=$(date +%s)
    local cleaned=0

    for meta_file in "$cache_dir"/*.meta; do
        [[ ! -f "$meta_file" ]] && continue

        local cache_time
        cache_time=$(cat "$meta_file" 2>/dev/null || echo "0")
        local age=$((current_time - cache_time))

        if [[ $age -gt $CACHE_TTL ]]; then
            local base="${meta_file%.meta}"
            rm -f "$base.md" "$meta_file"
            ((cleaned++)) || true
        fi
    done

    [[ $cleaned -gt 0 ]] && log "INFO" "Cleaned $cleaned expired cache entries" || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# RESULT FILE CLEANUP (v8.49.0)
# Age-based cleanup of per-agent result files after synthesis.
# Keeps synthesis files; removes ephemeral per-agent outputs older than retention.
# Config: OCTOPUS_RESULT_RETENTION_HOURS (default: 24)
# ═══════════════════════════════════════════════════════════════════════════════

cleanup_old_results() {
    [[ "$DRY_RUN" == "true" ]] && return 0
    [[ ! -d "$RESULTS_DIR" ]] && return 0

    local retention_hours="${OCTOPUS_RESULT_RETENTION_HOURS:-24}"
    local retention_mins=$((retention_hours * 60))
    local cleaned=0

    # Clean per-agent result files (not synthesis files)
    while IFS= read -r -d '' file; do
        local basename
        basename=$(basename "$file")
        # Keep synthesis, consensus, validation, delivery files
        case "$basename" in
            probe-synthesis-*|grasp-consensus-*|tangle-validation-*|delivery-*) continue ;;
            .session-id|.created-at) continue ;;
        esac
        rm -f "$file"
        ((cleaned++)) || true
    done < <(find "$RESULTS_DIR" -name "*.md" -mmin "+$retention_mins" -print0 2>/dev/null)

    # Clean marker files
    find "$RESULTS_DIR" -name "*.marker" -mmin "+$retention_mins" -delete 2>/dev/null || true

    [[ $cleaned -gt 0 ]] && log "INFO" "Cleaned $cleaned expired result files (retention: ${retention_hours}h)" || true
}
