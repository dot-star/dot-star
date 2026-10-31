#!/usr/bin/env bash
#
# Stop hook: quit the claude session once the model has marked it for prune
# (an `x` or `xx` reply), so closing it takes no `/exit` or Ctrl+D by hand.
#
# Signals the nearest `claude` ancestor from a detached job after a short
# delay, so this hook returns and the final recap renders first. SIGTERM
# restores the terminal just as Ctrl+D does but exits 143, so touch the marker
# claude_run (ai/.aliases.sh) exports, telling it the kill was asked for.

set -euo pipefail

marks_dir="/tmp/claude/prune_marks"

session_id=$(command jq --raw-output '.session_id // empty')
if [[ -z "${session_id}" ]]; then
    exit 0
fi

if [[ ! -e "${marks_dir}/${session_id}" ]]; then
    exit 0
fi

# Walk up from the parent rather than trusting it, since the hook may run
# under a `sh -c` wrapper.
claude_pid=""
pid="${PPID}"
while [[ "${pid}" -gt 1 ]]; do
    comm=$(ps -o comm= -p "${pid}")
    if [[ "${comm##*/}" == "claude" ]]; then
        claude_pid="${pid}"
        break
    fi

    pid=$(ps -o ppid= -p "${pid}" | tr -d ' ')
done

if [[ -z "${claude_pid}" ]]; then
    exit 0
fi

if [[ -n "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER:-}" ]]; then
    touch -- "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER}"
fi

# Leave the full-screen Space now rather than once the window closes, since the
# page is done; claude_run skips its own follow after a requested close.
if ! "${HOME}/.dot-star/ai/claude/follow_closed_full_screen_space.sh" leave; then
    # Close the session anyway; the script already printed why the hop failed.
    true
fi

# TODO: Minimize the window while the tab finishes closing (see ai/claude/minimize_own_window.sh).
nohup sh -c "sleep 1; kill -TERM ${claude_pid}" </dev/null >/dev/null 2>&1 &
