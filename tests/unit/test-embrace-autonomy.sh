#!/usr/bin/env bash
# Regression checks for explicit Embrace autonomy mode preservation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QUALITY="$PROJECT_ROOT/scripts/lib/quality.sh"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "embrace autonomy mode"

test_case "quality.sh has valid bash syntax"
if bash -n "$QUALITY" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in quality.sh"
fi

test_case "explicit AUTONOMY_MODE is not overwritten"
if AUTONOMY_MODE=autonomous CLAUDE_OCTOPUS_AUTONOMY= OCTOPUS_AUTONOMY= \
    bash -c "source '$QUALITY'; [[ \"\$AUTONOMY_MODE\" == autonomous ]]"; then
    test_pass
else
    test_fail "AUTONOMY_MODE=autonomous was overwritten during source"
fi

test_case "CLAUDE_OCTOPUS_AUTONOMY remains fallback"
if unset AUTONOMY_MODE; CLAUDE_OCTOPUS_AUTONOMY=supervised OCTOPUS_AUTONOMY= \
    bash -c "source '$QUALITY'; [[ \"\$AUTONOMY_MODE\" == supervised ]]"; then
    test_pass
else
    test_fail "CLAUDE_OCTOPUS_AUTONOMY was not used as fallback"
fi

test_case "OCTOPUS_AUTONOMY remains fallback"
if unset AUTONOMY_MODE CLAUDE_OCTOPUS_AUTONOMY; OCTOPUS_AUTONOMY=autonomous \
    bash -c "source '$QUALITY'; [[ \"\$AUTONOMY_MODE\" == autonomous ]]"; then
    test_pass
else
    test_fail "OCTOPUS_AUTONOMY was not used as fallback"
fi

test_summary
