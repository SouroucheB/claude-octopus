#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

CASE_DIR="$RESULT_ROOT/$SCENARIO_NAME"
mkdir -p "$CASE_DIR"
CASE_OUT="$CASE_DIR/plugin-tests.log"

(
    cd "$PLUGIN_ROOT"
    bash tests/unit/test-ink-compact-delivery.sh
) >"$CASE_OUT" 2>&1 || fail "ink compact delivery fallback regression test failed"

pass
