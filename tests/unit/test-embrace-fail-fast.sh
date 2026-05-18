#!/usr/bin/env bash
# Regression checks for /octo:embrace hardcoded phase fail-fast behavior.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

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
save_session_checkpoint() {
    CHECKPOINTS+="${1}:${2}:${3:-}"$'\n'
}

probe_discover() {
    PHASE_CALLS+="probe "
    [[ "$CASE_NAME" == "missing_probe_output" ]] && return 0
    printf '%s\n' "# probe synthesis" > "$RESULTS_DIR/probe-synthesis-test.md"
}

grasp_define() {
    PHASE_CALLS+="grasp "
    printf '%s\n' "# grasp consensus" > "$RESULTS_DIR/grasp-consensus-test.md"
}

tangle_develop() {
    PHASE_CALLS+="tangle "
    if [[ "$CASE_NAME" == "tangle_fails" ]]; then
        return 7
    fi
    printf '%s\n' "### Quality Gate: PASSED" > "$RESULTS_DIR/tangle-validation-test.md"
}

ink_deliver() {
    PHASE_CALLS+="ink "
    [[ "$CASE_NAME" == "missing_ink_output" ]] && return 0
    printf '%s\n' "# delivery" > "$RESULTS_DIR/delivery-test.md"
}

run_embrace_case() {
    CASE_NAME="$1"
    PHASE_CALLS=""
    CHECKPOINTS=""
    EMBRACE_STATUS=0
    rm -rf "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR"
    mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR" "$HOME"

    if embrace_full_workflow "Implement the requested feature" >/dev/null 2>&1; then
        EMBRACE_STATUS=0
    else
        EMBRACE_STATUS=$?
    fi
}

run_embrace_case "missing_probe_output"

test_case "missing probe synthesis stops before grasp"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe " ]] && \
   [[ "$CHECKPOINTS" == *"probe:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not stop cleanly when probe produced no synthesis artifact"
fi

run_embrace_case "tangle_fails"

test_case "tangle failure stops before ink"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle " ]] && \
   [[ "$CHECKPOINTS" == *"tangle:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not stop cleanly when tangle returned non-zero"
fi

run_embrace_case "missing_ink_output"

test_case "missing delivery artifact fails after ink"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ "$CHECKPOINTS" == *"ink:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not fail when ink produced no delivery artifact"
fi

test_summary
