#!/usr/bin/env bash
# Tests for session editing backend.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "session editing backend"

SESSION_MANAGER="$PROJECT_ROOT/scripts/session-manager.sh"

test_case "edit creates a session file and stores a string field"
tmp_home=$(mktemp -d)
session_file="$tmp_home/.claude-octopus/session.json"
if HOME="$tmp_home" "$SESSION_MANAGER" edit session_name "Release Planning" >/tmp/session-edit-output.json 2>/tmp/session-edit-output.err &&
   [[ -f "$session_file" ]] &&
   jq -e '.session_name == "Release Planning" and (.edited_at | type == "string")' "$session_file" >/dev/null &&
   jq -e '.session_name == "Release Planning"' /tmp/session-edit-output.json >/dev/null; then
    test_pass
else
    test_fail "session_name was not persisted with an edited_at timestamp"
fi

test_case "update applies typed JSON patches without losing existing fields"
tmp_home=$(mktemp -d)
mkdir -p "$tmp_home/.claude-octopus"
cat > "$tmp_home/.claude-octopus/session.json" <<'JSON'
{
  "session_id": "abc123",
  "session_name": "Before"
}
JSON
if HOME="$tmp_home" "$SESSION_MANAGER" update --json '{"autonomy":"autonomous","completed_phases":2,"remote_session":true}' >/dev/null 2>/tmp/session-update-output.err &&
   jq -e '.session_id == "abc123" and .session_name == "Before" and .autonomy == "autonomous" and .completed_phases == 2 and .remote_session == true' "$tmp_home/.claude-octopus/session.json" >/dev/null; then
    test_pass
else
    test_fail "typed JSON patch did not preserve or update expected fields"
fi

test_case "edit rejects protected identity fields"
tmp_home=$(mktemp -d)
mkdir -p "$tmp_home/.claude-octopus"
printf '{"session_id":"original"}\n' > "$tmp_home/.claude-octopus/session.json"
if HOME="$tmp_home" "$SESSION_MANAGER" edit session_id "changed" >/tmp/session-edit-protected.out 2>/tmp/session-edit-protected.err; then
    test_fail "editing session_id should fail"
elif jq -e '.session_id == "original"' "$tmp_home/.claude-octopus/session.json" >/dev/null &&
     grep -q "protected" /tmp/session-edit-protected.err; then
    test_pass
else
    test_fail "protected field rejection did not preserve the original session_id"
fi

test_summary
