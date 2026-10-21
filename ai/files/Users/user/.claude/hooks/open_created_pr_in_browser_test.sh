#!/usr/bin/env bash
# Tests for open_created_pr_in_browser.sh.
# Feeds the hook synthetic PostToolUse payloads with a stub `open` on PATH and
# asserts which URL, if any, the stub was asked to open.
#
# Run: bash ai/files/Users/user/.claude/hooks/open_created_pr_in_browser_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/open_created_pr_in_browser.sh"

if [[ ! -x "${HOOK}" ]]; then
    echo "Missing hook: ${HOOK}"
    exit 1
fi

scratch=$(mktemp -d)
trap 'rm -rf "${scratch}"' EXIT

# Record each URL the hook opens instead of launching a browser.
mkdir "${scratch}/bin"
cat >"${scratch}/bin/open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"${OPENED_LOG}"
EOF
chmod +x "${scratch}/bin/open"
export OPENED_LOG="${scratch}/opened.log"

passes=0
fails=0

# Run the hook on a command and its stdout, then compare what it opened.
check() {
    local name="$1"
    local command="$2"
    local stdout="$3"
    local expected="$4"
    local payload
    local opened

    : >"${OPENED_LOG}"
    payload=$(
        jq -nc \
            --arg command "${command}" \
            --arg stdout "${stdout}" \
            '{tool_input:{command:$command},tool_response:{stdout:$stdout}}'
    )
    PATH="${scratch}/bin:${PATH}" "${HOOK}" <<<"${payload}" >/dev/null
    opened=$(cat "${OPENED_LOG}")

    if [[ "${opened}" == "${expected}" ]]; then
        passes=$((passes + 1))
    else
        fails=$((fails + 1))
        echo "FAIL: ${name}"
        echo "  expected: ${expected:-<nothing>}"
        echo "  opened:   ${opened:-<nothing>}"
    fi
}

check "opens created PR" \
    'gh pr create --repo foo/bar --title "Add baz" --body-file body.md' \
    'https://github.com/foo/bar/pull/123' \
    'https://github.com/foo/bar/pull/123'

check "opens PR after progress output" \
    'git push mine HEAD && gh pr create --fill' \
    $'Creating pull request for foo:baz into master in foo/bar\n\nhttps://github.com/foo/bar/pull/45' \
    'https://github.com/foo/bar/pull/45'

check "ignores other commands" \
    'gh pr view 123' \
    'https://github.com/foo/bar/pull/123' \
    ''

check "skips --web" \
    'gh pr create --web' \
    'https://github.com/foo/bar/pull/123' \
    ''

check "skips failed create" \
    'gh pr create --fill' \
    '' \
    ''

echo "${passes} passed, ${fails} failed"
[[ "${fails}" -eq 0 ]]
