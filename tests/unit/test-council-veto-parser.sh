#!/usr/bin/env bash
# Focused regressions for council critical-veto artifact parsing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COUNCIL="$PROJECT_ROOT/scripts/lib/council.sh"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "council veto parser"

test_case "council.sh has valid bash syntax"
if bash -n "$COUNCIL" 2>/dev/null; then
    test_pass
else
    test_fail "syntax error in council.sh"
fi

# shellcheck source=/dev/null
source "$COUNCIL"

test_case "structured critical veto still triggers from veto-capable role"
tmp_dir="$(mktemp -d "$TEST_TMP_DIR/council-veto-parser.XXXXXX")"
mkdir -p "$tmp_dir/responses" "$tmp_dir/critiques" "$tmp_dir/revisions"
council_reset_defaults
COUNCIL_RUN_DIR="$tmp_dir"
COUNCIL_FIXTURE=""
cat > "$tmp_dir/responses/01-security-auditor.md" << 'EOF'
```json
{"severity":"critical","confidence":0.92,"reason":"Credential exposure risk"}
```
EOF
council_scan_veto_artifacts
if [[ "$COUNCIL_VETO_TRIGGERED" == "true" ]] &&
   [[ "$COUNCIL_VETO_SEVERITY" == "critical" ]] &&
   grep -q "Credential exposure" <<< "$COUNCIL_VETO_REASON"; then
    test_pass
else
    test_fail "veto-capable structured critical risk was not detected"
fi
rm -rf "$tmp_dir"

test_case "quoted structured critical text does not trigger veto"
tmp_dir="$(mktemp -d "$TEST_TMP_DIR/council-veto-parser.XXXXXX")"
mkdir -p "$tmp_dir/responses" "$tmp_dir/critiques" "$tmp_dir/revisions"
council_reset_defaults
COUNCIL_RUN_DIR="$tmp_dir"
COUNCIL_FIXTURE=""
cat > "$tmp_dir/responses/01-security-auditor.md" << 'EOF'
I am quoting a rejected peer claim, not issuing my own veto:
> {"severity":"critical","confidence":0.99,"reason":"Quoted only"}

Decision: no veto.
EOF
council_scan_veto_artifacts
if [[ "$COUNCIL_VETO_TRIGGERED" == "true" ]]; then
    test_fail "quoted structured critical text should not trigger veto"
else
    test_pass
fi
rm -rf "$tmp_dir"

test_summary
