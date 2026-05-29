#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "anti-sycophancy timeout reporting"

RESULTS_DIR="$(mktemp -d)"
REPO_DIR="$(mktemp -d)"
trap 'rm -rf "$RESULTS_DIR" "$REPO_DIR"' EXIT

GREEN=""
RED=""
YELLOW=""
DIM=""
NC=""
_BOX_TOP=""
_BOX_BOT=""
QUALITY_THRESHOLD=70
MAX_QUALITY_RETRIES=0
LOOP_UNTIL_APPROVED=false
OCTOPUS_ANTISYCOPHANCY=true

log() { :; }
record_task_metric() { :; }
write_structured_decision() { :; }
evaluate_quality_branch() { echo "proceed"; }
run_file_validation() { :; }
get_gate_threshold() { echo 70; }
run_agent_sync() { return 124; }

source "$PROJECT_ROOT/scripts/lib/testing.sh"

write_success_result() {
    local path="$1"
    cat > "$path" <<'EOF'
# Agent: codex
# Task ID: tangle-anti-0
# Phase: tangle

## Output
Architecture analysis completed with deterministic evidence.

## Verification
- Test fixture verification completed.
TANGLE_REPORT_COMPLETE

## Status: SUCCESS
EOF
}

test_case "timed-out anti-sycophancy check is challenged, not passed"
if (
    cd "$REPO_DIR"
    git init -q
    git config user.email test@example.com
    git config user.name "Octopus Test"
    printf 'base\n' > README.md
    git add README.md
    git commit -q -m init

    write_success_result "$RESULTS_DIR/codex-tangle-anti-0.md"
    RESULTS_DIR="$RESULTS_DIR" validate_tangle_results "anti" "Analyze architecture tradeoffs" >/dev/null 2>&1
    grep -q "### Quality Gate: CHALLENGED" "$RESULTS_DIR/tangle-validation-anti.md" && \
    grep -q "Anti-Sycophancy Check Unavailable" "$RESULTS_DIR/tangle-validation-anti.md"
); then
    test_pass
else
    test_fail "anti-sycophancy timeout was not reported as challenged/unavailable"
fi

test_summary
