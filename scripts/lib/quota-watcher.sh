#!/usr/bin/env bash
# Shared quota fast-fail watcher for provider CLIs that retry for a long time
# after quota exhaustion instead of exiting promptly.

OCTOPUS_QUOTA_PATTERN='QUOTA_EXHAUSTED|TerminalQuotaError|exhausted your capacity|RetryableQuotaError|Attempt [0-9]+ failed.*exhausted|code:[[:space:]]*429|(^|[^[:digit:]])429([^[:digit:]]|$)|too many requests|rate[ -]?limit(ed|ing)?|resource exhausted'

quota_watcher_has_match() {
    local temp_err="$1"
    local temp_out="$2"

    grep -qiE "$OCTOPUS_QUOTA_PATTERN" "$temp_err" 2>/dev/null || \
        grep -qiE "$OCTOPUS_QUOTA_PATTERN" "$temp_out" 2>/dev/null
}

start_quota_watcher() {
    local target_pid="$1"
    local temp_err="$2"
    local temp_out="$3"
    local kill_callback="$4"
    local warning_message="${5:-Quota exhaustion detected - fast-failing}"
    local detected_file="${6:-}"

    > "$temp_err"
    > "$temp_out"

    (
        while kill -0 "$target_pid" 2>/dev/null; do
            sleep 2
            if quota_watcher_has_match "$temp_err" "$temp_out"; then
                log "WARN" "$warning_message"
                if [[ -n "$detected_file" ]]; then
                    printf 'detected_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$detected_file" 2>/dev/null || true
                fi
                "$kill_callback" "$target_pid"
                break
            fi
        done
    ) >/dev/null &
    echo "$!"
}

stop_quota_watcher() {
    local watcher_pid="${1:-}"
    [[ -n "$watcher_pid" ]] || return 0

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
}

_octopus_watcher_file_size() {
    local file="$1"
    if [[ -e "$file" ]]; then
        wc -c < "$file" 2>/dev/null | tr -d '[:space:]' || echo 0
    else
        echo 0
    fi
}

_octopus_watcher_file_mtime() {
    local file="$1"
    if [[ ! -e "$file" ]]; then
        echo 0
        return 0
    fi

    stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0
}

idle_watcher_signature() {
    local temp_err="$1"
    local temp_out="$2"

    printf '%s:%s|%s:%s\n' \
        "$(_octopus_watcher_file_size "$temp_err")" \
        "$(_octopus_watcher_file_mtime "$temp_err")" \
        "$(_octopus_watcher_file_size "$temp_out")" \
        "$(_octopus_watcher_file_mtime "$temp_out")"
}

start_idle_watcher() {
    local target_pid="$1"
    local temp_err="$2"
    local temp_out="$3"
    local kill_callback="$4"
    local warning_message="${5:-}"
    local detected_file="${6:-}"

    local idle_timeout="${OCTOPUS_AGENT_IDLE_TIMEOUT:-90}"
    [[ "$idle_timeout" =~ ^[0-9]+$ && "$idle_timeout" -gt 0 ]] || idle_timeout=90

    local poll_interval="${OCTOPUS_AGENT_IDLE_POLL_INTERVAL:-5}"
    [[ "$poll_interval" =~ ^[0-9]+$ && "$poll_interval" -gt 0 ]] || poll_interval=5
    if [[ "$poll_interval" -gt "$idle_timeout" ]]; then
        poll_interval="$idle_timeout"
    fi

    (
        local last_signature current_signature idle_elapsed reason
        last_signature=$(idle_watcher_signature "$temp_err" "$temp_out")
        idle_elapsed=0
        reason="idle: no output for ${idle_timeout}s"

        while kill -0 "$target_pid" 2>/dev/null; do
            sleep "$poll_interval"
            kill -0 "$target_pid" 2>/dev/null || break

            current_signature=$(idle_watcher_signature "$temp_err" "$temp_out")
            if [[ "$current_signature" != "$last_signature" ]]; then
                last_signature="$current_signature"
                idle_elapsed=0
                continue
            fi

            idle_elapsed=$((idle_elapsed + poll_interval))
            if [[ "$idle_elapsed" -ge "$idle_timeout" ]]; then
                log "WARN" "${warning_message:-idle-timeout: ${reason}}"
                if [[ -n "$detected_file" ]]; then
                    {
                        printf 'detected_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
                        printf 'reason=%s\n' "$reason"
                        printf 'idle_timeout=%s\n' "$idle_timeout"
                    } > "$detected_file" 2>/dev/null || true
                fi
                "$kill_callback" "$target_pid"
                break
            fi
        done
    ) >/dev/null &
    echo "$!"
}

stop_idle_watcher() {
    local watcher_pid="${1:-}"
    [[ -n "$watcher_pid" ]] || return 0

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
}
