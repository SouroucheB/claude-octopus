#!/usr/bin/env bash
# Regression checks for /octo:embrace hardcoded phase fail-fast behavior.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

# This suite intentionally exercises non-zero workflow exits. Keep errexit off
# after loading the shared framework so Bash 5/Linux does not abort before
# assertions run.
set +e

test_suite "embrace phase fail-fast"

test_case "workflows.sh has valid bash syntax"
if bash -n "$WORKFLOWS" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in workflows.sh"
fi

# shellcheck source=/dev/null
source "$WORKFLOWS"

TEST_ROOT="$(mktemp -d)"
HOME="$TEST_ROOT/home"
RESULTS_DIR="$TEST_ROOT/results"
LOGS_DIR="$TEST_ROOT/logs"
WORKSPACE_DIR="$TEST_ROOT/workspace"
PLUGIN_DIR="$PROJECT_ROOT"
trap 'rm -rf "$TEST_ROOT"' EXIT

CYAN=""
GREEN=""
MAGENTA=""
NC=""
_BOX_TOP=""
_BOX_BOT=""
AUTONOMY_MODE="semi-autonomous"
LOOP_UNTIL_APPROVED=false
RESUME_SESSION=false
DRY_RUN=false
OCTOPUS_YAML_RUNTIME=disabled
OCTOPUS_EMBRACE_DEBATE_GATES=none
SUPPORTS_DISABLE_CRON_ENV=false

CASE_NAME=""
PHASE_CALLS=""
CHECKPOINTS=""
EMBRACE_STATUS=0

log() { :; }
cleanup_old_results() { :; }
show_cost_estimate() { :; }
cleanup_expired_checkpoints() { :; }
reset_provider_lockouts() { :; }
search_observations() { :; }
init_session() { :; }
display_workflow_cost_estimate() { return 0; }
preflight_check() { return 0; }
display_phase_metrics() { :; }
update_context() { :; }
handle_autonomy_checkpoint() { :; }
complete_session() { :; }
write_structured_decision() { :; }
earn_skill() { :; }
sleep() { :; }
run_agent_sync() {
    if [[ "$CASE_NAME" == "gate_agents_fail" && "${5:-}" == "embrace-gate" ]]; then
        return 2
    fi
    if [[ "$CASE_NAME" == "gate_blocks_revise" && "${5:-}" == "embrace-gate" ]]; then
        if [[ "${4:-}" == "synthesizer" ]]; then
            printf '%s\n' "Verdict: REVISE — do not enter Develop until blockers are resolved."
        else
            printf '%s\n' "Verdict: REVISE"
        fi
        return 0
    fi
    if [[ "$CASE_NAME" == "gate_self_referential_revise" && "${5:-}" == "embrace-gate" ]]; then
        if [[ "${4:-}" == "synthesizer" ]]; then
            cat <<'EOF'
Verdict: REVISE (blocking)

The current-run embrace-gate-define-develop-*.md artifact is missing. The context also lacks current-run tangle-validation-*.md and delivery-*.md artifacts. However, this review itself is the gate input and those artifacts cannot be prerequisites for entering Develop.
EOF
        else
            printf '%s\n' "Verdict: REVISE because the current gate artifact does not exist yet."
        fi
        return 0
    fi
    if [[ "$CASE_NAME" == "gate_proceed_with_risks" && "${5:-}" == "embrace-gate" ]]; then
        if [[ "${4:-}" == "synthesizer" ]]; then
            cat <<'EOF'
## Gate Synthesis

### Verdict consolide

**`PROCEED_WITH_RISKS`** - Develop is authorized.

### Non-blocking risks

No hard blocker. Watch phases_completed if it becomes blocked later, but this is observational and must not stop this gate.
EOF
        else
            printf '%s\n' "Verdict: PROCEED_WITH_RISKS"
        fi
        return 0
    fi
    printf '%s\n' "gate response from ${1:-agent}"
}
save_session_checkpoint() {
    CHECKPOINTS+="${1}:${2}:${3:-}"$'\n'
}

probe_discover() {
    PHASE_CALLS+="probe "
    [[ "$CASE_NAME" == "missing_probe_output" ]] && return 0
    printf '%s\n' "# probe synthesis" > "$RESULTS_DIR/probe-synthesis-${OCTOPUS_TASK_GROUP:-test}.md"
}

grasp_define() {
    PHASE_CALLS+="grasp "
    printf '%s\n' "# grasp consensus" > "$RESULTS_DIR/grasp-consensus-${OCTOPUS_TASK_GROUP:-test}.md"
}

tangle_develop() {
    PHASE_CALLS+="tangle "
    if [[ "$CASE_NAME" == "tangle_fails" ]]; then
        return 7
    fi
    printf '%s\n' "### Quality Gate: PASSED" > "$RESULTS_DIR/tangle-validation-${OCTOPUS_TASK_GROUP:-test}.md"
}

ink_deliver() {
    PHASE_CALLS+="ink "
    [[ "$CASE_NAME" == "missing_ink_output" ]] && return 0
    printf '%s\n' "# delivery" > "$RESULTS_DIR/delivery-${OCTOPUS_TASK_GROUP:-test}.md"
}

run_embrace_case() {
    set +e
    CASE_NAME="$1"
    OCTOPUS_EMBRACE_DEBATE_GATES="${2:-none}"
    PHASE_CALLS=""
    CHECKPOINTS=""
    EMBRACE_STATUS=0
    EMBRACE_DEBATE_GATE_OUTPUT=""
    rm -rf "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR"
    mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR" "$HOME"

    embrace_full_workflow "Implement the requested feature" >/dev/null 2>&1
    EMBRACE_STATUS=$?

    return 0
}

run_embrace_case "all_ok" "none" || true

test_case "no debate gates by default"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ "$CHECKPOINTS" != *"debate-"* ]] && \
   ! ls "$RESULTS_DIR"/embrace-gate-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace ran debate gates even though none were requested"
fi

run_embrace_case "all_ok" "both" || true

test_case "requested debate gates run before develop and deliver"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ "$CHECKPOINTS" == *"debate-define-develop:completed:"* ]] && \
   [[ "$CHECKPOINTS" == *"debate-develop-deliver:completed:"* ]] && \
   ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md >/dev/null 2>&1 && \
   ls "$RESULTS_DIR"/embrace-gate-develop-deliver-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace did not run both requested debate gates"
fi

run_embrace_case "gate_agents_fail" "define" || true

test_case "requested debate gate failure stops before tangle"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp " ]] && \
   [[ "$CHECKPOINTS" == *"debate-define-develop:failed:"* ]]; then
    test_pass
else
    test_fail "embrace continued after requested debate gate failure"
fi

run_embrace_case "gate_blocks_revise" "define" || true

test_case "requested debate gate blocking verdict stops before tangle"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp " ]] && \
   ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace continued after a requested debate gate returned REVISE"
fi

run_embrace_case "gate_self_referential_revise" "define" || true

test_case "self-referential gate artifact revise does not stop before tangle"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace stopped on a self-referential gate artifact blocker"
fi

run_embrace_case "gate_proceed_with_risks" "define" || true

test_case "proceed-with-risks gate verdict ignores non-blocking risk wording"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace stopped despite explicit PROCEED_WITH_RISKS verdict"
fi

run_embrace_case "missing_probe_output" || true

test_case "missing probe synthesis stops before grasp"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe " ]] && \
   [[ "$CHECKPOINTS" == *"probe:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not stop cleanly when probe produced no synthesis artifact"
fi

run_embrace_case "tangle_fails" || true

test_case "tangle failure stops before ink"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle " ]] && \
   [[ "$CHECKPOINTS" == *"tangle:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not stop cleanly when tangle returned non-zero"
fi

run_embrace_case "missing_ink_output" || true

test_case "missing delivery artifact fails after ink"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ "$CHECKPOINTS" == *"ink:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not fail when ink produced no delivery artifact"
fi

test_summary
