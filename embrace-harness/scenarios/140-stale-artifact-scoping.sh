#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=both OCTO_FAKE_STALE_ARTIFACTS=true run_embrace_case stale-artifacts

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with stale artifacts present, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/embrace-report-*.md" || fail "missing embrace report"

report="$(ls "$CASE_RESULTS"/embrace-report-*.md | head -1)"
file_contains "Final Status: SUCCESS" "$report" || fail "report does not record success"
! grep -q "9999999999\\|STALE_ARTIFACT_SHOULD_NOT_APPEAR" "$report" \
    || fail "report used a stale artifact from a previous run"
! grep -q "9999999999\\|STALE_ARTIFACT_SHOULD_NOT_APPEAR" "$CASE_OUT" \
    || fail "console summary used a stale artifact from a previous run"

task_group=$(sed -n 's/^- Task group: `\([^`]*\)`.*/\1/p' "$report")
[[ -n "$task_group" ]] || fail "could not extract task group from report"
file_contains "probe-synthesis-${task_group}\\.md" "$report" || fail "report does not use current probe artifact"
file_contains "grasp-consensus-${task_group}\\.md" "$report" || fail "report does not use current grasp artifact"
file_contains "tangle-validation-${task_group}\\.md" "$report" || fail "report does not use current tangle artifact"
file_contains "delivery-${task_group}\\.md" "$report" || fail "report does not use current delivery artifact"
file_contains "embrace-gate-define-develop-${task_group}\\.md" "$report" || fail "report does not use current define gate artifact"
file_contains "embrace-gate-develop-deliver-${task_group}\\.md" "$report" || fail "report does not use current develop gate artifact"
pass
