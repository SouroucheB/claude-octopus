#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_TANGLE_FAIL=true run_embrace_case tangle-failed

[[ "$CASE_RC" -ne 0 ]] || fail "expected non-zero rc when Tangle fails"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "missing tangle validation artifact"
glob_absent "$CASE_RESULTS/delivery-*.md" || fail "Deliver ran after failed Tangle"
file_contains "Quality Gate: FAILED" "$CASE_RESULTS"/tangle-validation-*.md || fail "validation does not mark Quality Gate failed"
pass
