#!/usr/bin/env bash

# Check that the hook signals its claude ancestor and touches claude_run's
# close-requested marker only when the session carries a prune mark.
#
# Run: bash ai/files/Users/user/.claude/hooks/exit_session_when_marked_for_prune_test.sh

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/exit_session_when_marked_for_prune.sh"

SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
SESSION_ID="test-exit-session-$$"
MARK="/tmp/claude/prune_marks/${SESSION_ID}"
export CLAUDE_RUN_CLOSE_REQUESTED_MARKER="${SANDBOX}/close_requested"

# Stand in for claude with a bash reached through a link named after it, so
# the hook's walk stops there instead of at the claude running this test.
FAKE_CLAUDE="${SANDBOX}/claude"
ln -s /bin/bash "${FAKE_CLAUDE}"

# Abort before any kill when the stand-in doesn't read as claude, since the
# walk would go on to signal the real one. Trail a `true` so bash doesn't exec
# into `ps` and report its name.
fake_comm="$("${FAKE_CLAUDE}" -c 'ps -o comm= -p $$; true')"
if [[ "${fake_comm##*/}" != "claude" ]]; then
    echo "fail: stand-in claude reads as ${fake_comm}"
    rm -r -- "${SANDBOX}"
    exit 1
fi

failures=0

assert_exit() {
    # Run the hook under the stand-in claude, which outlives the hook's delayed
    # kill unless signaled, and compare "<exit status>, <marker state>" against
    # <expected>.
    local label="$1"
    local expected="$2"

    rm --force -- "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER}"

    local input
    input="$(jq \
        --null-input \
        --compact-output \
        --arg sid "${SESSION_ID}" \
        '{session_id: $sid, hook_event_name: "Stop"}')"

    # Silence bash's "Terminated" notice for the signaled case.
    {
        "${FAKE_CLAUDE}" -c 'bash "$1" <<<"$2"; sleep 3' _ "${HOOK}" "${input}"
    } 2>/dev/null
    local status=$?

    local marker_state="close not requested"
    if [[ -e "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER}" ]]; then
        marker_state="close requested"
    fi

    local actual="exit ${status}, ${marker_state}"
    if [[ "${actual}" == "${expected}" ]]; then
        echo "✓ ${label}"
    else
        echo "✗ ${label}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        failures=$((failures + 1))
    fi
}

rm --force -- "${MARK}"
assert_exit "unmarked session keeps running" \
    "exit 0, close not requested"

mkdir --parents "$(dirname -- "${MARK}")"
touch -- "${MARK}"
assert_exit "marked session gets SIGTERM after asking claude_run to close" \
    "exit 143, close requested"

rm --force -- "${MARK}"
rm -r -- "${SANDBOX}"

if [[ "${failures}" -eq 0 ]]; then
    echo "pass"
else
    echo "fail: ${failures}"
    exit 1
fi
