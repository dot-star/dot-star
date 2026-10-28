# Open a Ghostty or Terminal.app window running a clean `claude_run` forked from another
# session. Source this; don't execute it. The window gets the parent's session
# id, transcript path and SendMessage address in its environment, where
# announce_fork_parent.sh picks them up at SessionStart.
#
# The window opens in the main checkout, even from a worktree, so the fork never
# shares the parent's worktree; it makes its own. A window rather than a tab
# keeps the fork's separate objective out of the parent's tab bar.

# Echo the SendMessage address of the `claude` process running this hook; return 1 when none is found.
# Each session listens on /tmp/cc-socks/<its claude pid>.sock, and SendMessage takes that path as `uds:<path>`.
claude_session_address() {
    local pid="${PPID}"
    local command_name
    local socket

    while [ -n "${pid}" ] && [ "${pid}" -gt 1 ]; do
        command_name=$(ps -o comm= -p "${pid}")
        if [ "${command_name##*/}" != "claude" ]; then
            pid=$(ps -o ppid= -p "${pid}" | tr -d ' ')
            continue
        fi

        socket="/tmp/cc-socks/${pid}.sock"
        if [ ! -S "${socket}" ]; then
            return 1
        fi
        printf '%s' "uds:${socket}"
        return 0
    done
    return 1
}

# Echo the argument single-quoted for the shell, every byte passed through as is.
# Replaces `printf '%q'`, whose macOS bash 3.2 build splits a multibyte character (`⌥`) into invalid UTF-8.
shell_quote() {
    local quote="'"
    local escaped_quote="'\\''"

    printf '%s' "'${1//${quote}/${escaped_quote}}'"
}

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
    local parent_address
    local error

    # Resolve the main checkout through the shared git dir, which every worktree points at.
    start_dir="${cwd}"
    if git_common_dir=$(git -C "${cwd}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
        start_dir=$(dirname -- "${git_common_dir}")
    fi

    command_line="CLAUDE_FORKED_FROM=$(shell_quote "${session_id}")"
    command_line+=" CLAUDE_FORKED_TRANSCRIPT=$(shell_quote "${transcript_path}")"
    if parent_address=$(claude_session_address); then
        command_line+=" CLAUDE_FORKED_FROM_ADDRESS=$(shell_quote "${parent_address}")"
    fi
    # Launch through `claude_run` rather than `claude`, so the window minimizes and
    # closes once the fork's session ends, the same as `cl`.
    command_line+=" claude_run"
    if [ -n "${task}" ]; then
        command_line+=" $(shell_quote "${task}")"
    fi

    # Pass every string as an argument, so nothing in the task needs AppleScript escaping.
    if [ "${TERM_PROGRAM:-}" = "ghostty" ]; then
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
    elif [ "${TERM_PROGRAM:-}" = "Apple_Terminal" ]; then
        # Change directory in the command itself, since `do script` has no working-directory option.
        if ! error=$(
            osascript - "cd -- $(shell_quote "${start_dir}") && ${command_line}" 2>&1 <<'APPLESCRIPT'
on run argv
    tell application "Terminal"
        do script (item 1 of argv)
        activate
    end tell
end run
APPLESCRIPT
        ); then
            printf '%s' "fork couldn't open a Terminal.app window: ${error}"
            return 1
        fi
    else
        printf '%s' "fork opens its window through AppleScript, so it only works under Ghostty or Terminal.app (TERM_PROGRAM is '${TERM_PROGRAM:-unset}')."
        return 1
    fi

    printf '%s' "${start_dir}"
}
