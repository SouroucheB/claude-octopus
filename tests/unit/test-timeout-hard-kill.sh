#!/usr/bin/env bash
# Regression checks for portable timeout hard-kill behavior.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/scripts/lib/heartbeat.sh"

test_suite "timeout hard kill"

log() { :; }

test_case "run_with_timeout kills TERM-resistant commands"
start=$(date +%s)
set +e
OCTOPUS_TIMEOUT_KILL_GRACE=1 run_with_timeout 1 bash -c 'trap "" TERM; sleep 20' >/dev/null 2>&1
rc=$?
set -e
elapsed=$(($(date +%s) - start))

if [[ "$rc" -eq 124 && "$elapsed" -le 5 ]]; then
    test_pass
else
    test_fail "expected rc=124 within 5s, got rc=$rc elapsed=${elapsed}s"
fi

test_summary
