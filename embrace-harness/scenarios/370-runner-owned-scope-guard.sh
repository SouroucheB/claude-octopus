#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_RUNNER_OWNED_SCOPE=true run_embrace_case runner-owned-scope-guard

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 after stripping runner-owned worker scope, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "missing tangle validation artifact"
[[ ! -f "$CASE_DIR/home/workspace/.claude-octopus/forged-worker-artifact.md" ]] \
    || fail "implementation worker received and wrote runner-owned .claude-octopus scope"
file_contains "src/app/page.tsx" "$CASE_RESULTS"/tangle-validation-*.md \
    || fail "sanitized worker did not preserve product write scope"

pass
