#!/usr/bin/env bash
# Static regression checks for /octo:develop Markdown plan reference handling.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "develop Markdown plan resolution"

assert_has() {
    local pattern="$1"
    local label="$2"
    test_case "$label"
    if grep -qE "$pattern" "$WORKFLOWS"; then
        test_pass
    else
        test_fail "pattern not found: $pattern"
    fi
}

assert_lacks() {
    local pattern="$1"
    local label="$2"
    test_case "$label"
    if grep -qE "$pattern" "$WORKFLOWS"; then
        test_fail "unexpected pattern found: $pattern"
    else
        test_pass
    fi
}

test_case "workflows.sh has valid bash syntax"
if bash -n "$WORKFLOWS" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in workflows.sh"
fi

assert_lacks 'grep -oE .*\.\.md.*head -1|grep -oE .*\\.md.*head -1' \
    "plan reference scan avoids grep|head pipeline"

assert_has 'trimmed_prompt=' \
    "plan reference handling detects file-only prompts"

assert_has 'resolved_prompt="\$\{prompt\}' \
    "plan reference handling preserves surrounding user instructions"

assert_has 'build_tangle_subtask_prompt "\$resolved_prompt"' \
    "direct fallback receives resolved prompt"

source "$WORKFLOWS"

CAPTURED_DECOMPOSE_PROMPT=""
CAPTURED_VALIDATE_PROMPT=""
CYAN=""
MAGENTA=""
NC=""
TMUX_MODE=false
DRY_RUN=false
SUPPORTS_PARALLEL_FILE_SAFETY=false
RESULTS_DIR="$(mktemp -d)"
LOGS_DIR="$RESULTS_DIR/logs"
WORKSPACE_DIR="$RESULTS_DIR/workspace"
mkdir -p "$WORKSPACE_DIR/.octo/agents"
DECOMPOSE_CAPTURE_FILE="$RESULTS_DIR/decompose.prompt"
trap 'rm -rf "$RESULTS_DIR"' EXIT

log() { :; }
octopus_phase_banner() { :; }
design_review_ceremony() { :; }
display_workflow_cost_estimate() { return 0; }
reset_provider_lockouts() { :; }
fleet_dispatch_begin() { :; }
fleet_dispatch_end() { :; }
run_agent_sync() {
    printf '%s' "$2" > "$DECOMPOSE_CAPTURE_FILE"
    printf '%s\n' "1. [CODING] Validate resolved plan context. Files: scripts/lib/workflows.sh"
}
validate_tangle_results() {
    CAPTURED_VALIDATE_PROMPT="$2"
}
spawn_agent_capture_pid() {
    local task_id="$3"
    printf '0\n' > "$WORKSPACE_DIR/.octo/agents/${task_id}.done"
    printf '12345\n'
}

run_tangle_case() {
    CAPTURED_DECOMPOSE_PROMPT=""
    CAPTURED_VALIDATE_PROMPT=""
    rm -f "$DECOMPOSE_CAPTURE_FILE"
    tangle_develop "$1" >/dev/null || return 1
    [[ -f "$DECOMPOSE_CAPTURE_FILE" ]] && CAPTURED_DECOMPOSE_PROMPT=$(<"$DECOMPOSE_CAPTURE_FILE")
}

test_case "plan file references inject content while preserving prompt text"
plan_file="$RESULTS_DIR/session-plan.md"
printf '%s\n' "Update scripts/lib/workflows.sh with the regression fix." > "$plan_file"
run_tangle_case "please implement $plan_file carefully"
if [[ "$CAPTURED_DECOMPOSE_PROMPT" == *"please implement"* ]] && \
   [[ "$CAPTURED_DECOMPOSE_PROMPT" == *"Update scripts/lib/workflows.sh with the regression fix."* ]]; then
    test_pass
else
    test_fail "resolved prompt did not preserve instructions and plan content"
fi

test_case "validation receives resolved plan content"
if [[ "$CAPTURED_VALIDATE_PROMPT" == *"Update scripts/lib/workflows.sh with the regression fix."* ]]; then
    test_pass
else
    test_fail "validate_tangle_results received raw prompt instead of resolved content"
fi

test_case "resolved plan content is size-bounded"
large_plan_file="$RESULTS_DIR/large-plan.md"
{
    printf '%s\n' "Update scripts/lib/workflows.sh with a bounded-plan regression fix."
    printf 'A%.0s' {1..2000}
    printf '%s\n' "TAIL_SHOULD_NOT_BE_INJECTED"
} > "$large_plan_file"
OCTOPUS_TANGLE_PLAN_CONTEXT_CHARS=200 run_tangle_case "please implement $large_plan_file"
if [[ "$CAPTURED_VALIDATE_PROMPT" == *"Update scripts/lib/workflows.sh with a bounded-plan regression fix."* ]] && \
   [[ "$CAPTURED_VALIDATE_PROMPT" == *"resolved plan truncated"* ]] && \
   [[ "$CAPTURED_VALIDATE_PROMPT" != *"TAIL_SHOULD_NOT_BE_INJECTED"* ]]; then
    test_pass
else
    test_fail "large resolved plan was not capped before injection"
fi
unset OCTOPUS_TANGLE_PLAN_CONTEXT_CHARS

test_case "tangle worker report contract is in the prompt prefix"
large_original_task=$(printf 'A%.0s' {1..5000})
subtask_prompt="$(build_tangle_subtask_prompt "$large_original_task" $'[CODING] Update page\nFiles: src/app/page.tsx')"
prompt_prefix="${subtask_prompt:0:1200}"
if [[ "$prompt_prefix" == *"## Verification"* && "$prompt_prefix" == *"TANGLE_REPORT_COMPLETE"* ]]; then
    test_pass
else
    test_fail "Tangle report contract is only in the truncatable prompt tail"
fi

test_case "backlog source Markdown mention is not injected as a plan"
backlog_file="$RESULTS_DIR/BACKLOG.md"
cat > "$backlog_file" <<'EOF'
# Backlog Fixture

This unrelated fixture mentions AGENTS.md, AUDIT.md, src/lib/engine/applyPerception.ts,
src/lib/engine/projectDossier.ts, and scripts/generate-snapshots.sh.
EOF
run_tangle_case "Task: fix Gmail threading. Source backlog: $backlog_file item \"Gmail threading des réponses CoproOS\". Files: src/lib/email/sendEmail.server.ts"
if [[ "$CAPTURED_DECOMPOSE_PROMPT" == *"This unrelated fixture mentions"* ]]; then
    test_fail "source backlog mention injected the full Markdown file"
elif [[ "$CAPTURED_VALIDATE_PROMPT" == *"This unrelated fixture mentions"* ]]; then
    test_fail "validation prompt included backlog file content"
else
    test_pass
fi

test_case "backlog from/use Markdown variants are not injected as plans"
run_tangle_case "Implement Gmail threading item from $backlog_file. Use $backlog_file as source of truth. Files: src/lib/email/sendEmail.server.ts"
if [[ "$CAPTURED_DECOMPOSE_PROMPT" == *"This unrelated fixture mentions"* ]]; then
    test_fail "from/use backlog mention injected the full Markdown file"
elif [[ "$CAPTURED_VALIDATE_PROMPT" == *"This unrelated fixture mentions"* ]]; then
    test_fail "validation prompt included backlog file content from from/use variant"
else
    test_pass
fi

test_case "wildcard-looking Markdown tokens are not glob-expanded"
glob_dir="$RESULTS_DIR/glob-case"
mkdir -p "$glob_dir"
printf '%s\n' "This file should not be injected from a wildcard prompt." > "$glob_dir/noise.md"
(
    cd "$glob_dir"
    run_tangle_case "review *.md"
)
if [[ "$CAPTURED_DECOMPOSE_PROMPT" == *"This file should not be injected"* ]]; then
    test_fail "wildcard token was expanded and injected as a plan file"
else
    test_pass
fi

test_case "deadline override marks stalled subtasks as timed out"
WORKSPACE_DIR="$RESULTS_DIR/workspace"
mkdir -p "$WORKSPACE_DIR/.octo/agents"
LOG_CAPTURE_FILE="$RESULTS_DIR/tangle-deadline.log"
DATE_COUNTER_FILE="$RESULTS_DIR/date-counter"
SLEEP_COUNTER_FILE="$RESULTS_DIR/sleep-counter"
EXPECTED_DONE_FILE="$WORKSPACE_DIR/.octo/agents/tangle-100-0.done"
printf '0' > "$DATE_COUNTER_FILE"
printf '0' > "$SLEEP_COUNTER_FILE"
rm -f "$EXPECTED_DONE_FILE" "$LOG_CAPTURE_FILE"

log() {
    printf '%s %s\n' "${1:-}" "${2:-}" >> "$LOG_CAPTURE_FILE"
}
run_agent_sync() {
    printf '%s\n' "1. [CODING] stalled implementation. Files: scripts/lib/workflows.sh"
}
spawn_agent_capture_pid() {
    printf '%s\n' "999999"
}
sleep() {
    local count
    count=$(<"$SLEEP_COUNTER_FILE")
    count=$((count + 1))
    printf '%s' "$count" > "$SLEEP_COUNTER_FILE"

    # On the pre-override implementation this prevents the test from looping
    # forever while still failing the behavioral assertion below.
    if [[ $count -ge 2 && ! -f "$EXPECTED_DONE_FILE" ]]; then
        printf '%s\n' "0" > "$EXPECTED_DONE_FILE"
    fi
}
date() {
    if [[ "${1:-}" == "+%s" ]]; then
        local count
        count=$(<"$DATE_COUNTER_FILE")
        count=$((count + 1))
        printf '%s' "$count" > "$DATE_COUNTER_FILE"
        if [[ $count -le 2 ]]; then
            printf '%s\n' "100"
        else
            printf '%s\n' "101"
        fi
        return 0
    fi
    command date "$@"
}

CAPTURED_VALIDATE_PROMPT=""
deadline_override_ok=false
if OCTOPUS_TANGLE_DEADLINE=0 tangle_develop "deadline override task" >/dev/null 2>&1 && \
   grep -q "deadline exceeded" "$LOG_CAPTURE_FILE" && \
   grep -q "finished with status: timeout" "$LOG_CAPTURE_FILE" && \
   [[ "$CAPTURED_VALIDATE_PROMPT" == "deadline override task" ]]; then
    deadline_override_ok=true
fi
unset -f date
unset -f sleep

if [[ "$deadline_override_ok" == "true" ]]; then
    test_pass
else
    test_fail "OCTOPUS_TANGLE_DEADLINE did not force a stalled subtask timeout"
fi

test_summary
