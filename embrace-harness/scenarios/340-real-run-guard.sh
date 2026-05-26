#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none \
run_embrace_case guarded-real-run \
    OCTOPUS_CONFORMANCE_MODE=false \
    OCTOPUS_EMBRACE_REQUIRE_ALLOW_REAL=1

[[ "$CASE_RC" -eq 2 ]] || fail "expected guard rc=2, got $CASE_RC"
file_contains 'Refusing real Embrace run without OCTOPUS_ALLOW_REAL_EMBRACE=1' "$CASE_OUT" \
    || fail "guard refusal message missing"
[[ ! -f "$CASE_DIR/home/providers.log" ]] \
    || fail "provider CLIs were called despite real-run guard"
glob_absent "$CASE_RESULTS/probe-synthesis-*.md" \
    || fail "Probe ran despite real-run guard"
pass
