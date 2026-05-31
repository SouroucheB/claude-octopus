#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# lib/heartbeat.sh — Heartbeat monitoring, dynamic timeouts, portable timeout
# Extracted from orchestrate.sh (v8.19.0 heartbeat + v7.16.0 timeout)
# ═══════════════════════════════════════════════════════════════════════════════

start_heartbeat_monitor() {
    local pid="$1"
    local task_id="$2"

    local heartbeat_dir="${WORKSPACE_DIR}/.octo/agents"
    mkdir -p "$heartbeat_dir"
    local heartbeat_file="$heartbeat_dir/${pid}.heartbeat"

    # Background process: touch heartbeat every 30s, self-terminate when PID dies
    (
        while kill -0 "$pid" 2>/dev/null; do
            touch "$heartbeat_file"
            sleep 30
        done
        rm -f "$heartbeat_file"
    ) &
    disown

    log DEBUG "Heartbeat monitor started for PID $pid (task: $task_id)"
}

check_agent_heartbeat() {
    local pid="$1"

    local heartbeat_file="${WORKSPACE_DIR}/.octo/agents/${pid}.heartbeat"

    if [[ ! -f "$heartbeat_file" ]]; then
        echo "missing"
        return
    fi

    # Get file modification time (macOS vs Linux compatible)
    local mod_time
    if stat -f %m "$heartbeat_file" &>/dev/null; then
        # macOS
        mod_time=$(stat -f %m "$heartbeat_file")
    else
        # Linux
        mod_time=$(stat -c %Y "$heartbeat_file")
    fi

    local now
    now=$(date +%s)
    local age=$((now - mod_time))

    if [[ $age -gt 90 ]]; then
        echo "stale"
    else
        echo "alive"
    fi
}

compute_dynamic_timeout() {
    local task_type="${1:-standard}"
    local prompt="${2:-}"
    local agent_type="${3:-}"  # v9.2.0: optional provider for per-provider caps

    # Env override takes precedence
    if [[ -n "${OCTOPUS_AGENT_TIMEOUT:-}" ]]; then
        echo "$OCTOPUS_AGENT_TIMEOUT"
        return
    fi

    # v9.2.0: Provider-specific timeout caps (OctoBench data)
    # Codex: consistently 120-183s, cap at 150s for probe tasks
    # Gemini: consistently 34-113s, cap at 90s for probe tasks
    # Claude-sonnet: consistently 35-46s, cap at 60s for probe tasks
    local provider_cap=""
    case "$agent_type" in
        codex*)     provider_cap=150 ;;
        gemini*)    provider_cap=90 ;;
        claude-sonnet*|sonnet*) provider_cap=60 ;;
        perplexity*) provider_cap=45 ;;
    esac

    # Response mode mapping
    local response_mode="${OCTOPUS_RESPONSE_MODE:-auto}"
    case "$response_mode" in
        direct|lightweight)
            echo "60"
            return
            ;;
    esac

    # v8.40.0: When CC has memory leak fixes (v2.1.63+), long sessions are stable —
    # allow longer timeouts for complex tasks since agent sessions won't degrade
    local leak_safe_boost=0
    if [[ "$SUPPORTS_MEMORY_LEAK_FIXES" == "true" ]]; then
        leak_safe_boost=60
    fi

    # Task type mapping
    case "$task_type" in
        direct|lightweight|trivial)
            echo "60"
            ;;
        full|premium|complex)
            echo "$((300 + leak_safe_boost))"
            ;;
        crossfire|debate)
            echo "$((180 + leak_safe_boost))"
            ;;
        security|audit)
            echo "$((240 + leak_safe_boost))"
            ;;
        *)
            local base_timeout=$((120 + leak_safe_boost))
            # Apply provider cap if set and lower than task-based timeout
            if [[ -n "$provider_cap" && "$provider_cap" -lt "$base_timeout" ]]; then
                echo "$provider_cap"
            else
                echo "$base_timeout"
            fi
            ;;
    esac
}

octopus_tangle_declared_file_count() {
    local prompt="${1:-}"

    printf '%s\n' "$prompt" \
        | awk '{ line = tolower($0); if (line ~ /(^|[[:space:]])files:[[:space:]]/) print }' \
        | grep -oE '((src|lib|app|test|tests|docs|pkg|cmd|internal|scripts|config|public|assets|components|pages|utils|hooks|services|models|controllers|routes|middleware|api)/[a-zA-Z0-9_./-]+\.[a-zA-Z0-9]{1,8}|\./[a-zA-Z0-9_./-]+\.[a-zA-Z0-9]{1,8}|[a-zA-Z0-9_.-]+\.(md|markdown|txt|json|ya?ml|sh|bash|ts|tsx|js|jsx|mjs|cjs|css|scss|html|py|rb|go|rs|java|kt|swift|sql|toml))' 2>/dev/null \
        | sed 's#^\./##' \
        | sort -u \
        | wc -l \
        | tr -d '[:space:]'
}

octopus_effective_agent_timeout() {
    local agent_type="${1:-}"
    local prompt="${2:-}"
    local phase="${3:-}"
    local default_timeout="${4:-${TIMEOUT:-120}}"
    local role="${5:-}"

    if [[ -n "${OCTOPUS_AGENT_TIMEOUT:-}" ]]; then
        echo "$OCTOPUS_AGENT_TIMEOUT"
        return
    fi

    if [[ -n "${OCTOPUS_SPAWN_AGENT_TIMEOUT:-}" ]]; then
        echo "$OCTOPUS_SPAWN_AGENT_TIMEOUT"
        return
    fi

    # A user-provided --timeout is an explicit per-task ceiling/contract. Keep
    # it exact unless a more specific env override above is set.
    if [[ "${OCTOPUS_TIMEOUT_EXPLICIT:-false}" == "true" ]]; then
        echo "$default_timeout"
        return
    fi

    local task_type="standard"
    if type classify_task >/dev/null 2>&1; then
        task_type=$(classify_task "$prompt" 2>/dev/null) || task_type="standard"
    fi

    local computed="$default_timeout"
    if type compute_dynamic_timeout >/dev/null 2>&1; then
        computed=$(compute_dynamic_timeout "$task_type" "$prompt" "$agent_type" 2>/dev/null) || computed="$default_timeout"
    fi

    [[ "$computed" =~ ^[0-9]+$ ]] || computed="$default_timeout"
    if [[ "$phase" == "tangle" && "$role" == "implementer" && "${OCTOPUS_TIMEOUT_EXPLICIT:-false}" != "true" ]]; then
        local file_count threshold per_extra_file scaled max_timeout
        file_count=$(octopus_tangle_declared_file_count "$prompt")
        threshold="${OCTOPUS_TANGLE_TIMEOUT_FILE_THRESHOLD:-4}"
        per_extra_file="${OCTOPUS_TANGLE_TIMEOUT_PER_EXTRA_FILE:-120}"
        [[ "$file_count" =~ ^[0-9]+$ ]] || file_count=0
        [[ "$threshold" =~ ^[0-9]+$ ]] || threshold=4
        [[ "$per_extra_file" =~ ^[0-9]+$ ]] || per_extra_file=120

        if [[ "$file_count" -ge "$threshold" ]]; then
            scaled=$((computed + (file_count - threshold + 1) * per_extra_file))
            max_timeout="${OCTOPUS_TANGLE_IMPLEMENTER_TIMEOUT_MAX:-$default_timeout}"
            [[ "$max_timeout" =~ ^[0-9]+$ ]] || max_timeout="$default_timeout"
            if [[ "$scaled" -gt "$max_timeout" ]]; then
                scaled="$max_timeout"
            fi
            if [[ "$scaled" -gt "$computed" ]]; then
                computed="$scaled"
            fi
        fi
    fi

    if [[ "$default_timeout" =~ ^[0-9]+$ && "$computed" -gt "$default_timeout" ]]; then
        echo "$default_timeout"
    else
        echo "$computed"
    fi
}

cleanup_heartbeat() {
    local pid="$1"
    rm -f "${WORKSPACE_DIR}/.octo/agents/${pid}.heartbeat"
}

# Portable timeout function (works on macOS and Linux)
# Prefers system timeout commands, falls back to manual implementation
run_with_timeout() {
    local timeout_secs="$1"
    shift

    local exit_code

    # v9.20.1: Detect if command is a shell function (e.g. perplexity_execute,
    # openrouter_execute). External timeout/gtimeout can only exec binaries —
    # shell functions require the in-process fallback path. (#255)
    local _cmd_is_function=false
    if [[ "$(type -t "$1" 2>/dev/null)" == "function" ]]; then
        _cmd_is_function=true
    fi

    # Use gtimeout (GNU) or timeout if available AND command is an external binary
    if [[ "$_cmd_is_function" == "false" ]] && command -v gtimeout &>/dev/null; then
        gtimeout "$timeout_secs" "$@"
        exit_code=$?
    elif [[ "$_cmd_is_function" == "false" ]] && command -v timeout &>/dev/null; then
        timeout "$timeout_secs" "$@"
        exit_code=$?
    else
        # Fallback with proper cleanup (also used for shell functions).
        # `<&0` explicitly inherits stdin from the caller: non-interactive bash
        # otherwise redirects background-job stdin to /dev/null, which starves
        # shell-function providers (perplexity_execute, openrouter_execute)
        # that read their prompt from stdin. See issue #307.
        local cmd_pid monitor_pid timed_out_file
        timed_out_file=$(mktemp 2>/dev/null || mktemp -t 'octo-timeout')

        "$@" <&0 &
        cmd_pid=$!

        (
            sleep "$timeout_secs"
            if kill -0 "$cmd_pid" 2>/dev/null; then
                printf '1\n' > "$timed_out_file"
                kill -TERM "$cmd_pid" 2>/dev/null || true
                sleep "${OCTOPUS_TIMEOUT_KILL_GRACE:-2}"
                kill -KILL "$cmd_pid" 2>/dev/null || true
            fi
        ) >/dev/null 2>&1 < /dev/null &
        monitor_pid=$!

        if wait "$cmd_pid" 2>/dev/null; then
            exit_code=0
        else
            exit_code=$?
        fi

        # Clean up monitor process
        kill "$monitor_pid" 2>/dev/null
        wait "$monitor_pid" 2>/dev/null
        if [[ -s "$timed_out_file" ]]; then
            exit_code=124
        fi
        rm -f "$timed_out_file" 2>/dev/null
    fi

    # Enhanced timeout error messaging (v7.16.0 Feature 3)
    if [[ $exit_code -eq 124 ]] || [[ $exit_code -eq 143 ]]; then
        local timeout_mins=$((timeout_secs / 60))
        local recommended_timeout=$((timeout_secs * 2))
        local recommended_mins=$((recommended_timeout / 60))

        if [[ $exit_code -eq 124 ]]; then
            log ERROR "backstop: exceeded ${timeout_secs}s"
        else
            log ERROR "Operation terminated after ${timeout_secs}s (${timeout_mins}m)"
        fi
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "⚠️  TIMEOUT EXCEEDED" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
        echo "Operation exceeded the ${timeout_secs}s (${timeout_mins}m) timeout limit." >&2
        echo "" >&2
        echo "💡 Possible solutions:" >&2
        echo "   1. Increase timeout: --timeout ${recommended_timeout} (${recommended_mins}m)" >&2
        echo "   2. Simplify the prompt to reduce processing time" >&2
        echo "   3. Check provider API status for slowness" >&2
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        return 124
    fi

    return $exit_code
}
