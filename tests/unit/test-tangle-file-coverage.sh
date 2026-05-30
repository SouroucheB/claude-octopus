#!/usr/bin/env bash
# Regression checks for /octo:develop explicit file coverage validation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TESTING="$PROJECT_ROOT/scripts/lib/testing.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "tangle explicit file coverage"

test_case "testing.sh has valid bash syntax"
if bash -n "$TESTING" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in testing.sh"
fi

# shellcheck source=/dev/null
source "$TESTING"

RED=""
GREEN=""
YELLOW=""
NC=""
_BOX_TOP=""
_BOX_BOT=""
DIM=""
MAX_QUALITY_RETRIES=0
QUALITY_THRESHOLD=75
LOOP_UNTIL_APPROVED=false
CI_MODE=true
OCTOPUS_ANTISYCOPHANCY=false
OCTOPUS_FILE_VALIDATION=false
FAILED_SUBTASKS=""

log() { :; }
record_task_metric() { :; }
write_structured_decision() { :; }
retry_failed_subtasks() { :; }
evaluate_quality_branch() { echo "proceed"; }
get_gate_threshold() { echo "75"; }

RESULTS_DIR="$(mktemp -d)"
trap 'rm -rf "$RESULTS_DIR"' EXIT

write_success_result() {
    local file="$1"
    local output="$2"
    if [[ "$output" != *"## Verification"* ]]; then
        output="${output}"$'\n\n## Verification\n- Test fixture verification completed.\nTANGLE_REPORT_COMPLETE'
    fi
    cat > "$file" <<EOF
# Agent: codex
# Task ID: tangle-coverage-0
# Role: implementer
# Phase: tangle
# Prompt: Generic implementation slice

## Output
${output}

## Status: SUCCESS
EOF
}

original_prompt="Update src/lib/templates/NA10_HANDLE_SILENCE.ts and src/lib/templates/NA20_REQUEST_MISSING_INFO.ts."

write_success_result "$RESULTS_DIR/codex-tangle-coverage-0.md" \
    "Updated src/lib/templates/NA10_HANDLE_SILENCE.ts and validated tests."

test_case "missing explicit file coverage fails validation"
if validate_tangle_results "coverage" "$original_prompt" >/dev/null 2>&1; then
    test_fail "validation passed even though NA20 was never covered by any tangle output"
else
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage.md")"
    if [[ "$report" == *"Quality Gate: FAILED"* ]] && \
       [[ "$report" == *"Missing Explicit File Coverage"* ]] && \
       [[ "$report" == *"src/lib/templates/NA20_REQUEST_MISSING_INFO.ts"* ]]; then
        test_pass
    else
        test_fail "validation failed without reporting the missing explicit file coverage"
    fi
fi

rm -f "$RESULTS_DIR"/*.md
write_success_result "$RESULTS_DIR/codex-tangle-coverage-0.md" \
    "Updated src/lib/templates/NA10_HANDLE_SILENCE.ts and src/lib/templates/NA20_REQUEST_MISSING_INFO.ts."

test_case "covered explicit files keep validation passing"
if validate_tangle_results "coverage" "$original_prompt" >/dev/null 2>&1; then
    test_pass
else
    test_fail "validation failed even though all explicit files were covered"
fi

test_case "explicit file coverage requires exact file tokens"
missing=$(check_explicit_file_coverage \
    "Update src/foo.ts." \
    "Updated src/foo.tsx and src/foo.ts.bak.")
if [[ "$missing" == *"src/foo.ts"* ]]; then
    test_pass
else
    test_fail "partial filename matches were treated as exact coverage"
fi

rm -f "$RESULTS_DIR"/*.md
write_success_result "$RESULTS_DIR/codex-tangle-coverage-instruction-doc-0.md" \
    "Updated src/app/page.tsx and validated the targeted unit test."

instruction_doc_prompt=$(cat <<'EOF'
Update src/app/page.tsx.

Verification expectations:
- If UI/e2e specs are touched, follow AGENTS.md Playwright rules.
EOF
)

test_case "conditional instruction docs are not required as file coverage"
if validate_tangle_results "coverage-instruction-doc" "$instruction_doc_prompt" >/dev/null 2>&1; then
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-instruction-doc.md")"
    coverage_section="$(sed -n '/### Explicit File Coverage/,/### Worktree Change Evidence/p' "$RESULTS_DIR/tangle-validation-coverage-instruction-doc.md")"
    if [[ "$report" == *"Quality Gate: PASSED"* ]] && \
       [[ "$coverage_section" != *"AGENTS.md"* ]]; then
        test_pass
    else
        test_fail "conditional AGENTS.md instruction still appeared in coverage report"
    fi
else
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-instruction-doc.md" 2>/dev/null || true)"
    if [[ "$report" == *"AGENTS.md"* ]]; then
        test_fail "validation failed because conditional AGENTS.md instruction was treated as file coverage"
    else
        test_fail "validation failed unexpectedly for conditional instruction doc prompt"
    fi
fi

rm -f "$RESULTS_DIR"/*.md
write_success_result "$RESULTS_DIR/codex-tangle-coverage-audit-0.md" \
    "Wrote OCTO_REAL_AUDIT_REPORT.md with the scoped audit recommendation."

read_only_audit_prompt=$(cat <<'EOF'
Real Octo Embrace audit. Read OCTO_REAL_AUDIT_TASK.md and produce a scoped audit report.

Evidence to inspect:
- scripts/lib/workflows.sh
- scripts/lib/heuristics.sh
- scripts/lib/error-tracking.sh
- tests/unit/test-embrace-fail-fast.sh

Write scope:
- You may create or update only `OCTO_REAL_AUDIT_REPORT.md` in this worktree.
- Do not modify plugin source files, tests, scripts, package files, docs, or git metadata.

Report requirements:
- Final recommendation: `READY_FOR_UPSTREAM_PR_PLANNING`, `NEEDS_LOCAL_FIX`, or `INCONCLUSIVE`.
EOF
)

test_case "read-only audit evidence is not required as tangle file coverage"
if validate_tangle_results "coverage-audit" "$read_only_audit_prompt" >/dev/null 2>&1; then
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-audit.md")"
    if [[ "$report" == *"Quality Gate: PASSED"* ]] && \
       [[ "$report" != *"Missing Explicit File Coverage"* ]] && \
       [[ "$report" == *"All explicit file references from the task were covered"* ]]; then
        test_pass
    else
        test_fail "audit coverage report still treated read-only evidence as missing coverage"
    fi
else
    test_fail "validation failed because read-only evidence files were treated as write coverage"
fi

test_summary
