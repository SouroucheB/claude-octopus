#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_CODEX_EMPTY_TANGLE=true run_embrace_case codex-empty

[[ "$CASE_RC" -ne 0 ]] || fail "expected non-zero rc when Codex returns true empty output"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "missing tangle validation artifact"
glob_absent "$CASE_RESULTS/delivery-*.md" || fail "Deliver ran after true Codex empty output"
file_contains "Status: FAILED \\(Empty output\\)" "$CASE_RESULTS"/*codex*tangle-*.md \
    || fail "true Codex empty output was not reported distinctly"
glob_exists "$CASE_RESULTS/embrace-report-*.md" || fail "missing failure report"
file_contains "codex: failed - Empty output" "$CASE_RESULTS"/embrace-report-*.md \
    || fail "failure report does not surface true Codex empty output"
pass
