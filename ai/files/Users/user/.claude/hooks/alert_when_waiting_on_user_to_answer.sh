#!/usr/bin/env bash
# Notification hook: chime and ring the pane's bell when Claude Code is blocked
# on the user (permission prompt, idle wait), so a tabbed-away user comes back
# to answer it.

set -u

# Print the terminal device a process runs on, or nothing when it has none.
print_tty_of() {
    local pid="$1"
    local tty

    tty="$(
        ps \
            -o "tty=" \
            -p "${pid}" |
            tr -d " "
    )"
    if [[ -z "${tty}" ]]; then
        return
    elif [[ "${tty}" == "??" ]]; then
        # Skip macOS's marker for a process with no terminal.
        return
    elif [[ "${tty}" == "?" ]]; then
        # Skip Linux's marker for a process with no terminal.
        return
    fi
    echo "${tty}"
}

# Ring the bell in the pane Claude runs in, so the terminal flags that pane
# (Ghostty outlines it until focused). The hook has no terminal of its own, so
# borrow the nearest ancestor's.
ring_bell_in_claude_pane() {
    local pid="${PPID}"
    local tty

    while [[ "${pid}" -gt 1 ]]; do
        tty="$(print_tty_of "${pid}")"
        if [[ -n "${tty}" ]]; then
            printf '\a' >"/dev/${tty}"
            return
        fi
        pid="$(
            ps \
                -o "ppid=" \
                -p "${pid}" |
                tr -d " "
        )"
    done
}

ring_bell_in_claude_pane
"${HOME}/.claude/hooks/play_chime_unless_recent.py" "Glass"
