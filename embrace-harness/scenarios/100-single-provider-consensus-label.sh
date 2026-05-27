#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_GEMINI_QUOTA=true run_embrace_case single-provider-consensus

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with partial single-provider consensus, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/grasp-consensus-*.md" || fail "missing grasp consensus"
file_contains "Automated consensus synthesis unavailable" "$CASE_RESULTS"/grasp-consensus-*.md \
    || fail "consensus synthesis fallback label missing"
file_contains "Consensus Quality: partial" "$CASE_RESULTS"/grasp-consensus-*.md \
    || fail "partial consensus quality label missing"
! grep -qi "degraded consensus" "$CASE_RESULTS"/grasp-consensus-*.md \
    || fail "consensus quality used provider-status degraded wording"
! grep -q "Auto-consensus failed - manual review required" "$CASE_RESULTS"/grasp-consensus-*.md \
    || fail "confusing legacy consensus failure label still present"
pass
