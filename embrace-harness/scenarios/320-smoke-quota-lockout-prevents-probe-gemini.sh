#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none \
OCTO_FAKE_GEMINI_429=true \
OCTOPUS_SKIP_PROVIDER_PROBES=false \
SKIP_SMOKE_TEST=false \
run_embrace_case smoke-quota-lockout

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with smoke-level Gemini quota lockout, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "missing probe synthesis"
glob_exists "$CASE_RESULTS/grasp-consensus-*.md" || fail "missing grasp consensus"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "missing delivery artifact"

gemini_calls=$(grep -c '^gemini ' "$CASE_DIR/home/providers.log" 2>/dev/null || echo 0)
[[ "$gemini_calls" -le 1 ]] \
    || fail "Gemini was called after smoke quota lockout; calls=$gemini_calls"

[[ -f "$CASE_DIR/home/workspace/.octo/provider-lockouts/gemini.quota" ]] \
    || fail "Gemini smoke quota lockout state was not recorded"

if compgen -G "$CASE_RESULTS/gemini-probe-*.md" >/dev/null; then
    grep -R -q "dispatch skipped: Provider quota exhausted earlier in this run" "$CASE_RESULTS"/gemini-probe-*.md \
        || fail "Gemini probe artifacts exist but are not explicit skip artifacts"
fi

pass
