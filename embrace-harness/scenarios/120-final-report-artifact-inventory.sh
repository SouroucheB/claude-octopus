#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=both run_embrace_case final-report-success

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/embrace-report-*.md" || fail "missing embrace run report"

report="$(ls "$CASE_RESULTS"/embrace-report-*.md | head -1)"
file_contains "Final Status: SUCCESS" "$report" || fail "report does not record success"
file_contains "Artifact Inventory" "$report" || fail "report missing artifact inventory"
file_contains "Provider Status Summary" "$report" || fail "report missing provider summary"
file_contains "Report Contract" "$report" || fail "report missing report contract"
file_contains "Autonomy: .*autonomous" "$report" || fail "report did not preserve autonomous mode"
file_contains "Probe \\| present \\| .*probe-synthesis" "$report" || fail "report does not reference probe artifact"
file_contains "Grasp \\| present \\| .*grasp-consensus" "$report" || fail "report does not reference grasp artifact"
file_contains "Gate define-develop \\| present \\| .*embrace-gate-define-develop" "$report" || fail "report does not reference define gate artifact"
file_contains "Tangle \\| present \\| .*tangle-validation" "$report" || fail "report does not reference tangle artifact"
file_contains "Gate develop-deliver \\| present \\| .*embrace-gate-develop-deliver" "$report" || fail "report does not reference develop gate artifact"
file_contains "Ink \\| present \\| .*delivery" "$report" || fail "report does not reference delivery artifact"
file_contains "codex:" "$report" || fail "report missing codex provider status"
file_contains "gemini:" "$report" || fail "report missing gemini provider status"
file_contains "claude-sonnet:" "$report" || fail "report missing claude provider status"

run_dir_count=$(find "$CASE_DIR/home/workspace/runs" -mindepth 1 -maxdepth 1 -type d -name 'embrace-*' | wc -l | tr -d ' ')
[[ "$run_dir_count" -eq 1 ]] || fail "expected one stable embrace run status dir, got $run_dir_count"
pass
