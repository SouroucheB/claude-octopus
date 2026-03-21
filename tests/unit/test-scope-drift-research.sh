#!/usr/bin/env bash
# Tests for Scope Drift Detection (CONSOLIDATED-05) and Research Report Template (CONSOLIDATED-08)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DELIVER="$PROJECT_ROOT/.claude/skills/flow-deliver.md"
RESEARCH="$PROJECT_ROOT/.claude/commands/research.md"

TEST_COUNT=0; PASS_COUNT=0; FAIL_COUNT=0
pass() { TEST_COUNT=$((TEST_COUNT+1)); PASS_COUNT=$((PASS_COUNT+1)); echo "PASS: $1"; }
fail() { TEST_COUNT=$((TEST_COUNT+1)); FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL: $1 — $2"; }

# ── Scope Drift Detection ────────────────────────────────────────────────────

if grep -qi 'Scope Drift Detection' "$DELIVER" 2>/dev/null; then
    pass "Deliver has Scope Drift Detection step"
else
    fail "Deliver has Scope Drift Detection step" "missing section"
fi

if grep -qi 'STEP 4.5' "$DELIVER" 2>/dev/null; then
    pass "Scope drift is STEP 4.5 (between orchestrate and verify)"
else
    fail "Scope drift is STEP 4.5" "wrong position"
fi

if grep -qi 'informational\|never blocks' "$DELIVER" 2>/dev/null; then
    pass "Scope drift is informational (never blocks)"
else
    fail "Scope drift is informational" "missing non-blocking language"
fi

if grep -qi 'scope creep\|unrelated' "$DELIVER" 2>/dev/null; then
    pass "Detects scope creep (unrelated changes)"
else
    fail "Detects scope creep" "missing"
fi

if grep -qi 'missing requirements\|not addressed' "$DELIVER" 2>/dev/null; then
    pass "Detects missing requirements"
else
    fail "Detects missing requirements" "missing"
fi

if grep -q 'CLEAN\|DRIFT DETECTED\|REQUIREMENTS MISSING' "$DELIVER" 2>/dev/null; then
    pass "Structured output format (CLEAN/DRIFT/MISSING)"
else
    fail "Structured output format" "missing status labels"
fi

if grep -q 'git diff --stat' "$DELIVER" 2>/dev/null; then
    pass "Uses git diff for comparison"
else
    fail "Uses git diff for comparison" "missing git diff"
fi

if grep -qi 'TODOS.md\|PR description\|commit messages' "$DELIVER" 2>/dev/null; then
    pass "Reads intent from TODOS/PR/commits"
else
    fail "Reads intent from TODOS/PR/commits" "missing intent sources"
fi

# ── Research Report Template ──────────────────────────────────────────────────

if grep -qi 'Report Format' "$RESEARCH" 2>/dev/null; then
    pass "Research has Report Format section"
else
    fail "Research has Report Format section" "missing"
fi

if grep -qi 'Executive Summary' "$RESEARCH" 2>/dev/null; then
    pass "Template includes Executive Summary"
else
    fail "Template includes Executive Summary" "missing"
fi

if grep -qi 'Key Themes' "$RESEARCH" 2>/dev/null; then
    pass "Template includes Key Themes"
else
    fail "Template includes Key Themes" "missing"
fi

if grep -qi 'Key Takeaways' "$RESEARCH" 2>/dev/null; then
    pass "Template includes Key Takeaways"
else
    fail "Template includes Key Takeaways" "missing"
fi

if grep -qi 'Sources.*Attribution' "$RESEARCH" 2>/dev/null; then
    pass "Template includes Sources & Attribution"
else
    fail "Template includes Sources & Attribution" "missing"
fi

if grep -qi 'Methodology' "$RESEARCH" 2>/dev/null; then
    pass "Template includes Methodology"
else
    fail "Template includes Methodology" "missing"
fi

if grep -qi 'Inference\|unsourced' "$RESEARCH" 2>/dev/null; then
    pass "Requires source attribution (marks inferences)"
else
    fail "Requires source attribution" "missing inference tagging"
fi

if grep -qi 'gaps\|limitations' "$RESEARCH" 2>/dev/null; then
    pass "Acknowledges gaps and limitations"
else
    fail "Acknowledges gaps and limitations" "missing"
fi

# ── No attribution ────────────────────────────────────────────────────────────

if grep -qi 'gstack\|ecc\|gsd-2\|strategic-audit' "$DELIVER" 2>/dev/null; then
    fail "Deliver has no attribution" "found reference"
else
    pass "Deliver has no attribution"
fi

if grep -qi 'ecc\|strategic-audit\|autoresearch' "$RESEARCH" 2>/dev/null; then
    fail "Research has no attribution" "found reference"
else
    pass "Research has no attribution"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo "scope-drift+research: $PASS_COUNT/$TEST_COUNT passed"
[[ $FAIL_COUNT -gt 0 ]] && echo "FAILURES: $FAIL_COUNT" && exit 1
echo "All tests passed."
