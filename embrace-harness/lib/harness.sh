#!/usr/bin/env bash
set -euo pipefail

: "${HARNESS_ROOT:?HARNESS_ROOT is required}"
: "${PLUGIN_ROOT:?PLUGIN_ROOT is required}"
: "${RESULT_ROOT:?RESULT_ROOT is required}"
: "${SCENARIO_NAME:?SCENARIO_NAME is required}"

FAKE_BIN="$HARNESS_ROOT/fake-bin"
ORIGINAL_PATH="$PATH"
CASE_DIR=""
CASE_RC=""
CASE_RESULTS=""
CASE_OUT=""

run_embrace_case() {
    local case_name="$1"
    shift || true

    CASE_DIR="$RESULT_ROOT/$SCENARIO_NAME/$case_name"
    local fake_home="$CASE_DIR/home"
    local workspace="$fake_home/workspace"
    CASE_OUT="$CASE_DIR/output.log"

    rm -rf "$CASE_DIR"
    mkdir -p "$workspace" "$fake_home"
    (
        cd "$workspace"
        git init -q
        git config user.email embrace-harness@example.invalid
        git config user.name "Embrace Harness"
        printf 'base\n' > README.md
        git add README.md
        git commit -q -m "harness baseline"
    )

    cat > "$fake_home/.octo-fake-mode" <<EOF
OCTO_FAKE_TANGLE_FAIL="${OCTO_FAKE_TANGLE_FAIL:-false}"
OCTO_FAKE_GEMINI_QUOTA="${OCTO_FAKE_GEMINI_QUOTA:-false}"
OCTO_FAKE_GEMINI_429="${OCTO_FAKE_GEMINI_429:-false}"
OCTO_FAKE_CODEX_STDERR_ONLY="${OCTO_FAKE_CODEX_STDERR_ONLY:-false}"
OCTO_FAKE_CODEX_PROBE_WRITE="${OCTO_FAKE_CODEX_PROBE_WRITE:-false}"
OCTO_FAKE_GATE_NO_OUTPUT="${OCTO_FAKE_GATE_NO_OUTPUT:-false}"
OCTO_FAKE_CODEX_GATE_EXIT2="${OCTO_FAKE_CODEX_GATE_EXIT2:-false}"
OCTO_FAKE_GEMINI_TRUST_FAIL="${OCTO_FAKE_GEMINI_TRUST_FAIL:-false}"
OCTO_FAKE_LONG_OUTPUT="${OCTO_FAKE_LONG_OUTPUT:-false}"
OCTO_FAKE_STALE_ARTIFACTS="${OCTO_FAKE_STALE_ARTIFACTS:-false}"
OCTO_FAKE_CODEX_EMPTY_TANGLE="${OCTO_FAKE_CODEX_EMPTY_TANGLE:-false}"
OCTO_FAKE_CLAUDE_FAIL="${OCTO_FAKE_CLAUDE_FAIL:-false}"
OCTO_FAKE_LOW_REVIEW_SCORE="${OCTO_FAKE_LOW_REVIEW_SCORE:-false}"
OCTO_FAKE_CODEX_PROBE_SLEEP_SECONDS="${OCTO_FAKE_CODEX_PROBE_SLEEP_SECONDS:-0}"
EOF

    if [[ "${OCTO_FAKE_STALE_ARTIFACTS:-false}" == "true" ]]; then
        mkdir -p "$workspace/results"
        for stale in \
            probe-synthesis-9999999999.md \
            grasp-consensus-9999999999.md \
            tangle-validation-9999999999.md \
            delivery-9999999999.md \
            embrace-gate-define-develop-9999999999.md \
            embrace-gate-develop-deliver-9999999999.md; do
            printf '# STALE_ARTIFACT_SHOULD_NOT_APPEAR\n\n%s\n' "$stale" > "$workspace/results/$stale"
        done
    fi

    set +e
    env \
        HOME="$fake_home" \
        PATH="$FAKE_BIN:$ORIGINAL_PATH" \
        OPENAI_API_KEY="fake-openai-key" \
        GEMINI_API_KEY="fake-gemini-key" \
        CLAUDE_OCTOPUS_WORKSPACE="$workspace" \
        OCTOPUS_SKIP_COST_PROMPT=true \
        OCTOPUS_SKIP_PHASE_COST_PROMPT=true \
        OCTOPUS_SKIP_PROVIDER_PROBES="${OCTOPUS_SKIP_PROVIDER_PROBES:-true}" \
        SKIP_SMOKE_TEST="${SKIP_SMOKE_TEST:-true}" \
        OCTOPUS_CONFORMANCE_MODE=true \
        OCTOPUS_YAML_RUNTIME=disabled \
        AUTONOMY_MODE="${AUTONOMY_MODE:-autonomous}" \
        ON_FAIL_ACTION=abort \
        OCTOPUS_DEBATE_GATES="${OCTOPUS_DEBATE_GATES:-both}" \
        OCTOPUS_EMBRACE_DEBATE_GATES="${OCTOPUS_DEBATE_GATES:-both}" \
        EMBRACE_DEBATE_GATES="${OCTOPUS_DEBATE_GATES:-both}" \
        OCTOPUS_DISPATCH_STRATEGY=full \
        OCTOPUS_TANGLE_DEADLINE="${OCTOPUS_TANGLE_DEADLINE:-30}" \
        OCTOPUS_AGENT_TIMEOUT="${OCTOPUS_HARNESS_AGENT_TIMEOUT:-}" \
        OCTOPUS_SPAWN_AGENT_TIMEOUT="${OCTOPUS_HARNESS_SPAWN_AGENT_TIMEOUT:-}" \
        OCTOPUS_CODEX_SMOKE_TIMEOUT="${OCTOPUS_CODEX_SMOKE_TIMEOUT:-5}" \
        OCTOPUS_GEMINI_SMOKE_TIMEOUT="${OCTOPUS_GEMINI_SMOKE_TIMEOUT:-5}" \
        OCTOPUS_AGENT_MAX_OUTPUT_BYTES=65536 \
        OCTO_FAKE_TANGLE_FAIL="${OCTO_FAKE_TANGLE_FAIL:-false}" \
        OCTO_FAKE_GEMINI_QUOTA="${OCTO_FAKE_GEMINI_QUOTA:-false}" \
        OCTO_FAKE_GEMINI_429="${OCTO_FAKE_GEMINI_429:-false}" \
        OCTO_FAKE_CODEX_STDERR_ONLY="${OCTO_FAKE_CODEX_STDERR_ONLY:-false}" \
        OCTO_FAKE_CODEX_PROBE_WRITE="${OCTO_FAKE_CODEX_PROBE_WRITE:-false}" \
        OCTO_FAKE_GATE_NO_OUTPUT="${OCTO_FAKE_GATE_NO_OUTPUT:-false}" \
        OCTO_FAKE_CODEX_GATE_EXIT2="${OCTO_FAKE_CODEX_GATE_EXIT2:-false}" \
        OCTO_FAKE_GEMINI_TRUST_FAIL="${OCTO_FAKE_GEMINI_TRUST_FAIL:-false}" \
        OCTO_FAKE_LONG_OUTPUT="${OCTO_FAKE_LONG_OUTPUT:-false}" \
        OCTO_FAKE_STALE_ARTIFACTS="${OCTO_FAKE_STALE_ARTIFACTS:-false}" \
        OCTO_FAKE_CODEX_EMPTY_TANGLE="${OCTO_FAKE_CODEX_EMPTY_TANGLE:-false}" \
        OCTO_FAKE_CLAUDE_FAIL="${OCTO_FAKE_CLAUDE_FAIL:-false}" \
        OCTO_FAKE_LOW_REVIEW_SCORE="${OCTO_FAKE_LOW_REVIEW_SCORE:-false}" \
        OCTO_FAKE_CODEX_PROBE_SLEEP_SECONDS="${OCTO_FAKE_CODEX_PROBE_SLEEP_SECONDS:-0}" \
        OCTOPUS_CONFORMANCE_SKIP_GATE_ARTIFACT="${OCTOPUS_CONFORMANCE_SKIP_GATE_ARTIFACT:-}" \
        "$@" \
        bash -c 'cd "$1" && shift && exec "$@"' _ "$workspace" \
        bash "$PLUGIN_ROOT/scripts/orchestrate.sh" --timeout 30 embrace "local conformance ${SCENARIO_NAME}" \
        >"$CASE_OUT" 2>&1
    CASE_RC=$?
    set -e

    CASE_RESULTS="$workspace/results"
    printf '%s' "$CASE_RC" > "$CASE_DIR/rc"
}

pass() {
    return 0
}

fail() {
    printf '  %s\n' "$*" >&2
    if [[ -n "${CASE_OUT:-}" && -f "$CASE_OUT" ]]; then
        printf '  tail %s:\n' "$CASE_OUT" >&2
        tail -40 "$CASE_OUT" >&2 || true
    fi
    return 1
}

glob_exists() {
    local pattern="$1"
    compgen -G "$pattern" >/dev/null
}

glob_absent() {
    local pattern="$1"
    ! compgen -G "$pattern" >/dev/null
}

file_contains() {
    local pattern="$1"
    shift
    grep -qE "$pattern" "$@"
}

provider_was_called() {
    local provider="$1"
    grep -q "^${provider} " "$CASE_DIR/home/providers.log" 2>/dev/null
}
