#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none \
OCTOPUS_HARNESS_AGENT_TIMEOUT=1 \
OCTO_FAKE_CODEX_PROBE_SLEEP_SECONDS=2 \
run_embrace_case spawn-timeout

glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "missing probe synthesis"

timeout_probe=""
for candidate in "$CASE_RESULTS"/codex-probe-*.md; do
    [[ -f "$candidate" ]] || continue
    if grep -q "Status: TIMEOUT" "$candidate"; then
        timeout_probe="$candidate"
        break
    fi
done

[[ -n "$timeout_probe" ]] \
    || fail "slow Codex probe did not honor OCTOPUS_AGENT_TIMEOUT via spawn_agent"

file_contains "timed out after 1s" "$timeout_probe" \
    || fail "timeout artifact does not show the effective 1s agent timeout"

pass
