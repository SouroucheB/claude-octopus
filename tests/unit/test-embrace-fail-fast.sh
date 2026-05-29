#!/usr/bin/env bash
# Regression checks for /octo:embrace hardcoded phase fail-fast behavior.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

# This suite intentionally exercises non-zero workflow exits. Keep errexit off
# after loading the shared framework so Bash 5/Linux does not abort before
# assertions run.
set +e

test_suite "embrace phase fail-fast"

test_case "workflows.sh has valid bash syntax"
if bash -n "$WORKFLOWS" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in workflows.sh"
fi

# shellcheck source=/dev/null
source "$WORKFLOWS"

TEST_ROOT="$(mktemp -d)"
HOME="$TEST_ROOT/home"
RESULTS_DIR="$TEST_ROOT/results"
LOGS_DIR="$TEST_ROOT/logs"
WORKSPACE_DIR="$TEST_ROOT/workspace"
PLUGIN_DIR="$PROJECT_ROOT"
trap 'rm -rf "$TEST_ROOT"' EXIT

CYAN=""
GREEN=""
MAGENTA=""
NC=""
_BOX_TOP=""
_BOX_BOT=""
AUTONOMY_MODE="semi-autonomous"
LOOP_UNTIL_APPROVED=false
RESUME_SESSION=false
DRY_RUN=false
OCTOPUS_YAML_RUNTIME=disabled
OCTOPUS_EMBRACE_DEBATE_GATES=none
SUPPORTS_DISABLE_CRON_ENV=false

CASE_NAME=""
PHASE_CALLS=""
CHECKPOINTS=""
EMBRACE_STATUS=0
RESUME_PHASE=""
FAKE_DATE_EPOCH=""

log() { :; }
cleanup_old_results() { :; }
show_cost_estimate() { :; }
cleanup_expired_checkpoints() { :; }
reset_provider_lockouts() { :; }
search_observations() { :; }
init_session() { :; }
check_resume_session() { [[ -n "$RESUME_PHASE" ]]; }
get_resume_phase() { printf '%s\n' "$RESUME_PHASE"; }
get_phase_output() {
    local phase="$1"
    local file=""
    case "$phase" in
        probe) file="$RESULTS_DIR/probe-synthesis-resume.md" ;;
        grasp) file="$RESULTS_DIR/grasp-consensus-resume.md" ;;
        debate-define-develop) file="$RESULTS_DIR/embrace-gate-define-develop-resume.md" ;;
        tangle) file="$RESULTS_DIR/tangle-validation-resume.md" ;;
        debate-develop-deliver) file="$RESULTS_DIR/embrace-gate-develop-deliver-resume.md" ;;
        ink) file="$RESULTS_DIR/delivery-resume.md" ;;
    esac
    [[ -n "$file" && -f "$file" ]] && printf '%s\n' "$file"
}
display_workflow_cost_estimate() { return 0; }
PREFLIGHT_ARGS=""
preflight_check() { PREFLIGHT_ARGS+="${1:-false}"$'\n'; return 0; }
display_phase_metrics() { :; }
update_context() { :; }
handle_autonomy_checkpoint() { :; }
complete_session() { :; }
write_structured_decision() { :; }
earn_skill() { :; }
sleep() { :; }
date() {
    if [[ -n "${FAKE_DATE_EPOCH:-}" && "${1:-}" == "+%s" ]]; then
        printf '%s\n' "$FAKE_DATE_EPOCH"
        return 0
    fi
    command date "$@"
}
run_agent_sync() {
    if [[ "$CASE_NAME" == "gate_agents_fail" && "${5:-}" == "embrace-gate" ]]; then
        return 2
    fi
    if [[ "$CASE_NAME" == "gate_codex_degraded_output" && "${5:-}" == "embrace-gate" ]]; then
        if [[ "${4:-}" == "synthesizer" ]]; then
            printf '%s\n' "VERDICT: PROCEED_WITH_RISKS"
            printf '%s\n' "Required actions before next phase: none."
            return 0
        fi
        if [[ "${1:-}" == "codex" && "${4:-}" == "code-reviewer" ]]; then
            printf '%s\n' "Verdict: PROCEED_WITH_RISKS - Codex degraded but useful."
            return 2
        fi
        return 2
    fi
    if [[ "$CASE_NAME" == "gate_blocks_revise" && "${5:-}" == "embrace-gate" ]]; then
        if [[ "${4:-}" == "synthesizer" ]]; then
            printf '%s\n' "VERDICT: REVISE"
            printf '%s\n' "Do not enter Develop until blockers are resolved."
        else
            printf '%s\n' "Verdict: REVISE"
        fi
        return 0
    fi
    if [[ "$CASE_NAME" == "gate_self_referential_revise" && "${5:-}" == "embrace-gate" ]]; then
        if [[ "${4:-}" == "synthesizer" ]]; then
            cat <<'EOF'
VERDICT: REVISE

The current-run embrace-gate-define-develop-*.md artifact is missing. The context also lacks current-run tangle-validation-*.md and delivery-*.md artifacts. However, this review itself is the gate input and those artifacts cannot be prerequisites for entering Develop.
EOF
        else
            printf '%s\n' "Verdict: REVISE because the current gate artifact does not exist yet."
        fi
        return 0
    fi
    if [[ "$CASE_NAME" == "gate_proceed_with_risks" && "${5:-}" == "embrace-gate" ]]; then
        if [[ "${4:-}" == "synthesizer" ]]; then
            cat <<'EOF'
VERDICT: PROCEED_WITH_RISKS

## Gate Synthesis

### Verdict consolide

**`PROCEED_WITH_RISKS`** - Develop is authorized.

### Non-blocking risks

No hard blocker. Watch phases_completed if it becomes blocked later, but this is observational and must not stop this gate.
EOF
        else
            printf '%s\n' "Verdict: PROCEED_WITH_RISKS"
        fi
        return 0
    fi
    if [[ "$CASE_NAME" == "gate_claude_hangs" && "${5:-}" == "embrace-gate" && "${1:-}" == "claude-sonnet" && "${4:-}" == "code-reviewer" ]]; then
        /bin/sleep 5
        printf '%s\n' "Verdict: PROCEED"
        return 0
    fi
    if [[ "$CASE_NAME" == "gate_claude_hangs" && "${5:-}" == "embrace-gate" && "${4:-}" == "synthesizer" ]]; then
        printf '%s\n' "VERDICT: PROCEED"
        return 0
    fi
    if [[ "$CASE_NAME" == "gate_synthesis_partial_revise_timeout" && "${5:-}" == "embrace-gate" ]]; then
        if [[ "${4:-}" == "synthesizer" ]]; then
            printf '%s\n' "VERDICT: REVISE"
            printf '%s\n' "partial blocking synthesis before timeout."
            /bin/sleep 5
            return 0
        fi
        printf '%s\n' "Verdict: PROCEED"
        return 0
    fi
    if [[ "${5:-}" == "embrace-gate" && "${4:-}" == "synthesizer" ]]; then
        printf '%s\n' "VERDICT: PROCEED"
        return 0
    fi
    printf '%s\n' "gate response from ${1:-agent}"
}
save_session_checkpoint() {
    CHECKPOINTS+="${1}:${2}:${3:-}"$'\n'
}

probe_discover() {
    PHASE_CALLS+="probe "
    [[ "$CASE_NAME" == "signal_interrupt" ]] && { /bin/sleep 5; return 0; }
    [[ "$CASE_NAME" == "missing_probe_output" ]] && return 0
    [[ "$CASE_NAME" == "stale_current_probe_artifact" ]] && return 0
    printf '%s\n' "# probe synthesis" > "$RESULTS_DIR/probe-synthesis-${OCTOPUS_TASK_GROUP:-test}.md"
}

grasp_define() {
    PHASE_CALLS+="grasp "
    printf '%s\n' "# grasp consensus" > "$RESULTS_DIR/grasp-consensus-${OCTOPUS_TASK_GROUP:-test}.md"
}

tangle_develop() {
    PHASE_CALLS+="tangle "
    if [[ "$CASE_NAME" == "tangle_fails" ]]; then
        return 7
    fi
    printf '%s\n' "### Quality Gate: PASSED" > "$RESULTS_DIR/tangle-validation-${OCTOPUS_TASK_GROUP:-test}.md"
}

ink_deliver() {
    PHASE_CALLS+="ink "
    [[ "$CASE_NAME" == "missing_ink_output" ]] && return 0
    printf '%s\n' "# delivery" > "$RESULTS_DIR/delivery-${OCTOPUS_TASK_GROUP:-test}.md"
}

seed_resume_artifacts() {
    local phase="$1"

    printf '%s\n' "# resumed probe synthesis" > "$RESULTS_DIR/probe-synthesis-resume.md"
    case "$phase" in probe) return 0 ;; esac

    printf '%s\n' "# resumed grasp consensus" > "$RESULTS_DIR/grasp-consensus-resume.md"
    case "$phase" in grasp) return 0 ;; esac

    printf '%s\n' "# resumed define gate" > "$RESULTS_DIR/embrace-gate-define-develop-resume.md"
    case "$phase" in debate-define-develop) return 0 ;; esac

    printf '%s\n' "### Quality Gate: PASSED" > "$RESULTS_DIR/tangle-validation-resume.md"
    case "$phase" in tangle) return 0 ;; esac

    printf '%s\n' "# resumed develop gate" > "$RESULTS_DIR/embrace-gate-develop-deliver-resume.md"
    case "$phase" in debate-develop-deliver) return 0 ;; esac

    printf '%s\n' "# resumed delivery" > "$RESULTS_DIR/delivery-resume.md"
}

run_embrace_case() {
    set +e
    CASE_NAME="$1"
    OCTOPUS_EMBRACE_DEBATE_GATES="${2:-none}"
    RESUME_PHASE="${3:-}"
    PHASE_CALLS=""
    CHECKPOINTS=""
    PREFLIGHT_ARGS=""
    EMBRACE_STATUS=0
    FAKE_DATE_EPOCH=""
    RESUME_SESSION=false
    EMBRACE_DEBATE_GATE_OUTPUT=""
    unset OCTOPUS_EMBRACE_GATE_PROVIDER_TIMEOUT
    rm -rf "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR"
    mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR" "$HOME"
    if [[ -n "$RESUME_PHASE" ]]; then
        RESUME_SESSION=true
        seed_resume_artifacts "$RESUME_PHASE"
    fi
    if [[ "$CASE_NAME" == "stale_current_probe_artifact" ]]; then
        FAKE_DATE_EPOCH="1780094000"
        printf '%s\n' "# stale probe from earlier attempt" > "$RESULTS_DIR/probe-synthesis-${FAKE_DATE_EPOCH}.md"
    fi

    embrace_full_workflow "Implement the requested feature" >/dev/null 2>&1
    EMBRACE_STATUS=$?
    FAKE_DATE_EPOCH=""

    return 0
}

run_embrace_case "all_ok" "none" || true

test_case "embrace forces fresh preflight and smoke checks"
if [[ "$PREFLIGHT_ARGS" == $'true\n' ]]; then
    test_pass
else
    test_fail "expected preflight_check true, got ${PREFLIGHT_ARGS//$'\n'/,}"
fi

unset OCTOPUS_EMBRACE_GATE_PROVIDER_TIMEOUT OCTOPUS_EMBRACE_GATE_TIMEOUT OCTOPUS_AGENT_TIMEOUT
test_case "debate gate provider timeout defaults to debate budget"
gate_default_timeout=$(embrace_gate_provider_timeout "claude-sonnet" "Audit a real Embrace run")
if [[ "$gate_default_timeout" =~ ^[0-9]+$ ]] && [[ "$gate_default_timeout" -ge 180 ]]; then
    test_pass
else
    test_fail "expected debate gate timeout >=180s, got ${gate_default_timeout:-empty}"
fi

test_case "no debate gates by default"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ "$CHECKPOINTS" != *"debate-"* ]] && \
   ! ls "$RESULTS_DIR"/embrace-gate-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace ran debate gates even though none were requested"
fi

run_embrace_case "all_ok" "both" || true

test_case "requested debate gates run before develop and deliver"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ "$CHECKPOINTS" == *"debate-define-develop:completed:"* ]] && \
   [[ "$CHECKPOINTS" == *"debate-develop-deliver:completed:"* ]] && \
   ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md >/dev/null 2>&1 && \
   ls "$RESULTS_DIR"/embrace-gate-develop-deliver-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace did not run both requested debate gates"
fi

run_embrace_case "gate_agents_fail" "define" || true

test_case "requested debate gate failure stops before tangle"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp " ]] && \
   [[ "$CHECKPOINTS" == *"debate-define-develop:failed:"* ]]; then
    test_pass
else
    test_fail "embrace continued after requested debate gate failure"
fi

run_embrace_case "gate_codex_degraded_output" "define" || true
GATE_DEGRADED_FILE=$(ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md 2>/dev/null | head -1)

test_case "degraded gate provider output satisfies requested gate"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ -n "$GATE_DEGRADED_FILE" ]] && \
   grep -q 'codex=degraded' "$GATE_DEGRADED_FILE" && \
   grep -q 'Codex degraded but useful' "$GATE_DEGRADED_FILE"; then
    test_pass
else
    test_fail "embrace discarded degraded gate provider output (status=$EMBRACE_STATUS file=${GATE_DEGRADED_FILE:-missing})"
fi

run_embrace_case "gate_blocks_revise" "define" || true

test_case "requested debate gate blocking verdict stops before tangle"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp " ]] && \
   ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace continued after a requested debate gate returned REVISE"
fi

run_embrace_case "gate_self_referential_revise" "define" || true

test_case "self-referential gate artifact revise does not stop before tangle"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace stopped on a self-referential gate artifact blocker"
fi

run_embrace_case "gate_proceed_with_risks" "define" || true

test_case "proceed-with-risks gate verdict ignores non-blocking risk wording"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "embrace stopped despite explicit PROCEED_WITH_RISKS verdict"
fi

test_case "negated proceed gate verdict is blocking"
if embrace_debate_gate_has_blocking_verdict $'Decision: should not proceed without fixing data loss.' && \
   embrace_debate_gate_has_blocking_verdict $'Verdict: cannot proceed safely until the timeout is addressed.' && \
   embrace_debate_gate_has_blocking_verdict $'Gate verdict: unable to proceed because validation is missing.'; then
    test_pass
else
    test_fail "negated proceed wording was parsed as non-blocking"
fi

test_case "non-contiguous proceed negations are blocking"
if embrace_debate_gate_has_blocking_verdict $'Decision: PROCEED is not recommended until validation passes.' && \
   embrace_debate_gate_has_blocking_verdict $'Verdict: recommend against proceeding until evidence exists.' && \
   embrace_debate_gate_has_blocking_verdict $'Gate verdict: do not recommend proceeding because validation is missing.'; then
    test_pass
else
    test_fail "non-contiguous proceed negation was parsed as non-blocking"
fi

test_case "proceed-with-risks prose is not a verdict"
if embrace_debate_gate_has_blocking_verdict $'Risks: proceeding with risks is unacceptable.\nVerdict: REVISE'; then
    test_pass
else
    test_fail "proceed-with-risks prose overrode the actual REVISE verdict"
fi

test_case "structured gate verdict is authoritative"
if ! embrace_debate_gate_has_blocking_verdict $'VERDICT: PROCEED\nRisks: data loss was reviewed.' && \
   ! embrace_debate_gate_has_blocking_verdict $'VERDICT: PROCEED_WITH_RISKS\nRisks: proceed with monitoring.' && \
   embrace_debate_gate_has_blocking_verdict $'VERDICT: REVISE\nNotes: later we may proceed.' && \
   embrace_debate_gate_has_blocking_verdict $'VERDICT: STOP\nNotes: do not proceed.'; then
    test_pass
else
    test_fail "structured verdict token was not authoritative"
fi

test_case "missing or invalid structured gate verdict fails closed"
if embrace_debate_gate_has_blocking_verdict $'Decision: PROCEED\nNo machine-readable verdict.' && \
   embrace_debate_gate_has_blocking_verdict $'Verdict: we advise against proceeding.' && \
   embrace_debate_gate_has_blocking_verdict $'VERDICT: HOLD\nNo canonical verdict.' && \
   embrace_debate_gate_has_blocking_verdict $'VERDICT: PROCEED only after fixing the data loss bug'; then
    test_pass
else
    test_fail "missing/invalid structured verdict did not fail closed"
fi

run_embrace_case "resume_after_define_gate" "both" "debate-define-develop" || true

test_case "resume after define gate runs tangle instead of skipping it"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "tangle ink " ]] && \
   [[ "$CHECKPOINTS" != *"debate-define-develop"* ]] && \
   [[ "$CHECKPOINTS" == *"tangle:"* ]] && \
   [[ "$CHECKPOINTS" == *"debate-develop-deliver"* ]]; then
    test_pass
else
    test_fail "resume from debate-define-develop did not continue at Tangle (status=$EMBRACE_STATUS calls='$PHASE_CALLS' checkpoints='$CHECKPOINTS')"
fi

run_embrace_case "resume_after_tangle" "both" "tangle" || true

test_case "resume after tangle does not rerun define gate or tangle"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "ink " ]] && \
   [[ "$CHECKPOINTS" != *"debate-define-develop"* ]] && \
   [[ "$CHECKPOINTS" != *"tangle:"* ]] && \
   [[ "$CHECKPOINTS" == *"debate-develop-deliver"* ]]; then
    test_pass
else
    test_fail "resume from tangle reran an earlier phase (status=$EMBRACE_STATUS calls='$PHASE_CALLS' checkpoints='$CHECKPOINTS')"
fi
RESUME_PHASE=""
RESUME_SESSION=false

CASE_NAME="gate_claude_hangs"
OCTOPUS_EMBRACE_DEBATE_GATES="define"
OCTOPUS_EMBRACE_GATE_PROVIDER_TIMEOUT=1
PHASE_CALLS=""
CHECKPOINTS=""
EMBRACE_STATUS=0
rm -rf "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR"
mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR" "$HOME"
SECONDS=0
embrace_full_workflow "Implement the requested feature" >/dev/null 2>&1
EMBRACE_STATUS=$?
GATE_HANG_ELAPSED=$SECONDS
unset OCTOPUS_EMBRACE_GATE_PROVIDER_TIMEOUT

GATE_HANG_FILE=$(ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md 2>/dev/null | head -1)

test_case "hanging gate provider times out and degrades cleanly"
if [[ "$EMBRACE_STATUS" -eq 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ "$GATE_HANG_ELAPSED" -lt 4 ]] && \
   [[ -n "$GATE_HANG_FILE" ]] && \
   grep -q 'claude=timeout' "$GATE_HANG_FILE"; then
    test_pass
else
    test_fail "hanging gate provider was not bounded cleanly (status=$EMBRACE_STATUS elapsed=${GATE_HANG_ELAPSED}s file=${GATE_HANG_FILE:-missing})"
fi

CASE_NAME="gate_synthesis_partial_revise_timeout"
OCTOPUS_EMBRACE_DEBATE_GATES="define"
OCTOPUS_EMBRACE_GATE_PROVIDER_TIMEOUT=1
PHASE_CALLS=""
CHECKPOINTS=""
EMBRACE_STATUS=0
rm -rf "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR"
mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR" "$HOME"
SECONDS=0
embrace_full_workflow "Implement the requested feature" >/dev/null 2>&1
EMBRACE_STATUS=$?
GATE_PARTIAL_TIMEOUT_ELAPSED=$SECONDS
unset OCTOPUS_EMBRACE_GATE_PROVIDER_TIMEOUT

GATE_PARTIAL_TIMEOUT_FILE=$(ls "$RESULTS_DIR"/embrace-gate-define-develop-*.md 2>/dev/null | head -1)

test_case "timed-out gate synthesis preserves partial blocking verdict"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp " ]] && \
   [[ "$GATE_PARTIAL_TIMEOUT_ELAPSED" -lt 4 ]] && \
   [[ -n "$GATE_PARTIAL_TIMEOUT_FILE" ]] && \
   grep -q 'partial blocking synthesis before timeout' "$GATE_PARTIAL_TIMEOUT_FILE"; then
    test_pass
else
    test_fail "timed-out gate synthesis lost partial blocking verdict (status=$EMBRACE_STATUS calls='$PHASE_CALLS' elapsed=${GATE_PARTIAL_TIMEOUT_ELAPSED}s file=${GATE_PARTIAL_TIMEOUT_FILE:-missing})"
fi

CASE_NAME="signal_interrupt"
OCTOPUS_EMBRACE_DEBATE_GATES="none"
PHASE_CALLS=""
CHECKPOINTS=""
EMBRACE_STATUS=0
rm -rf "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR"
mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR" "$HOME"
(
    embrace_full_workflow "Implement the requested feature" >/dev/null 2>&1
) &
INTERRUPT_PID=$!
/bin/sleep 1
kill -TERM "$INTERRUPT_PID" 2>/dev/null || true
wait "$INTERRUPT_PID" 2>/dev/null
INTERRUPT_STATUS=$?
INTERRUPT_REPORT=$(ls "$RESULTS_DIR"/embrace-report-*.md 2>/dev/null | head -1)

test_case "interrupted embrace writes failed report"
if [[ "$INTERRUPT_STATUS" -ne 0 ]] && \
   [[ -n "$INTERRUPT_REPORT" ]] && \
   grep -q 'Final Status: FAILED' "$INTERRUPT_REPORT" && \
   grep -q 'received TERM' "$INTERRUPT_REPORT"; then
    test_pass
else
    test_fail "interrupted run did not leave failed report (status=$INTERRUPT_STATUS report=${INTERRUPT_REPORT:-missing})"
fi

run_embrace_case "missing_probe_output" || true

test_case "missing probe synthesis stops before grasp"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe " ]] && \
   [[ "$CHECKPOINTS" == *"probe:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not stop cleanly when probe produced no synthesis artifact"
fi

run_embrace_case "stale_current_probe_artifact" || true

test_case "stale same-task probe artifact cannot satisfy current run"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe " ]] && \
   [[ "$CHECKPOINTS" == *"probe:failed:"* ]]; then
    test_pass
else
    test_fail "embrace accepted a stale same-task probe artifact (status=$EMBRACE_STATUS calls='$PHASE_CALLS')"
fi

run_embrace_case "tangle_fails" || true

test_case "tangle failure stops before ink"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle " ]] && \
   [[ "$CHECKPOINTS" == *"tangle:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not stop cleanly when tangle returned non-zero"
fi

run_embrace_case "missing_ink_output" || true

test_case "missing delivery artifact fails after ink"
if [[ "$EMBRACE_STATUS" -ne 0 ]] && \
   [[ "$PHASE_CALLS" == "probe grasp tangle ink " ]] && \
   [[ "$CHECKPOINTS" == *"ink:failed:"* ]]; then
    test_pass
else
    test_fail "embrace did not fail when ink produced no delivery artifact"
fi

test_summary
