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
REPO_DIR="$(mktemp -d)"
trap 'rm -rf "$RESULTS_DIR" "$REPO_DIR"' EXIT

git -C "$REPO_DIR" init -q
git -C "$REPO_DIR" config user.email test@example.com
git -C "$REPO_DIR" config user.name "Octopus Test"
printf 'base\n' > "$REPO_DIR/README.md"
git -C "$REPO_DIR" add README.md
git -C "$REPO_DIR" commit -q -m init

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

write_scoped_success_result() {
    local file="$1"
    local scope="$2"
    local output="$3"
    if [[ "$output" != *"## Verification"* ]]; then
        output="${output}"$'\n\n## Verification\n- Test fixture verification completed.\nTANGLE_REPORT_COMPLETE'
    fi
    cat > "$file" <<EOF
# Agent: codex
# Task ID: tangle-coverage-0
# Role: implementer
# Phase: tangle
# Prompt: Original task context:
Implement scoped file coverage fixture.

Assigned subtask:
[CODING] Implement scoped fixture.
Files: ${scope}

Execution instructions:
- Complete the assigned subtask.
# Started: Mon Jun  1 00:00:00 CEST 2026

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
write_success_result "$RESULTS_DIR/codex-tangle-coverage-degraded-no-worktree-0.md" \
    "Updated src/lib/templates/NA10_HANDLE_SILENCE.ts and validated tests."

test_case "no worktree evidence falls back to prose coverage"
if validate_tangle_results "coverage-degraded-no-worktree" "$original_prompt" >/dev/null 2>&1; then
    test_fail "validation passed without worktree evidence or prose coverage for NA20"
else
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-degraded-no-worktree.md")"
    if [[ "$report" == *"Quality Gate: FAILED"* ]] && \
       [[ "$report" == *"Missing Explicit File Coverage"* ]] && \
       [[ "$report" == *"src/lib/templates/NA20_REQUEST_MISSING_INFO.ts"* ]]; then
        test_pass
    else
        test_fail "no-worktree fallback did not report missing prose coverage"
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
       [[ "$report" == *"All explicit file references from the assigned implementation scope were covered"* ]]; then
        test_pass
    else
        test_fail "audit coverage report still treated read-only evidence as missing coverage"
    fi
else
    test_fail "validation failed because read-only evidence files were treated as write coverage"
fi

rm -f "$RESULTS_DIR"/*.md
inspect_only_prompt=$(cat <<'EOF'
Task: fix Gmail threading.

Inspect outbound paths:
- src/services/commands/sendDraft.server.ts
- src/services/commands/addEmail.server.ts
- src/lib/email/sendEmail.server.ts

Implement the local threading fix.
EOF
)

cat > "$RESULTS_DIR/codex-tangle-coverage-inspect-scope-0.md" <<'EOF'
# Agent: codex
# Task ID: tangle-coverage-inspect-scope-0
# Role: implementer
# Phase: tangle
# Prompt: Original task context:
Inspect outbound paths:
- src/services/commands/sendDraft.server.ts
- src/services/commands/addEmail.server.ts
- src/lib/email/sendEmail.server.ts

Assigned subtask:
[CODING] Implement threading propagation.
Files: src/services/commands/sendDraft.server.ts, src/lib/email/sendEmail.server.ts

Execution instructions:
- Complete the assigned subtask.
# Started: Mon Jun  1 00:00:00 CEST 2026

## Output
## Worktree Changes
- src/services/commands/sendDraft.server.ts
- src/lib/email/sendEmail.server.ts

## Integration Evidence
- Threading metadata is propagated through sendDraft and sendEmail.

## Verification
- Targeted threading tests pass.
TANGLE_REPORT_COMPLETE

## Status: SUCCESS
EOF

test_case "success coverage uses assigned subtask scope, not inspect-only original prompt refs"
if validate_tangle_results "coverage-inspect-scope" "$inspect_only_prompt" >/dev/null 2>&1; then
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-inspect-scope.md")"
    coverage_section="$(sed -n '/### Explicit File Coverage/,/### Worktree Change Evidence/p' "$RESULTS_DIR/tangle-validation-coverage-inspect-scope.md")"
    if [[ "$report" == *"Quality Gate: PASSED"* ]] && \
       [[ "$coverage_section" != *"src/services/commands/addEmail.server.ts"* ]]; then
        test_pass
    else
        test_fail "inspect-only addEmail.server.ts still appeared in missing success-path coverage"
    fi
else
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-inspect-scope.md" 2>/dev/null || true)"
    if [[ "$report" == *"src/services/commands/addEmail.server.ts"* ]]; then
        test_fail "validation failed because inspect-only addEmail.server.ts was required as success-path coverage"
    else
        test_fail "validation failed unexpectedly for assigned-scope success coverage"
    fi
fi

rm -f "$RESULTS_DIR"/*.md
cat > "$RESULTS_DIR/codex-tangle-coverage-stderr-proof-0.md" <<'EOF'
# Agent: codex
# Task ID: tangle-coverage-stderr-proof-0
# Role: implementer
# Phase: tangle
# Prompt: Original task context:
Update src/app/page.tsx.

Assigned subtask:
[CODING] Implement page update.
Files: src/app/page.tsx

Execution instructions:
- Complete the assigned subtask.
# Started: Mon Jun  1 00:00:00 CEST 2026

## Output
Codex response was emitted on stderr; see Warnings/Errors transcript below.

## Verification
- Targeted fixture verification completed.
TANGLE_REPORT_COMPLETE

## Status: SUCCESS

## Warnings/Errors
## Worktree Changes
- src/app/page.tsx

## Verification
- stderr transcript includes the worktree evidence.
TANGLE_REPORT_COMPLETE
EOF

test_case "success coverage accepts file evidence emitted on stderr"
if validate_tangle_results "coverage-stderr-proof" "Update src/app/page.tsx." >/dev/null 2>&1; then
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-stderr-proof.md")"
    if [[ "$report" == *"Quality Gate: PASSED"* ]] && \
       [[ "$report" != *"Missing Explicit File Coverage"* ]]; then
        test_pass
    else
        test_fail "stderr file evidence was still reported as missing explicit coverage"
    fi
else
    test_fail "validation failed even though stderr transcript covered the assigned file"
fi

test_case "glob scope is satisfied by matching concrete spec worktree change"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-glob-spec.txt"
    mkdir -p src/services/commands/__tests__
    printf 'test("foo", () => {})\n' > src/services/commands/__tests__/foo.spec.ts
    write_scoped_success_result "$RESULTS_DIR/codex-tangle-coverage-glob-spec-0.md" \
        "src/services/commands/**/*.spec.ts" \
        $'## Worktree Changes\n- src/services/commands/__tests__/foo.spec.ts'
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "coverage-glob-spec" "Implement tests in src/services/commands/**/*.spec.ts" "$RESULTS_DIR/before-glob-spec.txt" >/dev/null 2>&1
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-glob-spec.md")"
    coverage_section="$(sed -n '/### Explicit File Coverage/,/### Worktree Change Evidence/p' "$RESULTS_DIR/tangle-validation-coverage-glob-spec.md")"
    [[ "$report" == *"Quality Gate: PASSED"* ]] && \
    [[ "$coverage_section" != *".spec.ts"* ]] && \
    [[ "$coverage_section" != *"Out-of-Scope Worktree Changes"* ]] && \
    [[ "$coverage_section" != *"Missing Worktree Evidence For Explicit Files"* ]]
); then
    test_pass
else
    test_fail "glob declared scope was not satisfied by a concrete matching spec file"
fi

test_case "declared-but-untouched scope files are advisory under containment"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-containment-subset.txt"
    mkdir -p src/services/commands src/lib/email
    printf 'send draft\n' > src/services/commands/sendDraft.server.ts
    printf 'send email\n' > src/lib/email/sendEmail.server.ts
    write_scoped_success_result "$RESULTS_DIR/codex-tangle-coverage-containment-subset-0.md" \
        "src/services/commands/sendDraft.server.ts, src/lib/email/sendEmail.server.ts, src/services/commands/addEmail.server.ts" \
        $'## Worktree Changes\n- src/services/commands/sendDraft.server.ts\n- src/lib/email/sendEmail.server.ts\n\n## Integration Evidence\n- src/services/commands/addEmail.server.ts was inspected and ruled out because it does not call sendEmail.'
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "coverage-containment-subset" "Implement threading in src/services/commands/sendDraft.server.ts, src/lib/email/sendEmail.server.ts, and inspect src/services/commands/addEmail.server.ts" "$RESULTS_DIR/before-containment-subset.txt" >/dev/null 2>&1
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-containment-subset.md")"
    [[ "$report" == *"Quality Gate: PASSED"* ]] && \
    [[ "$report" == *"Declared-but-untouched (advisory)"* ]] && \
    [[ "$report" == *"src/services/commands/addEmail.server.ts"* ]] && \
    [[ "$report" != *"Out-of-Scope Worktree Changes"* ]]
); then
    test_pass
else
    test_fail "declared but untouched file was still treated as a hard coverage failure"
fi

test_case "new out-of-scope worktree changes fail containment"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-out-of-scope.txt"
    mkdir -p src/services/commands src/app
    printf 'send draft\n' > src/services/commands/sendDraft.server.ts
    printf 'page\n' > src/app/page.tsx
    write_scoped_success_result "$RESULTS_DIR/codex-tangle-coverage-out-of-scope-0.md" \
        "src/services/commands/sendDraft.server.ts" \
        $'## Worktree Changes\n- src/services/commands/sendDraft.server.ts\n- src/app/page.tsx'
    if RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "coverage-out-of-scope" "Implement threading in src/services/commands/sendDraft.server.ts" "$RESULTS_DIR/before-out-of-scope.txt" >/dev/null 2>&1; then
        exit 1
    fi
    report="$(cat "$RESULTS_DIR/tangle-validation-coverage-out-of-scope.md")"
    [[ "$report" == *"Quality Gate: FAILED"* ]] && \
    [[ "$report" == *"Out-of-Scope Worktree Changes"* ]] && \
    [[ "$report" == *"src/app/page.tsx"* ]]
); then
    test_pass
else
    test_fail "out-of-scope worktree change did not fail containment"
fi

test_summary
