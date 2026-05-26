#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_LOW_REVIEW_SCORE=true run_embrace_case low-score

[[ "$CASE_RC" -ne 0 ]] || fail "expected non-zero rc when Deliver review score is below threshold"
glob_exists "$CASE_RESULTS/embrace-report-*.md" || fail "missing failure report"
glob_absent "$CASE_RESULTS/delivery-*.md" || fail "Deliver wrote final artifact despite low review score"
file_contains "Final Status: FAILED" "$CASE_RESULTS"/embrace-report-*.md \
    || fail "report does not mark failed final status"
file_contains "Deliver quality gate FAILED" "$CASE_OUT" \
    || fail "console output does not explain low-score gate failure"
file_contains "claude-sonnet: ok" "$CASE_RESULTS"/embrace-report-*.md \
    || fail "provider success was not preserved separately from low-score gate failure"
pass
