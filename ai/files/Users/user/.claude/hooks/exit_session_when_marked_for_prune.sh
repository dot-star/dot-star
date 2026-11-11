#!/usr/bin/env bash
#
# Stop hook: quit the claude session once the model has marked it for prune
# (an `x` or `xx` reply), so closing it takes no `/exit` or Ctrl+D by hand.
# leave_space_when_prune_mark_written.sh already left the Space when the mark
# landed, so the recap renders off-screen.
#
# Signals the nearest `claude` ancestor from a detached job after a short
# delay, so this hook returns and the final recap renders first.
#
# Logs each close to ~/.claude/session_close.jsonl, so a close that fired
# mid-task can be traced after prune.sh deletes the transcript.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/exit_session.inc.sh"

{
    IFS= read -r -d '' session_id
    IFS= read -r -d '' cwd
    IFS= read -r -d '' transcript_path
} < <(
    command jq \
        --raw-output0 \
        '.session_id // "", .cwd // "", .transcript_path // ""'
)

if [[ -z "${session_id}" ]]; then
    exit 0
fi

# Close the turn the bare-x hook opened, so the next bare `x` closes at once.
turn_before=$(describe_turn "${session_id}")
rm --force -- "${open_turns_dir}/${session_id}"

if [[ ! -e "${prune_marks_dir}/${session_id}" ]]; then
    exit 0
fi

claude_pid=$(find_claude_pid)
if [[ -z "${claude_pid}" ]]; then
    exit 0
fi

log_session_close "stop hook" "${session_id}" "${cwd}" "${transcript_path}" "${turn_before}"
mark_close_requested

# TODO: Minimize the window while the tab finishes closing (see ai/claude/minimize_own_window.sh).
nohup sh -c "sleep 1; kill -TERM ${claude_pid}" </dev/null >/dev/null 2>&1 &
