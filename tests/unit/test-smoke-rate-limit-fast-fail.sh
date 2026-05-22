#!/usr/bin/env bash
# Regression checks for provider smoke tests fast-failing quota/rate-limit loops.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/scripts/lib/secure.sh"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/scripts/lib/heartbeat.sh"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/scripts/lib/quota-watcher.sh"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/scripts/lib/smoke.sh"

test_suite "smoke rate-limit fast-fail"

log() { :; }
get_agent_model() { echo "gemini-test-model"; }
get_agent_command() { echo "gemini"; }

test_case "gemini smoke test fast-fails on 429 before timeout"
cat > "$MOCK_BIN_DIR/gemini" <<'EOF'
#!/usr/bin/env bash
echo "Error: code: 429 Too Many Requests - rate limit exceeded" >&2
trap '' TERM
sleep 20
EOF
chmod +x "$MOCK_BIN_DIR/gemini"

result_file="$TEST_TMP_DIR/smoke-result"
start=$(date +%s)
PATH="$MOCK_BIN_DIR:$PATH" OCTOPUS_TMP_DIR="$TEST_TMP_DIR" OCTOPUS_TIMEOUT_KILL_GRACE=1 \
    _smoke_test_provider gemini 10 "$result_file"
elapsed=$(($(date +%s) - start))
result=$(cat "$result_file")

if [[ "$result" == RATE_LIMITED:* && "$elapsed" -le 6 ]]; then
    test_pass
else
    test_fail "expected RATE_LIMITED within 6s, got result='$result' elapsed=${elapsed}s"
fi

test_summary
