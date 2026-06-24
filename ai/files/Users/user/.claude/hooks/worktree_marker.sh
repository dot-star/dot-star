#!/usr/bin/env bash
#
# Hook for EnterWorktree / ExitWorktree (PostToolUse) and SessionStart:
# maintain a session-scoped marker file recording the worktree the session is
# currently working in. statusline.sh reads this file to render
# "[<worktree-name>]".
#
# Also emits an OSC 7 escape to the parent claude's TTY so Terminal.app's
# "new tab inherits cwd" tracking follows where the session is working. While
# Claude Code owns the TTY the shell's precmd never fires, so Terminal.app's
# tracked cwd would otherwise stay frozen at whatever PWD was when claude
# launched. Point it at the worktree while one is active, else at the session
# tmp dir (/tmp/claude/<session_id>) so a worktree-less session opens new tabs
# there rather than the launch dir.

set -euo pipefail

# Percent-encode a path byte-by-byte, preserving only the unreserved set
# (plus '/'). Matches Apple's update_terminal_cwd in /etc/zshrc_Apple_Terminal.
encode_path() {
    local path="$1"
    local out=''
    local ch val hex i
    local LC_CTYPE=C LC_COLLATE=C LC_ALL= LANG=

    # Walk the path one byte at a time; LC_CTYPE=C above forces byte indexing.
    for ((i = 0; i < ${#path}; i++)); do
        ch="${path:i:1}"
        case "${ch}" in
        [/._~A-Za-z0-9-])
            out+="${ch}"
            ;;
        *)
            # Bash sign-extends "'<byte>" for bytes > 127; mask to 0xFF.
            printf -v val '%d' "'${ch}"
            printf -v hex '%02X' "$((val & 0xFF))"
            out+="%${hex}"
            ;;
        esac
    done

    # Return the encoded path on stdout.
    printf '%s' "${out}"
}

# Find the TTY of the nearest ancestor process that has one. The hook
# subprocess itself has no controlling TTY (Claude Code pipes stdin/stdout),
# so /dev/tty fails; the parent claude process is what's attached to the
# terminal.
ancestor_tty() {
    local pid=$$
    local tty

    # Walk up the process tree until we find an ancestor with a TTY.
    while [ "${pid}" -gt 1 ]; do
        # ps prints "??" for processes with no controlling terminal.
        tty="$(ps -o tty= -p "${pid}" 2>/dev/null |
            tr -d ' ')"
        if [ -n "${tty}" ] && [ "${tty}" != "??" ]; then
            printf '/dev/%s' "${tty}"
            return 0
        fi

        # Step to the parent and keep looking.
        pid="$(ps -o ppid= -p "${pid}" 2>/dev/null |
            tr -d ' ')"
        if [ -z "${pid}" ]; then
            break
        fi
    done

    # Reached pid 1 or a missing parent without finding a TTY.
    return 1
}

# Emit an OSC 7 "file://host/path" escape so the terminal records `path` as
# its tracked cwd. No-op when no ancestor TTY is found or it isn't writable
# (e.g. piped session, restricted permissions).
emit_osc7() {
    local path="$1"
    local tty_path
    local encoded

    # Match the host zsh's precmd emits. Apple's update_terminal_cwd writes
    # file://$HOST/path, and Terminal.app only honors an OSC 7 whose host equals
    # the local machine; otherwise it ignores it and a new tab falls back to the
    # last accepted cwd (the launch dir, i.e. the root checkout). HOST/HOSTNAME
    # aren't exported into the hook's environment, so read it from `hostname`.
    local host
    host="$(hostname 2>/dev/null)"
    host="${host:-${HOST:-${HOSTNAME:-localhost}}}"

    # Resolve the TTY we'll write the escape to, and bail if it's not usable.
    tty_path="$(ancestor_tty)" || return
    if [ ! -w "${tty_path}" ]; then
        return
    fi

    # Encode the path per RFC 3986, then write the OSC 7 sequence.
    encoded="$(encode_path "${path}")"
    printf '\e]7;file://%s%s\a' "${host}" "${encoded}" >"${tty_path}"
}

data=$(cat)

sid=$(printf '%s' "${data}" |
    command jq --raw-output '.session_id // empty')
sid="${sid//[^a-zA-Z0-9-]/}"
if [ -z "${sid}" ]; then
    exit 0
fi

dir="/tmp/claude/${sid}"
marker="${dir}/worktree"

event=$(printf '%s' "${data}" |
    command jq --raw-output '.hook_event_name // empty')
tool=$(printf '%s' "${data}" |
    command jq --raw-output '.tool_name // empty')
case "${tool:-${event}}" in
EnterWorktree)
    # Extract the new worktree path from the tool response text
    # ("Created worktree at <path> on branch ..." or "Switched ...").
    response=$(printf '%s' "${data}" |
        command jq --raw-output '.tool_response | tostring')
    path=$(printf '%s' "${response}" |
        grep --only-matching --extended-regexp '/[A-Za-z0-9_./-]+/worktrees/[A-Za-z0-9_.-]+' |
        head -n 1)
    if [ -n "${path}" ] && [ -d "${path}" ]; then
        mkdir -p "${dir}"
        printf '%s\n' "${path}" >"${marker}"
        emit_osc7 "${path}"
    fi
    ;;
ExitWorktree)
    # Drop the marker; we're no longer in a worktree.
    if [ -f "${marker}" ]; then
        rm "${marker}"
    fi

    # Point new tabs at the session tmp dir now that no worktree is active.
    emit_osc7 "${dir}"
    ;;
SessionStart)
    # Follow a worktree marker that survived a resume; nothing else to resolve.
    if [ -f "${marker}" ]; then
        emit_osc7 "$(cat "${marker}")"
        exit 0
    fi

    cwd=$(printf '%s' "${data}" |
        command jq --raw-output '.cwd // .workspace.current_dir // empty')

    # Detect a worktree the session launched inside (created outside the
    # EnterWorktree tool, so no marker) the way statusline.sh does: a worktree's
    # git dir lives under <repo>/.git/worktrees/<name>.
    worktree_root=""
    if [ -n "${cwd}" ]; then
        gitdir=$(cd "${cwd}" 2>/dev/null && git rev-parse --absolute-git-dir 2>/dev/null || true)
        case "${gitdir}" in
        */worktrees/*)
            worktree_root=$(cd "${cwd}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)
            ;;
        esac
    fi

    # Point new tabs at that worktree if one is active, else at the session tmp
    # dir so a worktree-less session lands there rather than the launch dir.
    if [ -n "${worktree_root}" ]; then
        emit_osc7 "${worktree_root}"
    else
        mkdir -p "${dir}"
        emit_osc7 "${dir}"
    fi
    ;;
esac
