#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_CODEX_STDERR_ONLY=true run_embrace_case codex-stderr

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with Codex stderr-only degraded output, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "missing tangle validation"
file_contains "Status: SUCCESS \(DEGRADED: Codex response captured on stderr\)" "$CASE_RESULTS"/*codex*tangle-*.md \
    || fail "Codex stderr-only output was not classified as degraded usable output"
pass
