#!/usr/bin/env bash
#
# Stop hook: quit the claude session once the model has marked it for prune
# (an `x` or `xx` reply), so closing it takes no `/exit` or Ctrl+D by hand.
# leave_space_when_prune_mark_written.sh already left the Space when the mark
# landed, so the recap renders off-screen.
#
# Quits on a close mark too (a `z` sent mid-turn), leaving the Space itself
# and deleting the mark, so the session stays resumable and unpruned.
#
# Signals the nearest `claude` ancestor from a detached job after a short
# delay, so this hook returns and the final recap renders first. Skips the
# close when a sibling Stop hook blocked the stop, keeping the mark for the
# stop that really ends the turn.
#
# Logs each close to ~/.claude/session_close.jsonl, so a close that fired
# mid-task can be traced after prune.sh deletes the transcript.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/exit_session.inc.sh"

{
    IFS= read -r -d '' session_id
    IFS= read -r -d '' cwd
    IFS= read -r -d '' transcript_path
    IFS= read -r -d '' last_message
} < <(
    command jq \
        --raw-output0 \
        '.session_id // "", .cwd // "", .transcript_path // "", .last_assistant_message // ""'
)

if [[ -z "${session_id}" ]]; then
    exit 0
fi

# Close the turn the close-reply hook opened by recording this stop, so a sibling
# Stop hook blocking it in parallel still reads as a running turn.
turn_before=$(describe_turn "${session_id}")
fingerprint=$(stop_fingerprint "${last_message}")
mkdir --parents -- "${open_turns_dir}"
echo "${fingerprint}" >"${open_turns_dir}/${session_id}"

close_mark="${close_marks_dir}/${session_id}"

if [[ -e "${prune_marks_dir}/${session_id}" ]]; then
    trigger="stop hook"
elif [[ -e "${close_mark}" ]]; then
    trigger="stop hook, close mark"
else
    exit 0
fi

claude_pid=$(find_claude_pid)
if [[ -z "${claude_pid}" ]]; then
    exit 0
fi

# Report whether a sibling Stop hook sent Claude back to work on this stop,
# which it records through announce_window_state.py before answering.
stop_was_blocked() {
    local blocked_file="${session_state_dir}/${session_id}.stop_blocked"

    if [[ ! -f "${blocked_file}" ]]; then
        return 1
    fi

    [[ "$(<"${blocked_file}")" == "${fingerprint}" ]]
}

close_session() {
    # Wait out the parallel Stop hooks, then keep the session and its mark when
    # one blocked this stop, so the close lands on the stop that ends the turn.
    sleep 1
    if stop_was_blocked; then
        return 0
    fi

    log_session_close "${trigger}" "${session_id}" "${cwd}" "${transcript_path}" "${turn_before}"
    mark_close_requested

    # Leave the Space here for a close mark, since no hook left it when the mark landed.
    if [[ -e "${close_mark}" ]]; then
        rm --force -- "${close_mark}"
        leave_full_screen_space "${session_id}" "${claude_pid}"
    fi

    # TODO: Minimize the window while the tab finishes closing (see ai/claude/minimize_own_window.sh).
    kill -TERM "${claude_pid}"
}

# Close from a detached job ignoring hangups, so this hook returns and the final recap renders first.
(
    trap '' HUP
    close_session
) </dev/null >/dev/null 2>&1 &
disown
