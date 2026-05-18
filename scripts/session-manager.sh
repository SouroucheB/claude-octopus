#!/usr/bin/env bash
# Session Manager - Claude Code v2.1.9+ Session Variable Integration
# Provides session tracking and provider-specific session isolation

set -eo pipefail

# Resolve physical path so the fallback `dirname "$SCRIPT_DIR"` plugin_root
# (used when CLAUDE_PLUGIN_ROOT is unset) is the real install path rather than
# the convenience symlink — prevents self-referential symlink creation. See #371.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/lib/session-id.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/plugin-root.sh" 2>/dev/null || true

session_file_path() {
    printf '%s\n' "${OCTOPUS_SESSION_FILE:-${HOME}/.claude-octopus/session.json}"
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for session editing" >&2
        return 1
    fi
}

validate_session_edit_key() {
    local key="$1"

    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "Error: invalid session field '$key'" >&2
        return 1
    fi

    case "$key" in
        session_id|created_at|started_at|session_start|last_checkpoint|phases|directories)
            echo "Error: session field '$key' is protected" >&2
            return 1
            ;;
    esac
}

ensure_session_json_file() {
    local file="$1"
    mkdir -p "$(dirname "$file")"

    if [[ ! -f "$file" ]]; then
        printf '{}\n' > "$file"
        return 0
    fi

    if ! jq -e 'type == "object"' "$file" >/dev/null 2>&1; then
        echo "Error: session file is not a JSON object: $file" >&2
        return 1
    fi
}

write_session_json() {
    local file="$1"
    local filter="$2"
    shift 2

    local tmp="${file}.tmp.$$"
    if jq "$@" "$filter" "$file" > "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
    fi
}

edit_session_field() {
    local file="$1"
    local key="$2"
    local value="$3"
    local edited_at

    require_jq || return 1
    validate_session_edit_key "$key" || return 1
    ensure_session_json_file "$file" || return 1

    edited_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    write_session_json "$file" '.[$key] = $value | .edited_at = $edited_at' \
        --arg key "$key" \
        --arg value "$value" \
        --arg edited_at "$edited_at" || return 1

    jq '.' "$file"
}

edit_session_patch() {
    local file="$1"
    local patch="$2"
    local edited_at key

    require_jq || return 1

    if ! printf '%s' "$patch" | jq -e 'type == "object"' >/dev/null 2>&1; then
        echo "Error: session patch must be a JSON object" >&2
        return 1
    fi

    while IFS= read -r key; do
        validate_session_edit_key "$key" || return 1
    done < <(printf '%s' "$patch" | jq -r 'keys[]')

    ensure_session_json_file "$file" || return 1

    edited_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    write_session_json "$file" '. + $patch | .edited_at = $edited_at' \
        --argjson patch "$patch" \
        --arg edited_at "$edited_at" || return 1

    jq '.' "$file"
}

print_session_json() {
    local file="$1"

    require_jq || return 1
    if [[ ! -f "$file" ]]; then
        printf '{}\n'
        return 0
    fi

    jq '.' "$file"
}

parse_session_file_flag() {
    if [[ "${1:-}" == "--file" ]]; then
        if [[ -z "${2:-}" ]]; then
            echo "Error: --file requires a path" >&2
            return 1
        fi
        printf '%s\n' "$2"
        return 0
    fi

    session_file_path
}

# Export session variables for Claude Code v2.1.9+
export_session_variables() {
    # Use Claude Code's official Bash session ID if available, otherwise generate.
    if declare -f octo_resolve_session_id >/dev/null 2>&1; then
        export OCTOPUS_SESSION_ID
        OCTOPUS_SESSION_ID=$(octo_resolve_session_id "octopus-$(date +%s)")
    elif [[ -n "${CLAUDE_CODE_SESSION_ID:-${CLAUDE_SESSION_ID:-}}" ]]; then
        export OCTOPUS_SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${CLAUDE_SESSION_ID:-}}"
    else
        export OCTOPUS_SESSION_ID="octopus-$(date +%s)"
    fi

    # Provider-specific session IDs
    export OCTOPUS_CODEX_SESSION="codex-${OCTOPUS_SESSION_ID}"
    export OCTOPUS_GEMINI_SESSION="gemini-${OCTOPUS_SESSION_ID}"
    export OCTOPUS_CLAUDE_SESSION="claude-${OCTOPUS_SESSION_ID}"

    # Bridge CLAUDE_PLUGIN_ROOT to a stable symlink for LLM Bash tool access.
    # CLAUDE_PLUGIN_ROOT is set by Claude Code for hook execution but NOT
    # available in the LLM's Bash shell. This symlink makes all skill
    # references to ${HOME}/.claude-octopus/plugin/scripts/... resolve correctly.
    # Created BEFORE session directories so the symlink exists even if mkdir fails.
    #
    # IMPORTANT: canonicalize plugin_root to its physical path before passing
    # to the self-heal. Claude Code may set CLAUDE_PLUGIN_ROOT to the stable
    # symlink path itself, which would otherwise cause octo_ensure_stable_plugin_root
    # to recreate the symlink pointing at itself (ELOOP). See #371.
    local plugin_root_raw="${CLAUDE_PLUGIN_ROOT:-$(dirname "$SCRIPT_DIR")}"
    local plugin_root
    plugin_root="$(cd "$plugin_root_raw" 2>/dev/null && pwd -P)" || plugin_root="$plugin_root_raw"
    if declare -f octo_ensure_stable_plugin_root >/dev/null 2>&1; then
        octo_ensure_stable_plugin_root "$plugin_root" >/dev/null 2>&1 || true
    else
        mkdir -p "${HOME}/.claude-octopus"
        ln -sfn "$plugin_root" "${HOME}/.claude-octopus/plugin"
    fi

    # Session directories
    export OCTOPUS_SESSION_DIR="${HOME}/.claude-octopus/sessions/${OCTOPUS_SESSION_ID}"
    export OCTOPUS_SESSION_RESULTS="${OCTOPUS_SESSION_DIR}/results"
    export OCTOPUS_SESSION_LOGS="${OCTOPUS_SESSION_DIR}/logs"
    export OCTOPUS_SESSION_PLANS="${OCTOPUS_SESSION_DIR}/plans"

    # Create session directories
    mkdir -p "$OCTOPUS_SESSION_RESULTS" "$OCTOPUS_SESSION_LOGS" "$OCTOPUS_SESSION_PLANS"

    # Write session metadata
    cat > "${OCTOPUS_SESSION_DIR}/.session-metadata.json" <<EOF
{
  "session_id": "$OCTOPUS_SESSION_ID",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "providers": {
    "codex": "$OCTOPUS_CODEX_SESSION",
    "gemini": "$OCTOPUS_GEMINI_SESSION",
    "claude": "$OCTOPUS_CLAUDE_SESSION"
  },
  "directories": {
    "results": "$OCTOPUS_SESSION_RESULTS",
    "logs": "$OCTOPUS_SESSION_LOGS",
    "plans": "$OCTOPUS_SESSION_PLANS"
  }
}
EOF
}

# Get session info
get_session_info() {
    if [[ -z "${OCTOPUS_SESSION_ID:-}" ]]; then
        echo "No active session"
        return 1
    fi

    echo "Session ID: $OCTOPUS_SESSION_ID"
    echo "Results: $OCTOPUS_SESSION_RESULTS"
    echo "Logs: $OCTOPUS_SESSION_LOGS"
    echo ""
    echo "Provider Sessions:"
    echo "  🔴 Codex:  $OCTOPUS_CODEX_SESSION"
    echo "  🟡 Gemini: $OCTOPUS_GEMINI_SESSION"
    echo "  🔵 Claude: $OCTOPUS_CLAUDE_SESSION"
}

# Clean up old sessions (keep last 10)
cleanup_old_sessions() {
    local sessions_dir="${HOME}/.claude-octopus/sessions"
    if [[ ! -d "$sessions_dir" ]]; then
        return 0
    fi

    # Keep 10 most recent sessions, delete the rest
    local count=0
    for session_dir in $(ls -dt "$sessions_dir"/*/ 2>/dev/null); do
        ((count++)) || true
        if [[ $count -gt 10 ]]; then
            echo "Removing old session: $(basename "$session_dir")"
            rm -rf "$session_dir"
        fi
    done
}

# Main command dispatcher
case "${1:-}" in
    export)
        export_session_variables
        ;;
    info)
        get_session_info
        ;;
    get)
        shift
        _session_file=$(parse_session_file_flag "$@") || exit 1
        print_session_json "$_session_file"
        ;;
    edit|update)
        shift
        _session_file=$(parse_session_file_flag "$@") || exit 1
        if [[ "${1:-}" == "--file" ]]; then
            shift 2
        fi

        case "${1:-}" in
            --json)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --json requires a JSON object" >&2
                    exit 1
                fi
                edit_session_patch "$_session_file" "$2"
                ;;
            --stdin)
                _patch=$(cat)
                edit_session_patch "$_session_file" "$_patch"
                ;;
            "")
                echo "Error: edit requires a field and value, --json, or --stdin" >&2
                exit 1
                ;;
            *)
                if [[ -z "${2+x}" ]]; then
                    echo "Error: edit requires a value for field '$1'" >&2
                    exit 1
                fi
                edit_session_field "$_session_file" "$1" "$2"
                ;;
        esac
        ;;
    cleanup)
        cleanup_old_sessions
        ;;
    *)
        cat <<EOF
Usage: session-manager.sh COMMAND

Commands:
  export    Export session variables (OCTOPUS_SESSION_ID, provider sessions, etc.)
  info      Display current session information
  get       Print the session JSON (uses OCTOPUS_SESSION_FILE or ~/.claude-octopus/session.json)
  edit      Edit a session field: edit [--file PATH] FIELD VALUE
  update    Apply a session JSON patch: update [--file PATH] --json '{"field": "value"}'
  cleanup   Remove old sessions (keep last 10)

EOF
        exit 1
        ;;
esac
