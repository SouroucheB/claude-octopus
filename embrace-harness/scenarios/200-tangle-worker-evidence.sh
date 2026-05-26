#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

CASE_DIR="$RESULT_ROOT/$SCENARIO_NAME"
mkdir -p "$CASE_DIR"
CASE_OUT="$CASE_DIR/plugin-tests.log"

(
    cd "$PLUGIN_ROOT"
    bash tests/unit/test-tangle-worktree-evidence.sh
    bash tests/unit/test-tangle-file-coverage.sh
    bash tests/unit/test-tangle-subtask-context.sh
    bash tests/unit/test-tangle-write-scope-safety.sh
) >"$CASE_OUT" 2>&1 || fail "tangle worker evidence regression tests failed"

pass
