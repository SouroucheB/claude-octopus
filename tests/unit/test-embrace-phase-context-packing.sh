#!/usr/bin/env bash
# Regression checks for bounded Embrace phase-to-phase artifact context.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "embrace phase context packing"

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
WORKSPACE_DIR="$TEST_ROOT/workspace"
RESULTS_DIR="$WORKSPACE_DIR/results"
LOGS_DIR="$WORKSPACE_DIR/logs"
CAPTURE_DIR="$TEST_ROOT/captured-prompts"
PLUGIN_DIR="$PROJECT_ROOT"
OCTOPUS_RUN_ID="test-phase-context"
OCTOPUS_TASK_GROUP="phasectx"
DRY_RUN=false
TMUX_MODE=false
SUPPORTS_PARALLEL_FILE_SAFETY=false
CYAN=""
GREEN=""
MAGENTA=""
YELLOW=""
NC=""
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$HOME" "$WORKSPACE_DIR/.octo/agents" "$RESULTS_DIR" "$LOGS_DIR" "$CAPTURE_DIR"

log() { :; }
octopus_phase_banner() { :; }
display_workflow_cost_estimate() { return 0; }
reset_provider_lockouts() { :; }
design_review_ceremony() { :; }
fleet_dispatch_begin() { :; }
fleet_dispatch_end() { :; }
validate_tangle_results() { :; }

make_payload() {
    local token="$1"
    local count="$2"
    local i
    for i in $(seq 1 "$count"); do
        printf '%s line %04d: repeated phase artifact context that must stay bounded\n' "$token" "$i"
    done
}

run_agent_sync() {
    local agent_type="$1"
    local prompt="$2"
    local role="${4:-}"
    local phase="${5:-}"

    printf '%s' "$prompt" > "$CAPTURE_DIR/${phase}-${agent_type}-${role}.prompt"

    if [[ "$phase" == "tangle" ]]; then
        cat <<'EOF'
1. [CODING] Touch the explicit app file. Files: src/app/page.tsx
EOF
        return 0
    fi

    printf '%s\n' "${agent_type}/${role}/${phase} output"
}

spawn_agent_capture_pid() {
    local _agent="$1"
    local prompt="$2"
    local task_id="$3"
    printf '%s' "$prompt" > "$CAPTURE_DIR/${task_id}.prompt"
    printf '0\n' > "$WORKSPACE_DIR/.octo/agents/${task_id}.done"
    printf '12345\n'
}

probe_file="$RESULTS_DIR/probe-synthesis-${OCTOPUS_TASK_GROUP}.md"
grasp_file="$RESULTS_DIR/grasp-consensus-${OCTOPUS_TASK_GROUP}.md"

{
    echo "# Probe Synthesis"
    echo "[Synthesis failed - raw results attached]"
    make_payload "PROBE_CONTEXT" 220
    echo "PROBE_RAW_TAIL_SHOULD_NOT_APPEAR"
} > "$probe_file"

{
    echo "# Grasp Consensus"
    make_payload "GRASP_CONTEXT" 220
    echo "GRASP_RAW_TAIL_SHOULD_NOT_APPEAR"
} > "$grasp_file"

OCTOPUS_GRASP_CONTEXT_CHARS=1000
OCTOPUS_TANGLE_CONTEXT_CHARS=1000

test_case "grasp prompts receive bounded probe artifact context"
rm -f "$CAPTURE_DIR"/*.prompt
grasp_define "Audit bounded phase context" "$probe_file" >/dev/null 2>&1
grasp_prompts="$(cat "$CAPTURE_DIR"/grasp-*.prompt)"
if [[ "$grasp_prompts" == *"truncated by embrace phase context"* ]] && \
   [[ "$grasp_prompts" == *"Upstream phase synthesis failed; raw fallback omitted"* ]] && \
   [[ "$grasp_prompts" != *"[Synthesis failed - raw results attached]"* ]] && \
   [[ "$grasp_prompts" != *"PROBE_RAW_TAIL_SHOULD_NOT_APPEAR"* ]]; then
    test_pass
else
    test_fail "grasp prompts received raw or unbounded probe artifact context"
fi

test_case "tangle decomposition receives bounded grasp artifact context"
rm -f "$CAPTURE_DIR"/*.prompt
{
    echo "# Grasp Consensus"
    make_payload "GRASP_CONTEXT" 220
    echo "GRASP_RAW_TAIL_SHOULD_NOT_APPEAR"
} > "$grasp_file"
tangle_develop "Implement bounded phase context" "$grasp_file" >/dev/null 2>&1
tangle_prompt="$(cat "$CAPTURE_DIR"/tangle-*.prompt)"
if [[ "$tangle_prompt" == *"truncated by embrace phase context"* ]] && \
   [[ "$tangle_prompt" != *"GRASP_RAW_TAIL_SHOULD_NOT_APPEAR"* ]]; then
    test_pass
else
    test_fail "tangle decomposition received raw or unbounded grasp artifact context"
fi

test_case "phase artifact context omits runner-owned absolute paths"
runner_owned_file="$TEST_ROOT/.claude-octopus/results/probe-synthesis-runner.md"
mkdir -p "$(dirname "$runner_owned_file")"
printf '%s\n' "# Probe" "small bounded context" > "$runner_owned_file"
runner_context="$(build_embrace_phase_artifact_context "$runner_owned_file" "Previous research findings" 1000)"
if [[ "$runner_context" == *"probe-synthesis-runner.md"* ]] && \
   [[ "$runner_context" != *".claude-octopus"* ]] && \
   [[ "$runner_context" != *"$TEST_ROOT"* ]]; then
    test_pass
else
    test_fail "phase artifact context leaked runner-owned absolute path"
fi

test_summary
