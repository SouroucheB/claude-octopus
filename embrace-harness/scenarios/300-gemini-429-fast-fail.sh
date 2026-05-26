#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_GEMINI_429=true run_embrace_case gemini-429

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with Gemini 429 fallback, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "missing probe synthesis"
glob_exists "$CASE_RESULTS/grasp-consensus-*.md" || fail "missing grasp consensus"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "missing delivery artifact"
grep -R -q "GEMINI_QUOTA_EXHAUSTED" "$CASE_DIR/home/workspace/runs" \
    || fail "Gemini 429/rate-limit failure was not classified as quota exhaustion"
gemini_calls=$(grep -c '^gemini ' "$CASE_DIR/home/providers.log" 2>/dev/null || echo 0)
[[ "$gemini_calls" -le 2 ]] \
    || fail "Gemini 429 lockout did not prevent retry storm; calls=$gemini_calls"
[[ -f "$CASE_DIR/home/workspace/.octo/provider-lockouts/gemini.quota" ]] \
    || fail "Gemini 429 lockout state was not recorded"
pass
