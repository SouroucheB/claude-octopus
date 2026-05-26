#!/usr/bin/env bash
# Regression checks for Embrace real-run guardrails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EMBRACE_LIB="$PROJECT_ROOT/scripts/lib/embrace.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "embrace real-run guard"

test_case "embrace.sh has valid bash syntax"
if bash -n "$EMBRACE_LIB" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in embrace.sh"
fi

# shellcheck source=/dev/null
source "$EMBRACE_LIB"

log() { :; }

unset OCTOPUS_CONFORMANCE_MODE OCTOPUS_ALLOW_REAL_EMBRACE OCTOPUS_EMBRACE_VALIDATION_ONLY OCTOPUS_EMBRACE_REQUIRE_ALLOW_REAL

test_case "real embrace is allowed when guard is not requested"
if embrace_real_run_guard "test prompt" >/dev/null 2>&1; then
    test_pass
else
    test_fail "guard blocked default embrace unexpectedly"
fi

OCTOPUS_EMBRACE_REQUIRE_ALLOW_REAL=1
unset OCTOPUS_ALLOW_REAL_EMBRACE OCTOPUS_CONFORMANCE_MODE OCTOPUS_EMBRACE_VALIDATION_ONLY

test_case "require-allow guard blocks real embrace by default"
if embrace_real_run_guard "test prompt" >/dev/null 2>&1; then
    test_fail "guard allowed a real run without explicit override"
else
    test_pass
fi

OCTOPUS_ALLOW_REAL_EMBRACE=1

test_case "explicit allow overrides require-allow guard"
if embrace_real_run_guard "test prompt" >/dev/null 2>&1; then
    test_pass
else
    test_fail "guard blocked despite OCTOPUS_ALLOW_REAL_EMBRACE=1"
fi

unset OCTOPUS_ALLOW_REAL_EMBRACE
OCTOPUS_CONFORMANCE_MODE=1

test_case "conformance harness bypasses real-run guard"
if embrace_real_run_guard "test prompt" >/dev/null 2>&1; then
    test_pass
else
    test_fail "guard blocked conformance harness"
fi

unset OCTOPUS_CONFORMANCE_MODE OCTOPUS_EMBRACE_REQUIRE_ALLOW_REAL
OCTOPUS_EMBRACE_VALIDATION_ONLY=1

test_case "validation-only mode blocks real embrace"
if embrace_real_run_guard "test prompt" >/dev/null 2>&1; then
    test_fail "validation-only mode allowed a real provider-backed embrace"
else
    test_pass
fi

test_summary
