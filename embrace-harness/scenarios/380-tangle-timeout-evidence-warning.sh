#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none \
OCTOPUS_HARNESS_AGENT_TIMEOUT=1 \
OCTO_HARNESS_TASK_PROMPT="Implement deterministic conformance marker in src/app/page.tsx" \
OCTO_FAKE_CODEX_TANGLE_TIMEOUT_AFTER_WRITE=true \
run_embrace_case tangle-timeout-evidence-warning

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 for timeout with verified worktree evidence, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "missing tangle validation artifact"
file_contains "Quality Gate: WARNING" "$CASE_RESULTS"/tangle-validation-*.md \
    || fail "timeout with useful evidence was not reported as a warning"
file_contains "Evidence-backed timeouts: 1/1 implementation timeout result files" "$CASE_RESULTS"/tangle-validation-*.md \
    || fail "missing evidence-backed timeout accounting"
file_contains "src/app/page.tsx" "$CASE_RESULTS"/tangle-validation-*.md \
    || fail "missing product worktree evidence"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "warning tangle did not continue to delivery"

pass
