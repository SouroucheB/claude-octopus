#!/usr/bin/env bash
# Unit tests for shared quota fast-fail watcher helpers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/scripts/lib/quota-watcher.sh"

test_suite "quota watcher helper"

log() { :; }

test_case "quota_watcher_has_match detects quota text in stderr"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
err_file="$tmp_dir/agent.err"
out_file="$tmp_dir/agent.out"
printf '%s\n' "RetryableQuotaError: exhausted your capacity" > "$err_file"
touch "$out_file"
if quota_watcher_has_match "$err_file" "$out_file"; then
    test_pass
else
    test_fail "quota pattern was not detected"
fi

test_case "quota_watcher_has_match detects Gemini 429 and rate-limit wording"
: > "$err_file"
: > "$out_file"
quota_examples=(
    "Error: code: 429 Too Many Requests"
    "Gemini API rate limit exceeded, retrying"
    "request was rate-limited by the upstream provider"
    "Resource exhausted, please try again later"
)
detected_all=true
for quota_example in "${quota_examples[@]}"; do
    printf '%s\n' "$quota_example" > "$err_file"
    if ! quota_watcher_has_match "$err_file" "$out_file"; then
        detected_all=false
        break
    fi
done
if [[ "$detected_all" == "true" ]]; then
    test_pass
else
    test_fail "real Gemini quota/rate-limit wording was not detected: $quota_example"
fi

test_case "quota_watcher_has_match ignores non-quota provider errors"
printf '%s\n' "Gemini CLI is not running in a trusted directory" > "$err_file"
: > "$out_file"
if quota_watcher_has_match "$err_file" "$out_file"; then
    test_fail "trusted-directory failure was incorrectly classified as quota"
else
    test_pass
fi

test_case "start_quota_watcher invokes callback and stops target"
flag_file="$tmp_dir/callback.flag"
test_quota_callback() {
    local target_pid="$1"
    printf '%s\n' "$target_pid" > "$flag_file"
    kill "$target_pid" 2>/dev/null || true
}

( trap 'exit 0' TERM; while true; do sleep 1; done ) &
target_pid=$!
watcher_pid=$(start_quota_watcher "$target_pid" "$err_file" "$out_file" test_quota_callback "quota test")
printf '%s\n' "TerminalQuotaError" > "$out_file"

for _ in 1 2 3 4 5; do
    [[ -s "$flag_file" ]] && break
    sleep 1
done
stop_quota_watcher "$watcher_pid"
kill "$target_pid" 2>/dev/null || true
wait "$target_pid" 2>/dev/null || true

if [[ -s "$flag_file" ]]; then
    test_pass
else
    test_fail "quota watcher did not invoke callback"
fi

test_case "start_idle_watcher keeps target alive when stdout grows"
idle_flag_file="$tmp_dir/idle-stdout.flag"
test_idle_callback() {
    local target_pid="$1"
    printf '%s\n' "$target_pid" > "$idle_flag_file"
    kill "$target_pid" 2>/dev/null || true
}

: > "$err_file"
: > "$out_file"
OCTOPUS_AGENT_IDLE_TIMEOUT=2
OCTOPUS_AGENT_IDLE_POLL_INTERVAL=1
(
    for i in 1 2 3; do
        printf 'stdout tick %s\n' "$i" >> "$out_file"
        sleep 1
    done
) &
target_pid=$!
watcher_pid=$(start_idle_watcher "$target_pid" "$err_file" "$out_file" test_idle_callback "idle stdout test" "$tmp_dir/idle-stdout.detected")
wait "$target_pid" 2>/dev/null || true
stop_idle_watcher "$watcher_pid"
if [[ ! -e "$idle_flag_file" && ! -e "$tmp_dir/idle-stdout.detected" ]]; then
    test_pass
else
    test_fail "idle watcher killed stdout-active target"
fi

test_case "start_idle_watcher keeps target alive when stderr grows"
idle_stderr_flag_file="$tmp_dir/idle-stderr.flag"
test_idle_stderr_callback() {
    local target_pid="$1"
    printf '%s\n' "$target_pid" > "$idle_stderr_flag_file"
    kill "$target_pid" 2>/dev/null || true
}

: > "$err_file"
: > "$out_file"
(
    for i in 1 2 3; do
        printf 'stderr tick %s\n' "$i" >> "$err_file"
        sleep 1
    done
) &
target_pid=$!
watcher_pid=$(start_idle_watcher "$target_pid" "$err_file" "$out_file" test_idle_stderr_callback "idle stderr test" "$tmp_dir/idle-stderr.detected")
wait "$target_pid" 2>/dev/null || true
stop_idle_watcher "$watcher_pid"
if [[ ! -e "$idle_stderr_flag_file" && ! -e "$tmp_dir/idle-stderr.detected" ]]; then
    test_pass
else
    test_fail "idle watcher killed stderr-active target"
fi

test_case "start_idle_watcher kills silent target and records reason"
idle_silent_flag_file="$tmp_dir/idle-silent.flag"
idle_silent_detected="$tmp_dir/idle-silent.detected"
test_idle_silent_callback() {
    local target_pid="$1"
    printf '%s\n' "$target_pid" > "$idle_silent_flag_file"
    kill "$target_pid" 2>/dev/null || true
}

: > "$err_file"
printf 'initial output\n' > "$out_file"
( trap 'exit 143' TERM; while true; do read -r -t 1 _idle_test_input || true; done ) &
target_pid=$!
watcher_pid=$(start_idle_watcher "$target_pid" "$err_file" "$out_file" test_idle_silent_callback "idle silent test" "$idle_silent_detected")
wait "$target_pid" 2>/dev/null || true
stop_idle_watcher "$watcher_pid"
unset OCTOPUS_AGENT_IDLE_TIMEOUT OCTOPUS_AGENT_IDLE_POLL_INTERVAL
if [[ -s "$idle_silent_flag_file" ]] && grep -q "reason=idle: no output for 2s" "$idle_silent_detected" 2>/dev/null; then
    test_pass
else
    test_fail "idle watcher did not kill silent target with recorded reason"
fi

test_summary
