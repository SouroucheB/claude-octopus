#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_GEMINI_QUOTA=true OCTO_FAKE_LONG_OUTPUT=true run_embrace_case compact-fallbacks

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with compact fallbacks, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/probe-synthesis-*.md" || fail "missing probe synthesis"
glob_exists "$CASE_RESULTS/delivery-*.md" || fail "missing delivery artifact"

! grep -R -q "Auto-synthesis failed - raw findings below\\|Auto-consensus failed - manual review required" "$CASE_RESULTS" \
    || fail "legacy raw/failure fallback marker leaked into artifacts"
file_contains "intentionally compact" "$CASE_RESULTS"/probe-synthesis-*.md "$CASE_RESULTS"/delivery-*.md \
    || fail "compact fallback explanation missing"

probe_lines=$(wc -l < "$CASE_RESULTS"/probe-synthesis-*.md | tr -d ' ')
delivery_lines=$(wc -l < "$CASE_RESULTS"/delivery-*.md | tr -d ' ')
[[ "$probe_lines" -lt 2000 ]] || fail "probe fallback too large: ${probe_lines} lines"
[[ "$delivery_lines" -lt 3000 ]] || fail "delivery fallback too large: ${delivery_lines} lines"
pass
