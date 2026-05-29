#!/usr/bin/env bash
# Regression checks for /octo:develop worktree-change validation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "tangle worktree change evidence"

RESULTS_DIR="$(mktemp -d)"
REPO_DIR="$(mktemp -d)"
trap 'rm -rf "$RESULTS_DIR" "$REPO_DIR"' EXIT

GREEN=""
RED=""
YELLOW=""
DIM=""
NC=""
_BOX_TOP=""
_BOX_BOT=""
QUALITY_THRESHOLD=70
MAX_QUALITY_RETRIES=0
LOOP_UNTIL_APPROVED=false
OCTOPUS_ANTISYCOPHANCY=false

log() { :; }
record_task_metric() { :; }
write_structured_decision() { :; }
evaluate_quality_branch() { echo "proceed"; }
run_file_validation() { :; }
run_agent_sync() { echo "GENUINELY_CLEAN_TEST"; }
get_gate_threshold() { echo 70; }

source "$PROJECT_ROOT/scripts/lib/testing.sh"

write_success_result() {
    local path="$1"
    local body="$2"
    local role="${3:-implementer}"
    cat > "$path" <<EOF
# Agent: codex
# Task ID: tangle-evidence-0
# Role: $role
# Phase: tangle

## Output
$body

## Status: SUCCESS
EOF
}

write_failed_result() {
    local path="$1"
    local body="$2"
    local role="${3:-implementer}"
    cat > "$path" <<EOF
# Agent: codex
# Task ID: tangle-evidence-0
# Role: $role
# Phase: tangle

## Output
$body

## Status: FAILED (Empty output)
EOF
}

write_timeout_result() {
    local path="$1"
    local body="$2"
    local role="${3:-implementer}"
    cat > "$path" <<EOF
# Agent: codex
# Task ID: tangle-evidence-0
# Role: $role
# Phase: tangle

## Output
$body

## Status: TIMEOUT - PARTIAL RESULTS (exit code: 124)
EOF
}

git -C "$REPO_DIR" init -q
git -C "$REPO_DIR" config user.email test@example.com
git -C "$REPO_DIR" config user.name "Octopus Test"
printf 'base\n' > "$REPO_DIR/README.md"
git -C "$REPO_DIR" add README.md
git -C "$REPO_DIR" commit -q -m init

test_case "implementation prompt with no worktree change fails validation"
if (
    cd "$REPO_DIR"
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-empty.txt"
    write_success_result "$RESULTS_DIR/codex-tangle-evidence-empty.md" \
        "Implemented src/app/page.tsx conceptually; no files changed."
    if RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-empty" "Implement the app change in src/app/page.tsx" "$RESULTS_DIR/before-empty.txt" >/dev/null 2>&1; then
        exit 1
    fi
    grep -q "Missing Worktree Changes" "$RESULTS_DIR/tangle-validation-evidence-empty.md"
); then
    test_pass
else
    test_fail "validation passed despite no worktree changes"
fi

test_case "implementation prompt with new worktree path passes validation"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-change.txt"
    mkdir -p src/app
    printf 'export default function Page() { return null }\n' > src/app/page.tsx
    write_success_result "$RESULTS_DIR/codex-tangle-evidence-change.md" \
        "Changed src/app/page.tsx and wired the page."
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-change" "Implement the app change in src/app/page.tsx" "$RESULTS_DIR/before-change.txt" >/dev/null 2>&1
    grep -q "src/app/page.tsx" "$RESULTS_DIR/tangle-validation-evidence-change.md"
); then
    test_pass
else
    test_fail "validation failed despite a new worktree path"
fi

test_case "implementation prompt with verified current worktree path passes validation"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    mkdir -p src/app
    printf 'export const alreadyDone = true\n' > src/app/already-done.ts
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-current.txt"
    write_success_result "$RESULTS_DIR/codex-tangle-evidence-current.md" \
        "Verified src/app/already-done.ts is already in the target state; no extra edit required."
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-current" "Implement the app change in src/app/already-done.ts" "$RESULTS_DIR/before-current.txt" >/dev/null 2>&1
    grep -q "Tangle verified current worktree changes" "$RESULTS_DIR/tangle-validation-evidence-current.md" && \
    grep -q "src/app/already-done.ts" "$RESULTS_DIR/tangle-validation-evidence-current.md"
); then
    test_pass
else
    test_fail "validation failed despite verified current worktree evidence"
fi

test_case "reasoning-only provider lockout failures do not fail implementation score"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/gemini-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    git reset --hard -q HEAD
    printf 'baseline\n' > canary.txt
    git add canary.txt
    git commit -q -m 'add canary baseline'
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-reasoning-lockout.txt"
    printf 'baseline\nembrace-canary-after-e56\n' > canary.txt
    write_success_result "$RESULTS_DIR/codex-tangle-evidence-reasoning-lockout-0.md" \
        "Changed canary.txt by appending embrace-canary-after-e56." \
        "implementer"
    write_failed_result "$RESULTS_DIR/gemini-tangle-evidence-reasoning-lockout-1.md" \
        "Provider quota exhausted earlier in this run." \
        "researcher"
    write_failed_result "$RESULTS_DIR/gemini-tangle-evidence-reasoning-lockout-2.md" \
        "Provider quota exhausted earlier in this run." \
        "researcher"
    write_failed_result "$RESULTS_DIR/gemini-tangle-evidence-reasoning-lockout-3.md" \
        "Provider quota exhausted earlier in this run." \
        "researcher"
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-reasoning-lockout" "Modify canary.txt to append embrace-canary-after-e56" "$RESULTS_DIR/before-reasoning-lockout.txt" >/dev/null 2>&1
    grep -q "### Quality Gate: PASSED" "$RESULTS_DIR/tangle-validation-evidence-reasoning-lockout.md" && \
    grep -q "Successful: 1/1 implementation result files" "$RESULTS_DIR/tangle-validation-evidence-reasoning-lockout.md" && \
    grep -q "Reasoning-only: 0/3 successful, 3/3 failed/skipped result files (excluded from implementation score)" "$RESULTS_DIR/tangle-validation-evidence-reasoning-lockout.md"
); then
    test_pass
else
    test_fail "reasoning-only quota failures were counted against implementation quality"
fi

test_case "timeout after useful worktree evidence is a warning, not implementation failure"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-timeout-evidence.txt"
    mkdir -p src/app
    printf 'export default function Page() { return "done" }\n' > src/app/page.tsx
    write_timeout_result "$RESULTS_DIR/codex-tangle-evidence-timeout-evidence.md" \
        "Changed src/app/page.tsx before timing out."
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-timeout-evidence" "Implement the app change in src/app/page.tsx" "$RESULTS_DIR/before-timeout-evidence.txt" >/dev/null 2>&1
    grep -q "### Quality Gate: WARNING" "$RESULTS_DIR/tangle-validation-evidence-timeout-evidence.md" && \
    grep -q "Evidence-backed timeouts: 1/1 implementation timeout result files" "$RESULTS_DIR/tangle-validation-evidence-timeout-evidence.md" && \
    grep -q "src/app/page.tsx" "$RESULTS_DIR/tangle-validation-evidence-timeout-evidence.md"
); then
    test_pass
else
    test_fail "timeout with real worktree evidence was not distinguished from missing implementation evidence"
fi

test_case "timeout evidence is not blocked by unrelated resolved plan references"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-timeout-plan-noise.txt"
    mkdir -p src/app
    printf 'export default function Page() { return "done" }\n' > src/app/page.tsx
    write_timeout_result "$RESULTS_DIR/codex-tangle-evidence-timeout-plan-noise.md" \
        "Changed src/app/page.tsx before timing out."
    noisy_prompt='Implement the app change in src/app/page.tsx.

The following referenced plan file has been resolved. Use it as implementation context and do NOT modify the plan file itself (docs/BACKLOG.md).

--- PLAN: docs/BACKLOG.md ---
This backlog context mentions unrelated read-only files: AGENTS.md, AUDIT.md,
src/lib/engine/applyPerception.ts, src/lib/engine/projectDossier.ts,
and scripts/generate-snapshots.sh.
--- END PLAN ---'
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-timeout-plan-noise" "$noisy_prompt" "$RESULTS_DIR/before-timeout-plan-noise.txt" >/dev/null 2>&1
    grep -q "### Quality Gate: WARNING" "$RESULTS_DIR/tangle-validation-evidence-timeout-plan-noise.md" && \
    grep -q "Evidence-backed timeouts: 1/1 implementation timeout result files" "$RESULTS_DIR/tangle-validation-evidence-timeout-plan-noise.md" && \
    ! sed -n '/#### Missing Explicit File Coverage/,/### Worktree Change Evidence/p' "$RESULTS_DIR/tangle-validation-evidence-timeout-plan-noise.md" | grep -q "AGENTS.md"
); then
    test_pass
else
    test_fail "resolved plan context refs blocked evidence-backed timeout"
fi

test_case "timeout with only octopus internal artifacts still fails"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-timeout-internal.txt"
    mkdir -p .claude-octopus
    printf 'forged\n' > .claude-octopus/forged-worker-artifact.md
    write_timeout_result "$RESULTS_DIR/codex-tangle-evidence-timeout-internal.md" \
        "Changed src/app/page.tsx and .claude-octopus/forged-worker-artifact.md before timing out."
    if RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-timeout-internal" "Implement the app change in src/app/page.tsx" "$RESULTS_DIR/before-timeout-internal.txt" >/dev/null 2>&1; then
        exit 1
    fi
    grep -q "### Quality Gate: FAILED" "$RESULTS_DIR/tangle-validation-evidence-timeout-internal.md" && \
    grep -q "Missing Worktree Changes" "$RESULTS_DIR/tangle-validation-evidence-timeout-internal.md"
); then
    test_pass
else
    test_fail "timeout with only runner-owned artifact changes was treated as implementation evidence"
fi

test_case "octopus internal artifacts are not worktree evidence"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    mkdir -p .claude-octopus .octo results
    printf '{}\n' > .claude-octopus/state.json
    printf '{}\n' > .octo/state.json
    printf 'artifact\n' > results/output.md
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/internal-paths.txt"
    ! grep -qE '^(\.claude-octopus|\.octo|results)(/|$)' "$RESULTS_DIR/internal-paths.txt"
); then
    test_pass
else
    test_fail "octopus internal paths were counted as implementation evidence"
fi

test_case "analysis prompt does not require worktree changes"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-analysis.txt"
    write_success_result "$RESULTS_DIR/codex-tangle-evidence-analysis.md" \
        "Architecture analysis only."
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-analysis" "Analyze architecture tradeoffs" "$RESULTS_DIR/before-analysis.txt" >/dev/null 2>&1
    grep -q "Not required for this prompt." "$RESULTS_DIR/tangle-validation-evidence-analysis.md"
); then
    test_pass
else
    test_fail "analysis prompt unexpectedly required worktree changes"
fi

test_case "truncated verification report fails validation"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-truncated-report.txt"
    mkdir -p src/app
    printf 'export default function Page() { return "done" }\n' > src/app/page.tsx
    write_success_result "$RESULTS_DIR/codex-tangle-evidence-truncated-report.md" \
        $'## Worktree Changes\n- src/app/page.tsx\n\n## Integration Evidence\n- src/app/page.tsx is wired in the worktree.\n\n## Verification\n- canary.txt co'
    if RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-truncated-report" "Implement the app change in src/app/page.tsx" "$RESULTS_DIR/before-truncated-report.txt" >/dev/null 2>&1; then
        exit 1
    fi
    grep -q "Truncated or incomplete Tangle report" "$RESULTS_DIR/tangle-validation-evidence-truncated-report.md"
); then
    test_pass
else
    test_fail "truncated Verification section was accepted as a successful implementation report"
fi

test_case "state-json-only gate proof fails validation"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-state-only-gate-proof.txt"
    mkdir -p src/app
    printf 'export default function Page() { return "done" }\n' > src/app/page.tsx
    write_success_result "$RESULTS_DIR/codex-tangle-evidence-state-only-gate-proof.md" \
        $'## Worktree Changes\n- src/app/page.tsx\n\n## Integration Evidence\n- src/app/page.tsx is wired in the worktree.\n\n## Verification\n- Verified .claude-octopus/state.json contains embrace_debate_gate/define-develop, so the gate was evaluated.\nTANGLE_REPORT_COMPLETE'
    if RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-state-only-gate-proof" "Implement the app change in src/app/page.tsx" "$RESULTS_DIR/before-state-only-gate-proof.txt" >/dev/null 2>&1; then
        exit 1
    fi
    grep -q "State-only gate execution proof" "$RESULTS_DIR/tangle-validation-evidence-state-only-gate-proof.md"
); then
    test_pass
else
    test_fail "state.json-only gate proof was accepted as current-run gate execution evidence"
fi

test_case "state-json insufficiency warning does not fail validation"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    git reset --hard -q HEAD
    git clean -fdq
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-state-warning.txt"
    mkdir -p src/app
    printf 'export default function Page() { return "done" }\n' > src/app/page.tsx
    write_success_result "$RESULTS_DIR/codex-tangle-evidence-state-warning.md" \
        $'## Worktree Changes\n- src/app/page.tsx\n\n## Integration Evidence\n- src/app/page.tsx is wired in the worktree.\n\n## Verification\n- Octopus state.json alone is not proof that a Define to Develop gate executed.\nTANGLE_REPORT_COMPLETE'
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-state-warning" "Implement the app change in src/app/page.tsx" "$RESULTS_DIR/before-state-warning.txt" >/dev/null 2>&1
    grep -q "No truncated reports or state-only gate proofs detected." "$RESULTS_DIR/tangle-validation-evidence-state-warning.md"
); then
    test_pass
else
    test_fail "state.json insufficiency warning was treated as a state-only gate proof"
fi

test_case "failed quality gate writes validation report before abort"
if (
    cd "$REPO_DIR"
    rm -f "$RESULTS_DIR"/codex-tangle-evidence-*.md "$RESULTS_DIR"/tangle-validation-evidence-*.md
    snapshot_tangle_worktree_paths > "$RESULTS_DIR/before-abort.txt"
    write_failed_result "$RESULTS_DIR/codex-tangle-evidence-abort.md" \
        "Provider produced no usable implementation."
    evaluate_quality_branch() { echo "abort"; }
    if RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "evidence-abort" "Implement the app change in src/app/page.tsx" "$RESULTS_DIR/before-abort.txt" >/dev/null 2>&1; then
        exit 1
    fi
    grep -q "### Quality Gate: FAILED" "$RESULTS_DIR/tangle-validation-evidence-abort.md" && \
    grep -q "Decision Branch: abort" "$RESULTS_DIR/tangle-validation-evidence-abort.md" && \
    grep -q "threshold: 70%" "$RESULTS_DIR/tangle-validation-evidence-abort.md" && \
    grep -q "Failed: 1/1 implementation result files" "$RESULTS_DIR/tangle-validation-evidence-abort.md"
); then
    test_pass
else
    test_fail "abort path did not leave a useful validation report"
fi

test_summary
