#!/usr/bin/env bash
# Regression checks for compact /octo:ink delivery context.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS="$PROJECT_ROOT/scripts/lib/workflows.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "ink compact delivery"

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
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$HOME" "$RESULTS_DIR" "$LOGS_DIR" "$WORKSPACE_DIR"

make_payload() {
    local token="$1"
    local count="$2"
    local i
    for i in $(seq 1 "$count"); do
        printf '%s line %04d: repeated raw provider output for delivery regression\n' "$token" "$i"
    done
}

reset_results() {
    rm -rf "$RESULTS_DIR"
    mkdir -p "$RESULTS_DIR"
}

reset_results
probe_file="$RESULTS_DIR/probe-synthesis-test.md"
grasp_file="$RESULTS_DIR/grasp-consensus-test.md"
tangle_file="$RESULTS_DIR/tangle-validation-test.md"

{
    echo "# Probe"
    echo "[Synthesis failed - raw results attached]"
    make_payload "PROBE_RAW" 180
} > "$probe_file"

printf '%s\n' "# Grasp" "Consensus: use bounded delivery context." > "$grasp_file"

{
    echo "# Tangle"
    echo "### Quality Gate: PASSED"
    make_payload "TANGLE_RAW" 180
    echo "RAW_TAIL_SHOULD_NOT_APPEAR"
} > "$tangle_file"

OCTOPUS_INK_FILE_CONTEXT_CHARS=900
OCTOPUS_INK_CONTEXT_CHARS=4200

test_case "compact delivery context is bounded and sanitizes failed synthesis markers"
context="$(build_ink_delivery_context "$tangle_file")"
if [[ ${#context} -le 5200 ]] && \
   [[ "$context" == *"## Source: Tangle Validation"* ]] && \
   [[ "$context" == *"## Source: Grasp Consensus"* ]] && \
   [[ "$context" == *"## Source: Probe Synthesis"* ]] && \
   [[ "$context" == *"Upstream phase synthesis failed; raw fallback omitted"* ]] && \
   [[ "$context" != *"[Synthesis failed - raw results attached]"* ]] && \
   [[ "$context" == *"truncated by ink delivery context"* ]] && \
   [[ "$context" != *"RAW_TAIL_SHOULD_NOT_APPEAR"* ]]; then
    test_pass
else
    test_fail "compact delivery context did not stay bounded/sanitized"
fi

test_case "context sanitizer is byte-safe under invalid UTF-8"
sanitize_err="$TEST_ROOT/sanitize.err"
sanitize_out="$(printf 'bad-byte: \303\050\n[Synthesis failed - raw results attached]\n' | ink_delivery_sanitize_context 2>"$sanitize_err")"
if [[ ! -s "$sanitize_err" ]] && \
   [[ "$sanitize_out" == *"bad-byte:"* ]] && \
   [[ "$sanitize_out" == *"Upstream phase synthesis failed; raw fallback omitted"* ]]; then
    test_pass
else
    test_fail "sanitizer emitted stderr or failed replacement: $(cat "$sanitize_err" 2>/dev/null)"
fi

CYAN=""
GREEN=""
MAGENTA=""
NC=""
DRY_RUN=false
SUPPORTS_BATCH_COMMAND=false
OCTOPUS_REVIEW_4X10=false
LAST_INK_REVIEW_PROMPT_FILE="$TEST_ROOT/last-ink-review-prompt.txt"

log() { :; }
octopus_phase_banner() { :; }
display_workflow_cost_estimate() { return 0; }
retrospective_ceremony() { :; }
score_cross_model_review() { echo "10:10:10:10"; }
format_review_scorecard() { :; }
write_structured_decision() { :; }
octopus_complete() { :; }
run_agent_sync() {
    local provider="$1"
    local prompt="${2:-}"
    local phase="${5:-}"
    if [[ "$provider" == "claude-sonnet" && "$phase" == "ink" ]]; then
        printf '%s' "$prompt" > "$LAST_INK_REVIEW_PROMPT_FILE"
        printf '%s\n' \
            "Security: 10/10" \
            "Reliability: 10/10" \
            "Performance: 10/10" \
            "Accessibility: 10/10" \
            "No issues found."
        return 0
    fi
    return 1
}

test_case "ink fallback delivery does not attach raw phase artifacts"
if ink_deliver "Implement the requested feature" "$tangle_file" >/dev/null 2>&1; then
    delivery_file="$(ls -t "$RESULTS_DIR"/delivery-*.md 2>/dev/null | head -1)"
    delivery_content="$(cat "$delivery_file")"
    if [[ -n "$delivery_file" ]] && \
       [[ "$delivery_content" == *"Automated synthesis unavailable."* ]] && \
       [[ "$delivery_content" == *"Context policy: bounded excerpts"* ]] && \
       [[ "$delivery_content" != *"[Synthesis failed - raw results attached]"* ]] && \
       [[ "$delivery_content" != *"RAW_TAIL_SHOULD_NOT_APPEAR"* ]]; then
        test_pass
    else
        test_fail "fallback delivery attached raw artifacts or propagated failed synthesis marker"
    fi
else
    test_fail "ink_deliver returned non-zero in fallback scenario"
fi

test_case "ink review prompt does not penalize future delivery artifact"
last_review_prompt="$(cat "$LAST_INK_REVIEW_PROMPT_FILE" 2>/dev/null || true)"
if [[ "$last_review_prompt" == *"Do not penalize the absence of the final delivery document"* ]] && \
   [[ "$last_review_prompt" == *"If a dimension is not applicable"* ]]; then
    test_pass
else
    test_fail "ink review prompt does not explain pre-delivery/N-A scoring semantics"
fi

reset_results
printf '%s
' "# Tangle" "### Quality Gate: PASSED" > "$tangle_file"
score_cross_model_review() { echo "8:7:7:NA"; }
format_review_scorecard() { :; }

test_case "ink min-score gate ignores non-applicable dimensions"
if ink_deliver "Implement a CLI-only file change" "$tangle_file" >/dev/null 2>&1; then
    test_pass
else
    test_fail "ink_deliver failed because an N/A dimension was treated as below threshold"
fi

test_summary
