#!/usr/bin/env bash
# Unit tests for Claude Code progression dynamic prompt exclusion on agent execution paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DISPATCH="$PROJECT_ROOT/scripts/lib/dispatch.sh"
AGENT_UTILS="$PROJECT_ROOT/scripts/lib/agent-utils.sh"
SESSION_SH="$PROJECT_ROOT/scripts/lib/session.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "Claude progression dynamic prompt exclusion"

# shellcheck source=/dev/null
source "$DISPATCH"

progression_flag="--exclude-dynamic-system-prompt-sections"
unexpected_progression_arg="--exclude-dynamic-system-prompt-sections progression"

test_case "get_agent_command adds progression exclusion for supported Claude agent variants"
SUPPORTS_EXCLUDE_DYNAMIC_PROMPT=true
SUPPORTS_XHIGH_EFFORT=false
_BARE_OPT=" --bare"
missing=""
for agent in claude claude-sonnet claude-opus claude-opus-fast claude-opus-legacy; do
    cmd=$(get_agent_command "$agent" "probe" "researcher")
    if [[ "$cmd" != *"$progression_flag"* ]] || [[ "$cmd" == *"$unexpected_progression_arg"* ]]; then
        missing="${missing}${agent}: ${cmd}"$'\n'
    fi
done
if [[ -z "$missing" ]]; then
    test_pass
else
    test_fail "Missing progression exclusion in: ${missing}"
fi

test_case "get_agent_command omits progression exclusion on unsupported Claude versions"
SUPPORTS_EXCLUDE_DYNAMIC_PROMPT=false
SUPPORTS_XHIGH_EFFORT=false
_BARE_OPT=""
cmd=$(get_agent_command "claude-opus" "probe" "researcher")
if [[ "$cmd" != *"$progression_flag"* ]]; then
    test_pass
else
    test_fail "Unexpected progression exclusion in unsupported command: $cmd"
fi

test_case "get_agent_command preserves xhigh effort env prefix with progression exclusion"
SUPPORTS_EXCLUDE_DYNAMIC_PROMPT=true
SUPPORTS_XHIGH_EFFORT=true
_BARE_OPT=" --bare"
cmd=$(get_agent_command "claude-opus" "review" "code-reviewer")
if [[ "$cmd" == env\ CLAUDE_CODE_EFFORT_LEVEL=xhigh\ claude* ]] && \
   [[ "$cmd" == *"$progression_flag"* ]] && \
   [[ "$cmd" != *"$unexpected_progression_arg"* ]]; then
    test_pass
else
    test_fail "Expected xhigh env prefix and progression exclusion, got: $cmd"
fi

test_case "Ralph Claude fallback applies shared progression exclusion helper"
if grep -q 'claude_progression_exclusion_opt' "$AGENT_UTILS"; then
    test_pass
else
    test_fail "run_with_claude_code_ralph should apply claude_progression_exclusion_opt"
fi

test_case "Session naming Claude print call applies shared progression exclusion helper"
session_naming_block=$(grep -A10 'Auto-name session' "$SESSION_SH" || true)
if [[ "$session_naming_block" == *"claude_progression_exclusion_opt"* ]] && \
   [[ "$session_naming_block" == *'claude${_BARE_OPT:-}${progression_opt} --no-input --print'* ]]; then
    test_pass
else
    test_fail "init_session should apply claude_progression_exclusion_opt before Claude --print"
fi

test_summary
