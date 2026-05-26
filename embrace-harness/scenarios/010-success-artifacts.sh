#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=both run_embrace_case success

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "missing probe synthesis"
glob_exists "$CASE_RESULTS/grasp-consensus-*.md" || fail "missing grasp consensus"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "missing tangle validation"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "missing delivery artifact"
glob_exists "$CASE_RESULTS/embrace-gate-define-develop-*.md" || fail "missing define->develop gate artifact"
glob_exists "$CASE_RESULTS/embrace-gate-develop-deliver-*.md" || fail "missing develop->deliver gate artifact"
provider_was_called codex || fail "codex fake was not called"
provider_was_called gemini || fail "gemini fake was not called"
provider_was_called claude || fail "claude fake was not called"
pass
