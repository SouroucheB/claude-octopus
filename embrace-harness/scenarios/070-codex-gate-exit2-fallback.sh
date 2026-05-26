#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=both \
OCTO_FAKE_CODEX_GATE_EXIT2=true \
run_embrace_case codex-gate-exit2

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 when Codex gate fails but Gemini/Claude provide gate output, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/embrace-gate-define-develop-*.md" || fail "missing define->develop gate artifact"
glob_exists "$CASE_RESULTS/embrace-gate-develop-deliver-*.md" || fail "missing develop->deliver gate artifact"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "Develop did not run after degraded gate"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "Deliver did not run after degraded gate"
file_contains "Provider Statuses.*codex=failed, gemini=ok, claude=ok" "$CASE_RESULTS"/embrace-gate-*.md \
    || fail "gate artifact did not record Codex failed with Gemini/Claude ok"
pass
