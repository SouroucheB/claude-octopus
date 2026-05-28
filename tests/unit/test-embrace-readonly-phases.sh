#!/usr/bin/env bash
# Regression checks for Embrace non-develop phases being explicitly read-only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"
DISPATCH="$PROJECT_ROOT/scripts/lib/dispatch.sh"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "embrace read-only phases"

test_case "workflows.sh has valid bash syntax"
if bash -n "$WORKFLOWS" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in workflows.sh"
fi

test_case "grasp define prompts include read-only guard"
if grep -q "This is the read-only Define phase" "$WORKFLOWS" && \
   grep -q "Do NOT modify, create, delete, stage, or commit files" "$WORKFLOWS"; then
    test_pass
else
    test_fail "grasp_define prompts do not carry a read-only guard"
fi

test_case "debate gate prompt includes read-only guard"
if sed -n '/gate_prompt=/,/Return a concise gate review/p' "$WORKFLOWS" | grep -q "This debate gate is read-only" && \
   sed -n '/gate_prompt=/,/Return a concise gate review/p' "$WORKFLOWS" | grep -q "Do NOT run shell commands that write"; then
    test_pass
else
    test_fail "embrace debate gate prompt does not carry a read-only guard"
fi

test_case "pre-Develop aborts restore non-Develop worktree mutations"
if grep -q "_capture_pre_develop_worktree_snapshot" "$WORKFLOWS" && \
   grep -q "_restore_pre_develop_worktree_snapshot" "$WORKFLOWS" && \
   grep -q "_embrace_phase_is_pre_develop_abort" "$WORKFLOWS" && \
   grep -q "debate-define-develop" "$WORKFLOWS"; then
    test_pass
else
    test_fail "pre-Develop abort restore guard is missing"
fi

test_case "codex command uses read-only sandbox outside Embrace Develop"
log() { :; }
PLUGIN_DIR="$PROJECT_ROOT"
OCTOPUS_PLATFORM="${OCTOPUS_PLATFORM:-Darwin}"
# shellcheck source=/dev/null
source "$DISPATCH"
get_agent_model() { echo "gpt-test"; }

probe_cmd=$(OCTOPUS_WORKFLOW_TYPE=embrace OCTOPUS_CODEX_SANDBOX=workspace-write get_agent_command codex probe researcher)
gate_cmd=$(OCTOPUS_WORKFLOW_TYPE=embrace OCTOPUS_CODEX_SANDBOX=workspace-write get_agent_command codex embrace-gate code-reviewer)
tangle_cmd=$(OCTOPUS_WORKFLOW_TYPE=embrace OCTOPUS_CODEX_SANDBOX=workspace-write get_agent_command codex tangle coder)

if [[ "$probe_cmd" == *"--sandbox read-only"* ]] && \
   [[ "$gate_cmd" == *"--sandbox read-only"* ]] && \
   [[ "$tangle_cmd" == *"--sandbox workspace-write"* ]]; then
    test_pass
else
    test_fail "expected read-only sandbox for probe/gate and workspace-write for tangle; probe='$probe_cmd' gate='$gate_cmd' tangle='$tangle_cmd'"
fi

test_summary
