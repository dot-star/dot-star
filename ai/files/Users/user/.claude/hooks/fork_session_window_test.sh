#!/usr/bin/env bash
# Tests for shell_quote in fork_session_window.inc.sh.
# Quotes each sample, then asserts the result is valid UTF-8 (osascript rejects
# anything else with error -1700) and that bash and zsh both read it back as the
# original. Run under macOS's /bin/bash to cover the bash 3.2 the hooks run on.
#
# Run: bash ai/files/Users/user/.claude/hooks/fork_session_window_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/fork_session_window.inc.sh"

passes=0
fails=0

run_test() {
    local label="$1"
    local sample="$2"
    local quoted
    local from_bash
    local from_zsh

    quoted=$(shell_quote "${sample}")
    if ! printf '%s' "${quoted}" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then
        fails=$((fails + 1))
        printf "  FAIL  invalid UTF-8: %s  %s\n" "${quoted}" "${label}"
        return
    fi

    from_bash=$(bash -c "printf '%s' ${quoted}")
    from_zsh=$(zsh -c "printf '%s' ${quoted}")
    if [[ "${from_bash}" == "${sample}" ]] && [[ "${from_zsh}" == "${sample}" ]]; then
        passes=$((passes + 1))
        printf "  PASS  %s\n" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  bash=%s zsh=%s  %s\n" "${from_bash}" "${from_zsh}" "${label}"
    fi
}

echo "== shell_quote round-trips through bash ${BASH_VERSION} and zsh =="
run_test "plain words" "add a retry to the upload"
run_test "multibyte character" '" ⌥ Option + D" reads like 3 keys to press'
run_test "single quotes" "it's a 'quoted' task"
run_test "shell metacharacters" 'dollar $HOME `backtick` $(date) \backslash ! bang'
run_test "newline" $'two\nlines'
run_test "empty string" ""

echo ""
echo "== Summary: ${passes} passed, ${fails} failed =="

if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
