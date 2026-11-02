#!/usr/bin/env bash

# Check that the hook leaves the Space only when the write landed on this
# session's own prune mark.
#
# Run: bash ai/files/Users/user/.claude/hooks/leave_space_when_prune_mark_written_test.sh

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/leave_space_when_prune_mark_written.sh"

SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
SESSION_ID="test-leave-space-$$"

# Stub the Space hop under a sandboxed HOME, so a run records the hop instead
# of moving the real screen.
HOP_RECORD="${SANDBOX}/hopped"
export HOME="${SANDBOX}/home"
mkdir --parents "${HOME}/.dot-star/ai/claude"
printf '#!/usr/bin/env bash\ntouch -- "%s"\n' "${HOP_RECORD}" >"${HOME}/.dot-star/ai/claude/follow_closed_full_screen_space.sh"
chmod +x "${HOME}/.dot-star/ai/claude/follow_closed_full_screen_space.sh"

failures=0

assert_hop() {
    # Feed the hook a write to <file_path> and compare its hop against <expected>.
    local label="$1"
    local file_path="$2"
    local expected="$3"

    rm --force -- "${HOP_RECORD}"

    jq \
        --null-input \
        --compact-output \
        --arg sid "${SESSION_ID}" \
        --arg path "${file_path}" \
        '{session_id: $sid, tool_name: "Write", tool_input: {file_path: $path}}' |
        bash "${HOOK}"

    local actual="stayed"
    if [[ -e "${HOP_RECORD}" ]]; then
        actual="hopped"
    fi

    if [[ "${actual}" == "${expected}" ]]; then
        echo "✓ ${label}"
    else
        echo "✗ ${label}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        failures=$((failures + 1))
    fi
}

assert_hop "own prune mark leaves the Space" \
    "/tmp/claude/prune_marks/${SESSION_ID}" "hopped"
assert_hop "another session's mark stays" \
    "/tmp/claude/prune_marks/other-session" "stayed"
assert_hop "unrelated file stays" \
    "${SANDBOX}/notes.md" "stayed"

rm -r -- "${SANDBOX}"

if [[ "${failures}" -eq 0 ]]; then
    echo "pass"
else
    echo "fail: ${failures}"
    exit 1
fi
