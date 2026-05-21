#!/usr/bin/env bash
# Regression checks for relevant-only Embrace observation injection.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "embrace observation scope"

QUALITY="$PROJECT_ROOT/scripts/lib/quality.sh"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

test_case "quality/workflows have valid bash syntax"
if bash -n "$QUALITY" 2>/dev/null && bash -n "$WORKFLOWS" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in quality.sh or workflows.sh"
fi

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
WORKSPACE_DIR="$TEST_ROOT/workspace"
mkdir -p "$WORKSPACE_DIR/.octo"

cat > "$WORKSPACE_DIR/.octo/decisions.md" <<'EOF'
### type: quality-gate | timestamp: 2026-05-01T00:00:00Z | source: unrelated
**ID:** D-unrelated
**Summary:** Quality gate PASSED for old tangle scope.
**Scope:** tangle-1777657809
**Confidence:** high
**Importance:** 8
**Rationale:** Old global observation that must not leak into unrelated tasks.
---

### type: quality-gate | timestamp: 2026-05-01T00:00:01Z | source: relevant
**ID:** D-relevant
**Summary:** canary.txt needs exact one-line validation.
**Scope:** canary.txt
**Confidence:** high
**Importance:** 8
**Rationale:** Relevant file-level observation.
---
EOF

log() { :; }
source "$QUALITY"
source "$WORKFLOWS"

test_case "keyword extraction includes root files"
keywords="$(embrace_observation_keywords "update canary.txt and keep README.md unchanged")"
if [[ "$keywords" == *"canary.txt"* && "$keywords" == *"README.md"* ]]; then
    test_pass
else
    test_fail "root file keywords were not extracted: ${keywords:-<empty>}"
fi

test_case "unrelated high-importance observations are not injected"
context="$(embrace_build_observation_context "update canary.txt" 7 1500)"
if [[ "$context" == *"D-relevant"* && "$context" != *"D-unrelated"* ]]; then
    test_pass
else
    test_fail "observation context was not relevance-filtered: ${context:-<empty>}"
fi

test_case "tasks without extracted keywords inject no global observations"
context="$(embrace_build_observation_context "small unrelated housekeeping task" 7 1500)"
if [[ -z "$context" ]]; then
    test_pass
else
    test_fail "global observations leaked into keywordless task: $context"
fi

test_summary
