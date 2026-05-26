#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_TANGLE_FAIL=true run_embrace_case final-report-failed

[[ "$CASE_RC" -ne 0 ]] || fail "expected non-zero rc when Tangle fails"
glob_exists "$CASE_RESULTS/embrace-report-*.md" || fail "missing embrace failure report"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "missing tangle validation artifact"
glob_absent "$CASE_RESULTS/delivery-*.md" || fail "Deliver ran after failed Tangle"

report="$(ls "$CASE_RESULTS"/embrace-report-*.md | head -1)"
file_contains "Final Status: FAILED" "$report" || fail "report does not record failure"
file_contains "Stopped phase: .*tangle" "$report" || fail "report missing stopped phase"
file_contains "Reason: tangle_develop returned non-zero" "$report" || fail "report missing failure reason"
file_contains "Probe \\| present \\| .*probe-synthesis" "$report" || fail "report does not reference probe artifact"
file_contains "Grasp \\| present \\| .*grasp-consensus" "$report" || fail "report does not reference grasp artifact"
file_contains "Tangle \\| present \\| .*tangle-validation" "$report" || fail "report does not reference failed tangle artifact"
file_contains "Ink \\| not-requested \\|" "$report" || fail "report should not claim delivery artifact after failed tangle"
file_contains "Provider Status Summary" "$report" || fail "report missing provider summary"
file_contains "codex:" "$report" || fail "report missing codex provider status"
pass
