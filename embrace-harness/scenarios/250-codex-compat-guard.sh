#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

CASE_DIR="$RESULT_ROOT/$SCENARIO_NAME"
mkdir -p "$CASE_DIR"
CASE_OUT="$CASE_DIR/plugin-tests.log"
before_status="$(cd "$PLUGIN_ROOT" && git status --porcelain)"
ISOLATED_PLUGIN="$CASE_DIR/plugin-worktree"

cleanup_isolated_plugin() {
    git -C "$PLUGIN_ROOT" worktree remove --force "$ISOLATED_PLUGIN" >/dev/null 2>&1 || true
}
trap cleanup_isolated_plugin EXIT

git -C "$PLUGIN_ROOT" worktree add --detach "$ISOLATED_PLUGIN" HEAD >"$CASE_DIR/worktree.log" 2>&1 \
    || fail "failed to create isolated plugin worktree"

(
    cd "$ISOLATED_PLUGIN"
    bash scripts/test-codex-compat.sh
) >"$CASE_OUT" 2>&1 || fail "Codex compatibility regression suite failed"

after_status="$(cd "$PLUGIN_ROOT" && git status --porcelain)"
[[ "$after_status" == "$before_status" ]] \
    || fail "Codex compatibility scenario mutated plugin worktree: ${after_status:-<clean>}"

pass
