#!/usr/bin/env bash
# Enable HTTP-based telemetry hooks (Claude Code v2.1.63+)
# Replaces shell-based telemetry-webhook.sh with native HTTP POST hooks
# for faster execution and better sandboxing.
#
# Usage: enable-http-telemetry.sh <webhook-url> [bearer-token]
#
# v8.41.0: Feature adoption — HTTP hooks for telemetry (planning doc #6)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_JSON="$PLUGIN_ROOT/.claude-plugin/hooks.json"

WEBHOOK_URL="${1:-}"
BEARER_TOKEN="${2:-}"

if [[ -z "$WEBHOOK_URL" ]]; then
    echo "Usage: enable-http-telemetry.sh <webhook-url> [bearer-token]"
    echo ""
    echo "Replaces shell-based telemetry with native HTTP hooks (CC v2.1.63+)."
    echo "The webhook URL will receive POST requests with phase completion data."
    echo ""
    echo "Example:"
    echo "  ./enable-http-telemetry.sh https://hooks.example.com/octopus my-secret-token"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required. Install with: brew install jq" >&2
    exit 1
fi

echo "Enabling HTTP telemetry hook..."
echo "  URL: $WEBHOOK_URL"
[[ -n "$BEARER_TOKEN" ]] && echo "  Auth: Bearer token configured"

# Build the HTTP hook entry
HTTP_HOOK=$(jq -n \
    --arg url "$WEBHOOK_URL" \
    --arg token "$BEARER_TOKEN" \
    '{
        "matcher": {
            "tool": "Bash",
            "pattern": "orchestrate\\.sh.*(probe|grasp|tangle|ink|embrace)"
        },
        "hooks": [
            {
                "type": "http",
                "url": $url,
                "timeout": 10,
                "headers": (if $token != "" then {"Authorization": ("Bearer " + $token)} else {} end)
            }
        ]
    }')

# Replace the shell-based telemetry entry in PostToolUse
TMP="${HOOKS_JSON}.tmp"
jq --argjson http_hook "$HTTP_HOOK" '
    .PostToolUse = [
        (.PostToolUse[] | select(.hooks[0].command // "" | test("telemetry") | not)),
        $http_hook
    ]
' "$HOOKS_JSON" > "$TMP" && mv "$TMP" "$HOOKS_JSON"

echo ""
echo "Done. HTTP telemetry hook enabled in hooks.json."
echo "The shell-based telemetry-webhook.sh is now bypassed (kept as fallback)."
echo ""
echo "To revert: git checkout .claude-plugin/hooks.json"
