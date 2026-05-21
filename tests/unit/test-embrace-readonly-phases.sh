#!/usr/bin/env bash
# Regression checks for Embrace non-develop phases being explicitly read-only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

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

test_summary
