#!/usr/bin/env bash
# Regression checks for Embrace historical context hygiene.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENTS="$PROJECT_ROOT/scripts/lib/agents.sh"
SPAWN="$PROJECT_ROOT/scripts/lib/spawn.sh"
AGENT_SYNC="$PROJECT_ROOT/scripts/lib/agent-sync.sh"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "embrace context hygiene"

test_case "touched libs have valid bash syntax"
if bash -n "$AGENTS" 2>/dev/null && \
   bash -n "$SPAWN" 2>/dev/null && \
   bash -n "$AGENT_SYNC" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in agents/spawn/agent-sync libs"
fi

source "$AGENTS"

test_case "Embrace disables historical context by default"
if OCTOPUS_WORKFLOW_TYPE=embrace OCTOPUS_HISTORY_CONTEXT= OCTOPUS_EMBRACE_HISTORY_CONTEXT= \
    bash -c "source '$AGENTS'; ! octopus_should_inject_historical_context probe"; then
    test_pass
else
    test_fail "Embrace did not disable historical context by default"
fi

test_case "Embrace historical context can be explicitly re-enabled"
if OCTOPUS_WORKFLOW_TYPE=embrace OCTOPUS_EMBRACE_HISTORY_CONTEXT=on \
    bash -c "source '$AGENTS'; octopus_should_inject_historical_context probe"; then
    test_pass
else
    test_fail "OCTOPUS_EMBRACE_HISTORY_CONTEXT=on did not re-enable historical context"
fi

test_case "Non-Embrace workflows keep historical context by default"
if OCTOPUS_WORKFLOW_TYPE=research OCTOPUS_HISTORY_CONTEXT= OCTOPUS_EMBRACE_HISTORY_CONTEXT= \
    bash -c "source '$AGENTS'; octopus_should_inject_historical_context probe"; then
    test_pass
else
    test_fail "historical context was disabled outside Embrace"
fi

test_case "Global historical context override still wins"
if OCTOPUS_WORKFLOW_TYPE=research OCTOPUS_HISTORY_CONTEXT=off \
    bash -c "source '$AGENTS'; ! octopus_should_inject_historical_context probe" && \
   OCTOPUS_WORKFLOW_TYPE=embrace OCTOPUS_HISTORY_CONTEXT=on \
    bash -c "source '$AGENTS'; octopus_should_inject_historical_context probe"; then
    test_pass
else
    test_fail "OCTOPUS_HISTORY_CONTEXT override did not win"
fi

test_case "spawn_agent gates earned skills and provider history"
if grep -B 20 -A 20 "## Earned Project Skills" "$SPAWN" | grep -q "octopus_should_inject_historical_context" && \
   grep -B 8 -A 20 'provider_ctx=$(build_provider_context' "$SPAWN" | grep -q "octopus_should_inject_historical_context"; then
    test_pass
else
    test_fail "spawn_agent does not gate historical context injection"
fi

test_case "run_agent_sync gates earned skills and provider history"
if grep -B 20 -A 20 "## Earned Project Skills" "$AGENT_SYNC" | grep -q "octopus_should_inject_historical_context" && \
   grep -B 8 -A 20 'provider_ctx=$(build_provider_context' "$AGENT_SYNC" | grep -q "octopus_should_inject_historical_context"; then
    test_pass
else
    test_fail "run_agent_sync does not gate historical context injection"
fi

test_summary
