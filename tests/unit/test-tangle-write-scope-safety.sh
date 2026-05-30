#!/usr/bin/env bash
# Regression checks for /octo:develop parallel write-scope safety.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "tangle write-scope safety"

test_case "workflows.sh has valid bash syntax"
if bash -n "$WORKFLOWS" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in workflows.sh"
fi

# shellcheck source=/dev/null
source "$WORKFLOWS"

CYAN=""
GREEN=""
MAGENTA=""
NC=""
TMUX_MODE=false
DRY_RUN=false
SUPPORTS_PARALLEL_FILE_SAFETY=false
RESULTS_DIR="$(mktemp -d)"
LOGS_DIR="$RESULTS_DIR/logs"
WORKSPACE_DIR="$RESULTS_DIR/workspace"
mkdir -p "$WORKSPACE_DIR/.octo/agents"
trap 'rm -rf "$RESULTS_DIR"' EXIT

DIRECT_PROMPT=""
DIRECT_TASK_ID=""
PARALLEL_SPAWNED=false
VALIDATION_CALLED=false

log() { :; }
octopus_phase_banner() { :; }
display_workflow_cost_estimate() { return 0; }
reset_provider_lockouts() { :; }
design_review_ceremony() { :; }
fleet_dispatch_begin() { :; }
fleet_dispatch_end() { :; }
run_agent_sync() {
    cat <<'EOF'
1. [CODING] Add the reference prefix. Files: src/lib/templates/NA02_REQUEST_REPORT.ts
2. [CODING] Add legal wording to the same template. Files: src/lib/templates/NA02_REQUEST_REPORT.ts, src/lib/legal/legalReferenceCatalog.ts
EOF
}
spawn_agent_capture_pid() {
    PARALLEL_SPAWNED=true
    printf '12345\n'
}
spawn_agent() {
    DIRECT_PROMPT="$2"
    DIRECT_TASK_ID="$3"
}
validate_tangle_results() {
    VALIDATION_CALLED=true
}

test_case "directory write scopes overlap contained files"
if tangle_scopes_overlap "src/lib/templates/" "src/lib/templates/NA02_REQUEST_REPORT.ts" && \
   ! tangle_scopes_overlap "src/lib/templates/" "src/lib/legal/legalReferenceCatalog.ts"; then
    test_pass
else
    test_fail "directory/file overlap detection is incorrect"
fi

test_case "absolute and relative scopes overlap inside workspace"
absolute_scope="${WORKSPACE_DIR}/src/lib/templates/NA02_REQUEST_REPORT.ts"
relative_scope="src/lib/templates/NA02_REQUEST_REPORT.ts"
if tangle_scopes_overlap "$absolute_scope" "$relative_scope"; then
    test_pass
else
    test_fail "absolute and relative paths to the same file were treated as disjoint"
fi

test_case "absolute write scopes are recognized"
absolute_subtasks="1. [CODING] Update canary. Files: /private/tmp/embrace-canary.abc/canary.txt"
if tangle_validate_parallel_write_scopes "$absolute_subtasks"; then
    test_pass
else
    test_fail "absolute Files: scope was treated as missing"
fi

test_case "root file write scopes are recognized"
root_file_subtasks="1. [CODING] Update canary. Files: \`canary.txt\`. Rationale: single root file."
if tangle_validate_parallel_write_scopes "$root_file_subtasks"; then
    test_pass
else
    test_fail "root file Files: scope was treated as missing"
fi

test_case "multi-line Files clauses are recognized"
multiline_file_subtasks="1. [CODING] Minimal canary mutation
   Inputs: \`task.md\`, current \`canary.txt\`.
   Files: \`canary.txt\` only.
   Expected output: append the canary line.

2. [REASONING] Validate read-only probe behavior
   Inputs: git status."
if tangle_validate_parallel_write_scopes "$multiline_file_subtasks"; then
    test_pass
else
    test_fail "multi-line Files: scope was treated as missing"
fi

test_case "runner-owned artifact scopes are not delegated to worker prompts"
runner_owned_prompt=$(build_tangle_subtask_prompt \
    "Validate the full Embrace workflow while changing validation.txt only." \
    "Apply the marker and update workflow artifacts. Files: \`validation.txt\`, \`.claude-octopus/\`, \`results/tangle-validation-123.md\`, \`tangle-validation-123.md\`, \`delivery-123.md\`")
if [[ "$runner_owned_prompt" == *"validation.txt"* ]] && \
   [[ "$runner_owned_prompt" != *".claude-octopus"* ]] && \
   [[ "$runner_owned_prompt" != *"results/"* ]] && \
   [[ "$runner_owned_prompt" != *"tangle-validation-123.md"* ]] && \
   [[ "$runner_owned_prompt" != *"delivery-123.md"* ]] && \
   [[ "$runner_owned_prompt" == *"Runner-owned Octopus artifacts"* ]]; then
    test_pass
else
    test_fail "worker prompt delegated runner-owned artifacts: $runner_owned_prompt"
fi

test_case "reasoning subtasks avoid locked Gemini"
is_provider_locked() { [[ "$1" == "gemini" ]]; }
is_provider_quota_exhausted() { [[ "$1" == "gemini" ]]; }
selection=$(tangle_select_subtask_agent "2. [REASONING] Validate orchestration artifacts")
IFS='|' read -r selected_agent selected_role _selected_icon <<< "$selection"
if [[ "$selected_agent" == "codex" && "$selected_role" == "researcher" ]]; then
    test_pass
else
    test_fail "locked Gemini was still selected for a reasoning subtask: $selection"
fi
unset -f is_provider_locked is_provider_quota_exhausted

original_prompt="Update src/lib/templates/NA02_REQUEST_REPORT.ts and src/lib/legal/legalReferenceCatalog.ts without producing duplicate subject prefixes."

tangle_develop "$original_prompt" >/dev/null

test_case "overlapping coding scopes fall back to direct execution"
if [[ "$DIRECT_TASK_ID" == tangle-*-direct ]] && [[ "$PARALLEL_SPAWNED" == "false" ]]; then
    test_pass
else
    test_fail "overlapping write scopes were still spawned in parallel"
fi

test_case "direct fallback explains unsafe parallel decomposition"
if [[ "$DIRECT_PROMPT" == *"parallel decomposition is unsafe"* ]] && \
   [[ "$DIRECT_PROMPT" == *"overlaps"* ]] && \
   [[ "$DIRECT_PROMPT" == *"src/lib/templates/NA02_REQUEST_REPORT.ts"* ]]; then
    test_pass
else
    test_fail "direct fallback prompt did not preserve the overlap reason and original scope"
fi

test_case "unsafe direct fallback keeps full-task scope"
if [[ "$DIRECT_PROMPT" == *"single Tangle implementer"* ]] && \
   [[ "$DIRECT_PROMPT" != *"exclusive write scope"* ]]; then
    test_pass
else
    test_fail "unsafe direct fallback still inherited subtask exclusive write scope"
fi

test_case "unsafe fallback still runs tangle validation"
if [[ "$VALIDATION_CALLED" == "true" ]]; then
    test_pass
else
    test_fail "unsafe direct fallback returned before producing tangle validation"
fi

test_summary
