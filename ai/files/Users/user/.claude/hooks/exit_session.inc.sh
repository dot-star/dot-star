# Helpers for the hooks that close a claude session once it's marked for prune:
# find the session's claude process, leave its full-screen Space and tell
# claude_run (ai/.aliases.sh) the coming SIGTERM was asked for. Source this;
# don't execute it.

prune_marks_dir="/tmp/claude/prune_marks"

# Print the nearest `claude` ancestor's pid, or nothing when there is none.
# Walk up from the parent rather than trusting it, since a hook may run under a
# `sh -c` wrapper. Return nonzero when a lookup fails, since a command
# substitution drops `set -e` and would otherwise end the walk quietly.
find_claude_pid() {
    local pid="${PPID}"
    local comm

    while [[ "${pid}" -gt 1 ]]; do
        comm=$(ps -o comm= -p "${pid}") || return 1
        if [[ "${comm##*/}" == "claude" ]]; then
            echo "${pid}"
            return 0
        fi

        pid=$(ps -o ppid= -p "${pid}" | tr -d ' ') || return 1
    done
}

# Touch the marker claude_run exports, since SIGTERM restores the terminal just
# as Ctrl+D does but exits 143.
mark_close_requested() {
    if [[ -n "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER:-}" ]]; then
        touch -- "${CLAUDE_RUN_CLOSE_REQUESTED_MARKER}"
    fi
}

# Leave the full-screen Space now rather than once the window closes, since the
# page is done; claude_run skips its own follow after a requested close. Pass
# the session id so the hop skips once focus has moved on to another window.
# Pass the claude pid when already known, so the hop skips its own ancestor walk.
leave_full_screen_space() {
    local session_id="$1"
    local claude_pid="$2"

    if ! "${HOME}/.dot-star/ai/claude/follow_closed_full_screen_space.sh" "now" "${session_id}" "${claude_pid}"; then
        # Close the session anyway; the script already printed why the hop failed.
        true
    fi
}
