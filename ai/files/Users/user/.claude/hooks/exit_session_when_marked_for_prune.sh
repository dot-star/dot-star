#!/usr/bin/env bash
#
# Stop hook: quit the claude session once the model has marked it for prune
# (an `x` or `xx` reply), so closing it takes no `/exit` or Ctrl+D by hand.
# leave_space_when_prune_mark_written.sh already left the Space when the mark
# landed, so the recap renders off-screen.
#
# Signals the nearest `claude` ancestor from a detached job after a short
# delay, so this hook returns and the final recap renders first.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/exit_session.inc.sh"

session_id=$(command jq --raw-output '.session_id // empty')
if [[ -z "${session_id}" ]]; then
    exit 0
fi

if [[ ! -e "${prune_marks_dir}/${session_id}" ]]; then
    exit 0
fi

claude_pid=$(find_claude_pid)
if [[ -z "${claude_pid}" ]]; then
    exit 0
fi

mark_close_requested

# TODO: Minimize the window while the tab finishes closing (see ai/claude/minimize_own_window.sh).
nohup sh -c "sleep 1; kill -TERM ${claude_pid}" </dev/null >/dev/null 2>&1 &
