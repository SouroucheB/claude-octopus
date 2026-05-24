#!/usr/bin/env bash
# Regression checks for Probe semantic cache path resolution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SESSION_LIB="$PROJECT_ROOT/scripts/lib/session.sh"
SEMANTIC_CACHE_LIB="$PROJECT_ROOT/scripts/lib/semantic-cache.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "semantic cache path"

test_case "session.sh has valid bash syntax"
if bash -n "$SESSION_LIB" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in session.sh"
fi

test_case "semantic-cache.sh has valid bash syntax"
if bash -n "$SEMANTIC_CACHE_LIB" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in semantic-cache.sh"
fi

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

PROGRESS_TRACKING_ENABLED=false
DRY_RUN=false
log() { :; }

unset CACHE_DIR
WORKSPACE_DIR=""

# shellcheck source=/dev/null
source "$SESSION_LIB"
# shellcheck source=/dev/null
source "$SEMANTIC_CACHE_LIB"

WORKSPACE_DIR="$TEST_ROOT/workspace"
mkdir -p "$WORKSPACE_DIR"
result_file="$TEST_ROOT/result.md"
printf '%s\n' '# result' > "$result_file"

test_case "cache resolves under workspace after late WORKSPACE_DIR assignment"
if save_to_cache "abc123" "$result_file" >/dev/null 2>&1 && \
   [[ -f "$WORKSPACE_DIR/.cache/probe-results/abc123.md" ]] && \
   [[ ! -f "/.cache/probe-results/abc123.md" ]]; then
    test_pass
else
    test_fail "cache path did not resolve under WORKSPACE_DIR"
fi

test_summary
