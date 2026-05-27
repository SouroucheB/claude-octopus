#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=define OCTO_FAKE_GEMINI_QUOTA=true run_embrace_case gemini-status-canonical

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with Gemini quota lockout and requested gate, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/embrace-gate-define-develop-*.md" || fail "missing define gate artifact"
glob_exists "$CASE_RESULTS/embrace-report-*.md" || fail "missing embrace report"

gate="$(ls "$CASE_RESULTS"/embrace-gate-define-develop-*.md | head -1)"
report="$(ls "$CASE_RESULTS"/embrace-report-*.md | head -1)"

file_contains "Provider Statuses:.*gemini=failed" "$gate" \
    || fail "gate artifact did not canonicalize Gemini quota skip as failed"
! grep -q "Gemini (degraded)" "$gate" \
    || fail "gate provider view used degraded wording for a quota-skipped Gemini provider"
file_contains "gemini: failed - Provider quota exhausted earlier in this run" "$report" \
    || fail "final report did not keep canonical Gemini failed wording"

pass
