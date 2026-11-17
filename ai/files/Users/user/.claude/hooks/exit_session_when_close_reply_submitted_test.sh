#!/usr/bin/env bash

# Check that a bare `x` or `xx` closes the session at once, marking it for
# prune and leaving its Space, except an `x` from a session holding a
# worktree, which still reaches the model to land first. Check that a bare `z`
# closes the same way from anywhere but leaves the session unmarked.
#
# Run: bash ai/files/Users/user/.claude/hooks/exit_session_when_close_reply_submitted_test.sh

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/exit_session_when_close_reply_submitted.sh"

SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
SESSION_ID="test-bare-x-$$"
MARK="/tmp/claude/prune_marks/${SESSION_ID}"
CLOSE_MARK="/tmp/claude/close_marks/${SESSION_ID}"
OPEN_TURN="/tmp/claude/open_turns/${SESSION_ID}"
STOP_BLOCKED="/tmp/claude-state-hook/${SESSION_ID}.stop_blocked"
export CLAUDE_RUN_CLOSE_REQUESTED_MARKER="${SANDBOX}/close_requested"

# Stub the Space hop under a sandboxed HOME, so a run records the hop and its
# arguments instead of moving the real screen.
HOP_RECORD="${SANDBOX}/hopped"
export HOME="${SANDBOX}/home"
mkdir --parents "${HOME}/.dot-star/ai/claude"
printf '#!/usr/bin/env bash\necho "$*" >"%s"\n' "${HOP_RECORD}" >"${HOME}/.dot-star/ai/claude/follow_closed_full_screen_space.sh"
chmod +x "${HOME}/.dot-star/ai/claude/follow_closed_full_screen_space.sh"

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

# Build a repo with a linked worktree, plus a plain directory outside any repo.
REPO="${SANDBOX}/repo"
WORKTREE="${SANDBOX}/worktree"
PLAIN_DIR="${SANDBOX}/plain"
mkdir --parents "${PLAIN_DIR}"
git init --quiet "${REPO}"
git -C "${REPO}" \
    -c user.name="test" \
    -c user.email="test@example.com" \
    commit \
    --quiet \
    --allow-empty \
    --message="init"
git -C "${REPO}" worktree add --quiet "${WORKTREE}"

# Build transcripts whose tool calls touched a worktree under another repo,
# one still on disk and one already torn down.
HELD_WORKTREE="${SANDBOX}/other/.claude/worktrees/held"
mkdir --parents "${HELD_WORKTREE}"
NO_TRANSCRIPT=""
HELD_TRANSCRIPT="${SANDBOX}/held.jsonl"
GONE_TRANSCRIPT="${SANDBOX}/gone.jsonl"
write_transcript() {
    # Write <path> as one assistant turn running a command that names <dir>.
    local path="$1"
    local dir="$2"

    jq \
        --null-input \
        --compact-output \
        --arg command "git -C \"${dir}\" status" \
        '{type: "assistant", message: {content: [{type: "tool_use", input: {command: $command}}]}}' \
        >"${path}"
}
write_transcript "${HELD_TRANSCRIPT}" "${HELD_WORKTREE}"
write_transcript "${GONE_TRANSCRIPT}" "${SANDBOX}/other/.claude/worktrees/gone"

failures=0

assert_close() {
    # Submit <prompt> from <cwd> under the stand-in claude, which outlives the
    # hook unless signaled, with the turn left per <turn> (idle, mid-turn,
    # blocked, closed) and <transcript> as the session's history, and compare
    # "<exit status>, <mark>, <hop>" against <expected>.
    local label="$1"
    local prompt="$2"
    local cwd="$3"
    local turn="$4"
    local transcript="$5"
    local expected="$6"

    rm --force -- "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER}" "${HOP_RECORD}" "${MARK}" "${OPEN_TURN}" "${STOP_BLOCKED}"
    mkdir --parents -- "$(dirname -- "${OPEN_TURN}")" "$(dirname -- "${STOP_BLOCKED}")"

    # Record a stop the way the close Stop hook does, and a block the way announce_window_state.py does.
    if [[ "${turn}" == "mid-turn" ]]; then
        touch -- "${OPEN_TURN}"
    elif [[ "${turn}" == "blocked" ]]; then
        printf '%s\n' "abcdef123456" >"${OPEN_TURN}"
        printf '%s' "abcdef123456" >"${STOP_BLOCKED}"
    elif [[ "${turn}" == "closed" ]]; then
        printf '%s\n' "abcdef123456" >"${OPEN_TURN}"
        printf '%s' "123456abcdef" >"${STOP_BLOCKED}"
    fi

    local input
    input="$(jq \
        --null-input \
        --compact-output \
        --arg sid "${SESSION_ID}" \
        --arg prompt "${prompt}" \
        --arg cwd "${cwd}" \
        --arg transcript "${transcript}" \
        '{session_id: $sid, prompt: $prompt, cwd: $cwd, transcript_path: $transcript, hook_event_name: "UserPromptSubmit"}')"

    # Silence bash's "Terminated" notice for the signaled case.
    {
        "${FAKE_CLAUDE}" -c 'bash "$1" <<<"$2" >/dev/null; sleep 3' _ "${HOOK}" "${input}"
    } 2>/dev/null
    local status=$?

    local mark_state="unmarked"
    if [[ -e "${MARK}" ]]; then
        mark_state="marked"
    fi

    # Require the claude pid the hook already found, so the hop skips its own walk.
    local hop_state="stayed"
    if [[ "$(cat -- "${HOP_RECORD}" 2>/dev/null)" =~ ^now\ ${SESSION_ID}\ [0-9]+$ ]]; then
        hop_state="hopped"
    fi

    local actual="exit ${status}, ${mark_state}, ${hop_state}"
    if [[ "${actual}" == "${expected}" ]]; then
        echo "✓ ${label}"
    else
        echo "✗ ${label}"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        failures=$((failures + 1))
    fi
}

assert_close "x outside a repo closes at once" \
    "x" "${PLAIN_DIR}" "idle" "${NO_TRANSCRIPT}" "exit 143, marked, hopped"
assert_close "x in a main checkout closes at once" \
    "x" "${REPO}" "idle" "${NO_TRANSCRIPT}" "exit 143, marked, hopped"
assert_close "x from a torn-down worktree closes at once" \
    "x" "${SANDBOX}/gone" "idle" "${NO_TRANSCRIPT}" "exit 143, marked, hopped"
assert_close "padded uppercase X closes at once" \
    $' X \n' "${PLAIN_DIR}" "idle" "${NO_TRANSCRIPT}" "exit 143, marked, hopped"
assert_close "xx inside a worktree closes at once" \
    "xx" "${WORKTREE}" "idle" "${NO_TRANSCRIPT}" "exit 143, marked, hopped"
assert_close "x inside a worktree reaches the model" \
    "x" "${WORKTREE}" "idle" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close "drafted pick x2 reaches the model" \
    "x2" "${PLAIN_DIR}" "idle" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close "sentence carrying x reaches the model" \
    "fix x" "${PLAIN_DIR}" "idle" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close "x after a finished turn closes at once" \
    "x" "${REPO}" "closed" "${NO_TRANSCRIPT}" "exit 143, marked, hopped"
assert_close "x after a blocked stop reaches the model" \
    "x" "${REPO}" "blocked" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close "x holding a worktree in another repo reaches the model" \
    "x" "${REPO}" "idle" "${HELD_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close "x after its other-repo worktree was torn down closes at once" \
    "x" "${REPO}" "idle" "${GONE_TRANSCRIPT}" "exit 143, marked, hopped"
assert_close "x mid-turn in a main checkout reaches the model" \
    "x" "${REPO}" "mid-turn" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close "xx mid-turn reaches the model" \
    "xx" "${PLAIN_DIR}" "mid-turn" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close "z outside a repo closes at once without a mark" \
    "z" "${PLAIN_DIR}" "idle" "${NO_TRANSCRIPT}" "exit 143, unmarked, hopped"
assert_close "padded uppercase Z inside a worktree closes at once without a mark" \
    $' Z \n' "${WORKTREE}" "idle" "${NO_TRANSCRIPT}" "exit 143, unmarked, hopped"
assert_close "z mid-turn reaches the model" \
    "z" "${PLAIN_DIR}" "mid-turn" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"

assert_close_mark() {
    # Compare whether the close mark exists against <expected> (present, absent).
    local label="$1"
    local expected="$2"

    local actual="absent"
    if [[ -e "${CLOSE_MARK}" ]]; then
        actual="present"
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

assert_close_mark "z mid-turn leaves a close mark for the turn's end" "present"
assert_close "z after a blocked stop reaches the model" \
    "z" "${PLAIN_DIR}" "blocked" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close_mark "z after a blocked stop leaves a close mark" "present"
assert_close "sentence after a mid-turn z reaches the model" \
    "keep going" "${PLAIN_DIR}" "mid-turn" "${NO_TRANSCRIPT}" "exit 0, unmarked, stayed"
assert_close_mark "sentence after a mid-turn z clears its close mark" "absent"

# Expect a prompt that reaches the model to leave its turn open for the Stop hook to close.
if [[ -e "${OPEN_TURN}" && ! -s "${OPEN_TURN}" ]]; then
    echo "✓ prompt reaching the model opens a turn"
else
    echo "✗ prompt reaching the model opens a turn"
    failures=$((failures + 1))
fi

rm --force -- "${MARK}" "${CLOSE_MARK}" "${OPEN_TURN}" "${STOP_BLOCKED}"
rm -r -- "${SANDBOX}"

if [[ "${failures}" -eq 0 ]]; then
    echo "pass"
else
    echo "fail: ${failures}"
    exit 1
fi
