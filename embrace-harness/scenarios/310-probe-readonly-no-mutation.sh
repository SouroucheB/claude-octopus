#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

AUTONOMY_MODE=supervised \
OCTOPUS_DEBATE_GATES=none \
OCTO_FAKE_CODEX_PROBE_WRITE=true \
run_embrace_case probe-readonly

[[ "$CASE_RC" -eq 0 || "$CASE_RC" -eq 1 ]] \
    || fail "expected supervised Probe to stop cleanly after approval prompt, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "missing probe synthesis"
[[ ! -f "$CASE_DIR/home/workspace/probe-mutated.txt" ]] \
    || fail "Probe/Discover was able to mutate the workspace before Tangle"
grep -q '^codex .*--sandbox read-only' "$CASE_DIR/home/providers.log" \
    || fail "Codex Probe was not dispatched with read-only sandbox"
pass
