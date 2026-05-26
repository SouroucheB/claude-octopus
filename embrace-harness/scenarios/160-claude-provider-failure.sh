#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_CLAUDE_FAIL=true run_embrace_case claude-failed

[[ "$CASE_RC" -ne 0 ]] || fail "expected non-zero rc when Claude provider fails"
glob_exists "$CASE_RESULTS/embrace-report-*.md" || fail "missing failure report"
file_contains "Final Status: FAILED" "$CASE_RESULTS"/embrace-report-*.md \
    || fail "report does not record failure"
file_contains "claude-sonnet: failed" "$CASE_RESULTS"/embrace-report-*.md \
    || fail "report does not surface Claude provider failure"
glob_absent "$CASE_RESULTS/delivery-*.md" || fail "Deliver ran after Claude provider failure"
pass
