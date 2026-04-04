#!/usr/bin/env bash
# Claude Octopus — PostCompact Hook (v9.19.0)
# Fires AFTER context compaction completes. Reads state persisted by
# pre-compact.sh and re-injects critical workflow context that compaction dropped.
#
# Hook event: PostCompact (CC v2.1.76+, SUPPORTS_POST_COMPACT_HOOK)
# Companion: pre-compact.sh (PreCompact) saves the snapshot this hook reads
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

STATE_DIR="${HOME}/.claude-octopus/.octo"
SNAPSHOT="${STATE_DIR}/pre-compact-snapshot.json"

# Nothing to recover if pre-compact didn't save a snapshot
[[ -f "$SNAPSHOT" ]] || exit 0

# Only inject if snapshot is <10 min old (avoid stale re-injection from old sessions)
now=$(date +%s)
if [[ "$(uname)" == "Darwin" ]]; then
    mod=$(stat -f %m "$SNAPSHOT" 2>/dev/null || echo 0)
else
    mod=$(stat -c %Y "$SNAPSHOT" 2>/dev/null || echo 0)
fi
age=$(( now - mod ))
[[ $age -gt 600 ]] && exit 0

# Guard: require jq for structured reads
command -v jq &>/dev/null || exit 0

# Output context for Claude to see after compaction
phase=$(jq -r '.phase // empty' "$SNAPSHOT" 2>/dev/null)
workflow=$(jq -r '.workflow // empty' "$SNAPSHOT" 2>/dev/null)
autonomy=$(jq -r '.autonomy // empty' "$SNAPSHOT" 2>/dev/null)
completed=$(jq -r '.completed_phases // [] | join(", ")' "$SNAPSHOT" 2>/dev/null)
blockers=$(jq -r '.blockers // [] | join("; ")' "$SNAPSHOT" 2>/dev/null)

if [[ -n "$phase" && "$phase" != "null" ]]; then
    echo "[Octopus PostCompact] Context recovered after compaction:"
    echo "  Phase: ${phase} | Workflow: ${workflow:-unknown} | Autonomy: ${autonomy:-supervised}"
    [[ -n "$completed" && "$completed" != "null" ]] && echo "  Completed: $completed"
    [[ -n "$blockers" && "$blockers" != "null" ]] && echo "  Blockers: $blockers"
    echo "  Tip: Run /octo:resume if you need to rebuild full workflow context."
fi

exit 0
