#!/usr/bin/env bash
# Regression checks for Grasp/Define provider fallback traceability.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "grasp define provider fallbacks"

source "$PROJECT_ROOT/scripts/lib/error-tracking.sh"
source "$PROJECT_ROOT/scripts/lib/workflows.sh"

TEST_ROOT="$(mktemp -d)"
HOME="$TEST_ROOT/home"
WORKSPACE_DIR="$TEST_ROOT/workspace"
RESULTS_DIR="$WORKSPACE_DIR/results"
LOGS_DIR="$WORKSPACE_DIR/logs"
PLUGIN_DIR="$PROJECT_ROOT"
OCTOPUS_RUN_ID="test-grasp-fallback"
OCTOPUS_TASK_GROUP="424242"
DRY_RUN=false
CYAN=""
GREEN=""
MAGENTA=""
YELLOW=""
NC=""
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$HOME"

log() { :; }
octopus_phase_banner() { :; }
display_workflow_cost_estimate() { return 0; }
run_agent_sync() {
    local agent_type="$1"
    local role="${4:-}"
    local phase="${5:-}"

    if [[ "${FAKE_GEMINI_SYNTH_FAIL:-false}" == "true" && "$agent_type" == "gemini" && "$role" == "synthesizer" && "$phase" == "grasp" ]]; then
        write_agent_status "gemini" "failed" 100 0 "Provider quota exhausted earlier in this run" 25 "" "$role"
        return 1
    fi

    if [[ "$agent_type" == "codex" && "$role" == "backend-architect" && "$phase" == "grasp" ]]; then
        write_agent_status "codex" "failed" 100 0 "Codex tool stdin closed (avoid write_stdin in non-interactive sessions)" 25 "" "$role"
        return 1
    fi

    printf '%s\n' "${agent_type}/${role}/${phase} output"
}

test_case "grasp consensus records Codex stdin-closed fallback reason"
grsp_status=0
grasp_define "Audit Octo reliability" >/dev/null 2>&1 || grsp_status=$?
consensus_file="$RESULTS_DIR/grasp-consensus-${OCTOPUS_TASK_GROUP}.md"
if [[ "$grsp_status" -eq 0 ]] && \
   [[ -f "$consensus_file" ]] && \
   grep -q "Provider Fallbacks" "$consensus_file" && \
   grep -q "Codex tool stdin closed" "$consensus_file" && \
   grep -q "fallback claude-sonnet" "$consensus_file"; then
    test_pass
else
    test_fail "expected grasp consensus to preserve Codex fallback reason (status=$grsp_status file=${consensus_file:-missing})"
fi

test_case "grasp fallback does not call consensus quality a provider degraded status"
rm -f "$RESULTS_DIR"/grasp-consensus-*.md
FAKE_GEMINI_SYNTH_FAIL=true
grsp_status=0
grasp_define "Validate Gemini failed status after quota lockout" >/dev/null 2>&1 || grsp_status=$?
consensus_file="$RESULTS_DIR/grasp-consensus-${OCTOPUS_TASK_GROUP}.md"
if [[ "$grsp_status" -eq 0 ]] && \
   [[ -f "$consensus_file" ]] && \
   grep -q "Consensus Quality: partial" "$consensus_file" && \
   ! grep -qi "degraded consensus" "$consensus_file"; then
    test_pass
else
    test_fail "expected partial consensus wording that cannot be confused with provider degraded status (status=$grsp_status file=${consensus_file:-missing})"
fi
unset FAKE_GEMINI_SYNTH_FAIL

test_summary
