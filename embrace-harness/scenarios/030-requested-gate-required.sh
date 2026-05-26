#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=both \
OCTO_FAKE_GATE_NO_OUTPUT=true \
run_embrace_case missing-gate

[[ "$CASE_RC" -ne 0 ]] || fail "expected non-zero rc when requested gate artifact is missing"
glob_exists "$CASE_RESULTS/grasp-consensus-*.md" || fail "missing grasp artifact before gate check"
glob_absent "$CASE_RESULTS/embrace-gate-define-develop-*.md" || fail "gate artifact unexpectedly exists"
glob_absent "$CASE_RESULTS/tangle-validation-*.md" || fail "Develop ran despite missing requested gate"
pass
