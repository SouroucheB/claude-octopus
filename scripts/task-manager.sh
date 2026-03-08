#!/usr/bin/env bash
# Task Manager Helper - Claude Code v2.1.16+ Task Management Integration
# v8.41.0: Simplified — prefer native TodoWrite for Claude-side task tracking.
# This script retains only orchestration-specific state (phase→task ID mapping)
# and cleanup. TaskCreate/TaskUpdate text generation is deprecated in favor of
# direct TodoWrite calls from within Claude's context.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Task state file (stores task IDs for the current session)
TASK_STATE_FILE="${HOME}/.claude-octopus/task-state-${CLAUDE_SESSION_ID:-default}.json"

# Initialize task state
init_task_state() {
    mkdir -p "$(dirname "$TASK_STATE_FILE")"
    if [[ ! -f "$TASK_STATE_FILE" ]]; then
        echo '{}' > "$TASK_STATE_FILE"
    fi
}

# Store task ID for a phase
store_task_id() {
    local phase="$1"
    local task_id="$2"

    init_task_state

    # Update JSON with new task ID
    local tmp_file="${TASK_STATE_FILE}.tmp"
    jq --arg phase "$phase" --arg id "$task_id" \
        '.[$phase] = $id' \
        "$TASK_STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$TASK_STATE_FILE"
}

# Get task ID for a phase
get_task_id() {
    local phase="$1"

    if [[ ! -f "$TASK_STATE_FILE" ]]; then
        echo ""
        return
    fi

    jq -r --arg phase "$phase" '.[$phase] // ""' "$TASK_STATE_FILE"
}

# DEPRECATED: Use native TodoWrite directly from Claude's context instead.
# These functions are kept for backward compatibility with orchestrate.sh callers.
create_embrace_tasks() {
    echo "# v8.41.0: Use TodoWrite directly for task tracking" >&2
    echo "# Phase tasks: Discover, Define, Develop, Deliver" >&2
}

create_phase_task() {
    echo "# v8.41.0: Use TodoWrite directly for phase task: ${1:-unknown}" >&2
}

# Get task status summary
get_task_status() {
    init_task_state

    local discover_id=$(get_task_id "discover")
    local define_id=$(get_task_id "define")
    local develop_id=$(get_task_id "develop")
    local deliver_id=$(get_task_id "deliver")

    local status_parts=()

    [[ -n "$discover_id" ]] && status_parts+=("Discover:$discover_id")
    [[ -n "$define_id" ]] && status_parts+=("Define:$define_id")
    [[ -n "$develop_id" ]] && status_parts+=("Develop:$develop_id")
    [[ -n "$deliver_id" ]] && status_parts+=("Deliver:$deliver_id")

    if [[ ${#status_parts[@]} -eq 0 ]]; then
        echo "No active tasks"
    else
        echo "${status_parts[*]}"
    fi
}

# Clean up task state for session
cleanup_task_state() {
    if [[ -f "$TASK_STATE_FILE" ]]; then
        rm -f "$TASK_STATE_FILE"
    fi
}

# Main command dispatcher
case "${1:-}" in
    create-embrace)
        create_embrace_tasks "$2"
        ;;
    create-phase)
        create_phase_task "$2" "$3"
        ;;
    store-id)
        store_task_id "$2" "$3"
        ;;
    get-id)
        get_task_id "$2"
        ;;
    get-status)
        get_task_status
        ;;
    cleanup)
        cleanup_task_state
        ;;
    *)
        cat <<EOF
Usage: task-manager.sh COMMAND [ARGS]

Commands:
  create-embrace PROMPT      Generate TaskCreate commands for all 4 phases
  create-phase PHASE PROMPT  Generate TaskCreate command for single phase
  store-id PHASE TASK_ID     Store task ID for phase
  get-id PHASE               Get task ID for phase
  get-status                 Get task status summary
  cleanup                    Clean up task state file

EOF
        exit 1
        ;;
esac
