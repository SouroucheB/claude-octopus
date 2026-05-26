#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_GEMINI_QUOTA=true run_embrace_case gemini-quota

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with Gemini quota fallback, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "missing probe synthesis"
glob_exists "$CASE_RESULTS/grasp-consensus-*.md" || fail "missing grasp consensus"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "missing delivery artifact"
file_contains "Automated probe synthesis unavailable|Automated consensus synthesis unavailable|synthesis provider did not return" \
    "$CASE_RESULTS"/probe-synthesis-*.md \
    "$CASE_RESULTS"/grasp-consensus-*.md \
    "$CASE_RESULTS"/delivery-*.md || fail "compact fallback markers not found in artifacts"
! grep -R -q "Auto-synthesis failed - raw findings below\\|Auto-consensus failed - manual review required" "$CASE_RESULTS" \
    || fail "legacy raw/failure fallback marker leaked into artifacts"
grep -R -q "GEMINI_QUOTA_EXHAUSTED" "$CASE_DIR/home/workspace/runs" \
    || fail "Gemini quota failure was not classified in agent status"
gemini_calls=$(grep -c '^gemini ' "$CASE_DIR/home/providers.log" 2>/dev/null || echo 0)
[[ "$gemini_calls" -le 2 ]] \
    || fail "Gemini quota lockout did not prevent retry storm; calls=$gemini_calls"
[[ -f "$CASE_DIR/home/workspace/.octo/provider-lockouts/gemini.quota" ]] \
    || fail "Gemini quota lockout state was not recorded"
pass
