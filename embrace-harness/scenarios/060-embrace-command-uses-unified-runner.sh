#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

command_file="$PLUGIN_ROOT/.claude/commands/embrace.md"
[[ -f "$command_file" ]] || fail "missing embrace command file: $command_file"

file_contains 'orchestrate\.sh embrace ' "$command_file" \
    || fail "embrace command must delegate to the unified orchestrate.sh embrace runner"

if grep -qE 'orchestrate\.sh (probe|grasp|tangle|ink) <user' "$command_file"; then
    fail "embrace command still instructs manual phase-by-phase orchestration"
fi

if grep -q 'orchestrate.sh embrace-gate' "$command_file"; then
    fail "embrace command still instructs markdown-driven debate gates instead of runner-owned gates"
fi

file_contains 'Do not implement code directly if the runner fails' "$command_file" \
    || fail "embrace command must prohibit manual implementation after runner failure"
file_contains 'If the command fails, do not continue locally' "$command_file" \
    || fail "embrace command must stop instead of locally compensating after runner failure"
file_contains 'phase outputs and artifact paths printed by the runner' "$command_file" \
    || fail "embrace command must summarize runner-owned artifacts instead of manual narration"

pass
