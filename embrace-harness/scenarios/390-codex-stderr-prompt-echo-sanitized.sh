#!/usr/bin/env bash
set -euo pipefail
source "$HARNESS_ROOT/lib/harness.sh"

OCTOPUS_DEBATE_GATES=none OCTO_FAKE_CODEX_TRANSCRIPT_STDERR=true run_embrace_case codex-stderr-prompt-echo

[[ "$CASE_RC" -eq 0 ]] || fail "expected rc=0 with Codex stderr prompt echo, got rc=$CASE_RC"
glob_exists "$CASE_RESULTS/tangle-validation-*.md" || fail "missing tangle validation"

if rg -q "skill-tdd|Agent Skill Context|Test-Driven Development" "$CASE_RESULTS"; then
    fail "Codex stderr prompt echo leaked skill context into Embrace artifacts"
fi

file_contains "codex user prompt omitted" "$CASE_RESULTS"/*codex*.md \
    || fail "sanitized Codex stderr transcript did not record prompt omission"
file_contains "codex stderr diagnostic after prompt echo" "$CASE_RESULTS"/*codex*.md \
    || fail "sanitizer dropped non-prompt Codex stderr diagnostics"

pass
