#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=define OCTO_FAKE_GEMINI_QUOTA=true run_embrace_case consensus-quality-status-boundary

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with Gemini quota lockout and partial consensus, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/grasp-consensus-*.md" || fail "missing grasp consensus artifact"
glob_exists "$CASE_RESULTS/embrace-gate-define-develop-*.md" || fail "missing define gate artifact"
glob_exists "$CASE_RESULTS/embrace-report-*.md" || fail "missing embrace report"

grasp="$(ls "$CASE_RESULTS"/grasp-consensus-*.md | head -1)"
gate="$(ls "$CASE_RESULTS"/embrace-gate-define-develop-*.md | head -1)"
report="$(ls "$CASE_RESULTS"/embrace-report-*.md | head -1)"

file_contains "Consensus Quality: partial" "$grasp" \
    || fail "grasp fallback did not mark consensus quality separately from provider status"
! grep -qi "degraded consensus" "$grasp" \
    || fail "grasp fallback used provider-status wording for consensus quality"
file_contains "Provider Statuses:.*gemini=failed" "$gate" \
    || fail "gate artifact did not keep Gemini quota skip canonicalized as failed"
file_contains "gemini: failed - Provider quota exhausted earlier in this run" "$report" \
    || fail "final report did not keep canonical Gemini failed wording"

pass
