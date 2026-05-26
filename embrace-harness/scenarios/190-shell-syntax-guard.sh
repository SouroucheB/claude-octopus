#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

files=(
    "$PLUGIN_ROOT/scripts/orchestrate.sh"
    "$PLUGIN_ROOT/scripts/lib/workflows.sh"
    "$PLUGIN_ROOT/scripts/lib/spawn.sh"
    "$PLUGIN_ROOT/scripts/lib/agent-sync.sh"
    "$PLUGIN_ROOT/scripts/lib/error-tracking.sh"
    "$PLUGIN_ROOT/scripts/lib/provider-routing.sh"
    "$PLUGIN_ROOT/scripts/lib/quota-watcher.sh"
    "$HARNESS_ROOT/lib/harness.sh"
    "$HARNESS_ROOT/fake-bin/codex"
    "$HARNESS_ROOT/fake-bin/gemini"
    "$HARNESS_ROOT/fake-bin/claude"
)

for file in "${files[@]}"; do
    [[ -f "$file" ]] || fail "missing shell file: $file"
    bash -n "$file" || fail "bash syntax check failed: $file"
done

if command -v rg >/dev/null 2>&1; then
    ! rg -n '^[^#]*\$\{[A-Za-z_][A-Za-z0-9_]*,,\}|^[^#]*\$\{[A-Za-z_][A-Za-z0-9_]*\^\}' \
        "$PLUGIN_ROOT/scripts/orchestrate.sh" \
        "$PLUGIN_ROOT/scripts/lib/workflows.sh" \
        "$PLUGIN_ROOT/scripts/lib/spawn.sh" \
        "$PLUGIN_ROOT/scripts/lib/agent-sync.sh" \
        "$PLUGIN_ROOT/scripts/lib/error-tracking.sh" \
        "$PLUGIN_ROOT/scripts/lib/provider-routing.sh" \
        "$PLUGIN_ROOT/scripts/lib/quota-watcher.sh" \
        || fail "found Bash 4-only case-modification expansion in Embrace-critical scripts"
fi

pass
