#!/usr/bin/env bash
# Static checks for Claude Octopus PR review draft filtering.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "Claude Octopus PR review draft filter"

WORKFLOW="$PROJECT_ROOT/.github/workflows/claude-octopus.yml"

test_case "workflow includes ready_for_review PR event"
if grep -qE 'types:[[:space:]]*\[[^]]*ready_for_review' "$WORKFLOW"; then
    test_pass
else
    test_fail "pull_request types must include ready_for_review so draft PRs are reviewed when marked ready"
fi

test_case "pr-review job skips draft pull requests"
if awk '
    /^  pr-review:/ { in_job=1; next }
    in_job && /^  [a-zA-Z0-9_-]+:/ { in_job=0 }
    in_job { print }
' "$WORKFLOW" | grep -q 'github.event.pull_request.draft == false'; then
    test_pass
else
    test_fail "pr-review job must guard against github.event.pull_request.draft"
fi

test_summary
