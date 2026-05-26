#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none \
SKIP_SMOKE_TEST=false \
OCTOPUS_SKIP_PROVIDER_PROBES=false \
OCTOPUS_CODEX_SMOKE_TIMEOUT=5 \
OCTOPUS_GEMINI_SMOKE_TIMEOUT=5 \
run_embrace_case smoke-enabled

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with provider smoke enabled, got rc=$CASE_RC"
file_contains "Running provider smoke test" "$CASE_OUT" || fail "smoke test did not run"
file_contains "Smoke test passed" "$CASE_OUT" || fail "smoke test did not pass"
glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "workflow did not reach Probe synthesis after smoke"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "workflow did not complete after smoke"
pass
