# Open a Ghostty window running a clean `claude_run` forked from another
# session. Source this; don't execute it. The window gets the parent's session
# id and transcript path in its environment, where announce_fork_parent.sh
# picks them up at SessionStart.
#
# The window opens in the main checkout, even from a worktree, so the fork never
# shares the parent's worktree; it makes its own. A window rather than a tab
# keeps the fork's separate objective out of the parent's tab bar.

# Open the fork window and echo the directory it opened in; echo the reason and return 1 when it can't.
# Usage:
#   open_fork_window <session-id> <transcript-path> <cwd> [<task>]
open_fork_window() {
    local session_id="${1}"
    local transcript_path="${2}"
    local cwd="${3}"
    local task="${4:-}"
    local start_dir
    local git_common_dir
    local command_line
    local error

    if [ "${TERM_PROGRAM:-}" != "ghostty" ]; then
        printf '%s' "fork opens its window through Ghostty's AppleScript, so it only works under Ghostty (TERM_PROGRAM is '${TERM_PROGRAM:-unset}')."
        return 1
    fi

    # Resolve the main checkout through the shared git dir, which every worktree points at.
    start_dir="${cwd}"
    if git_common_dir=$(git -C "${cwd}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
        start_dir=$(dirname -- "${git_common_dir}")
    fi

    command_line="CLAUDE_FORKED_FROM=$(printf '%q' "${session_id}")"
    command_line+=" CLAUDE_FORKED_TRANSCRIPT=$(printf '%q' "${transcript_path}")"
    # Launch through `claude_run` rather than `claude`, so the window minimizes and
    # closes once the fork's session ends, the same as `cl`.
    command_line+=" claude_run"
    if [ -n "${task}" ]; then
        command_line+=" $(printf '%q' "${task}")"
    fi

    # Pass both strings as arguments, so nothing in the task needs AppleScript escaping.
    if ! error=$(
        osascript - "${start_dir}" "${command_line}"$'\n' 2>&1 <<'APPLESCRIPT'
on run argv
    tell application "Ghostty"
        new window with configuration {initial working directory:item 1 of argv, initial input:item 2 of argv}
    end tell
end run
APPLESCRIPT
    ); then
        printf '%s' "fork couldn't open a Ghostty window: ${error}"
        return 1
    fi

    printf '%s' "${start_dir}"
}
