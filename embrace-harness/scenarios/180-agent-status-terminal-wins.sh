#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"
source "$PLUGIN_ROOT/scripts/lib/error-tracking.sh"

export WORKSPACE_DIR="$RESULT_ROOT/$SCENARIO_NAME/status-workspace"
export OCTOPUS_RUN_ID="terminal-status"
mkdir -p "$WORKSPACE_DIR/results"
printf 'terminal output\n' > "$WORKSPACE_DIR/results/codex-terminal.md"

write_agent_status "codex" "running" 100 0 "initial dispatch" 0 "$WORKSPACE_DIR/results/codex-running.md" "researcher"
write_agent_status "codex" "ok" 100 40 "" 1000 "$WORKSPACE_DIR/results/codex-terminal.md" "researcher"
write_agent_status "codex" "running" 100 0 "stale dispatch record" 0 "$WORKSPACE_DIR/results/codex-stale.md" "researcher"

summary="$(render_agent_summary)"
files="$(agent_status_output_files)"

[[ "$summary" == *"codex"* ]] || fail "summary does not include codex"
[[ "$summary" == *" ok"* ]] || fail "summary did not prefer terminal ok status"
[[ "$summary" != *"stale dispatch record"* ]] || fail "stale running record leaked into provider summary"
[[ "$files" == *"codex-terminal.md"* ]] || fail "agent output reader did not return terminal output file"
pass
