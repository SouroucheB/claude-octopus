#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_GEMINI_TRUST_FAIL=true run_embrace_case gemini-trust

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with Gemini trust fallback, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "missing probe synthesis"
glob_exists "$CASE_RESULTS/grasp-consensus-*.md" || fail "missing grasp consensus"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "missing delivery artifact"
grep -R -q "GEMINI_TRUST_REQUIRED" "$CASE_DIR/home/workspace/runs" \
    || fail "Gemini trust failure was not classified in agent status"
pass
