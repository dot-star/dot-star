#!/usr/bin/env bash

# Have Hammerspoon follow a finished claude session's full-screen Space, once
# the window closes, to the next session showing the green check (else the next
# full-screen app) rather than the desktop macOS falls back to, so the next
# terminal waiting on input lands in view.
#
# Usage:
#   follow_closed_full_screen_space.sh on-close [<session_id>]  # hop once the Space goes away
#   follow_closed_full_screen_space.sh now [<session_id>]       # hop now, for a window sure to close
#
# Returns at once either way; after `on-close`, Hammerspoon waits for the Space to go
# away. Acts only when the focused window belongs to the terminal app this shell
# runs in, sits in a full-screen Space and holds no other tabs (closing one of
# several tabs leaves the Space open, so the terminal shows the next tab itself).
#
# Pass the closing claude session's id to also require that the focused window is
# still the one that session recorded at SessionStart, so a session closing after
# you moved on to another window leaves you there. Without one, the focused window
# counts as the closing one.
#
# Skips silently where it can't apply (no Hammerspoon installed, no terminal app
# to match). Fails loudly when Hammerspoon is installed but can't run the hop,
# since that is a missing `hs.ipc`, a stopped app or a missing bootstrap block.
#
# Logs every skip and hop, this script's and Hammerspoon's, to one file, each
# tagged with the script that asked and the claude session above it:
#   tail -f /tmp/claude-state-hook/follow_closed_full_screen_space.log

set -euo pipefail

mode="$1"
session_id="${2:-}"
if [[ "${mode}" == "on-close" ]]; then
    lua_function="onClose"
elif [[ "${mode}" == "now" ]]; then
    lua_function="now"
else
    echo "Usage: $(basename "$0") on-close|now [<session_id>]" >&2
    exit 2
fi

# Print the name of the script that ran this one: the script an interpreter
# runs (`bash <hook>.sh`), else the program itself (`zsh` for a bare-shell `x`).
caller_name() {
    local words
    local program

    read -r -a words <<<"$(ps -o command= -p "${PPID}")"
    program="${words[0]##*/}"
    program="${program#-}"

    if [[ "${#words[@]}" -lt 2 ]]; then
        echo "${program}"
    elif [[ "${words[1]}" == "-"* ]]; then
        echo "${program}"
    elif [[ "${program}" == "bash" || "${program}" == "sh" || "${program}" == "zsh" || "${program}" == python* ]]; then
        echo "${words[1]##*/}"
    else
        echo "${program}"
    fi
}

# Print the pid of the nearest `claude` above this script, or nothing, from one
# `ps` snapshot so the tag adds no walk of separate calls.
claude_ancestor_pid() {
    ps -A -o pid=,ppid=,comm= |
        awk -v start="${PPID}" '
            {
                command = $0
                sub(/^ *[0-9]+ +[0-9]+ +/, "", command)
                sub(/.*\//, "", command)
                parent[$1] = $2
                name[$1] = command
            }
            END {
                pid = start
                while (pid > 1) {
                    if (name[pid] == "claude") {
                        print pid
                        exit
                    }
                    pid = parent[pid]
                }
            }
        '
}

caller="caller: $(caller_name)"
claude_pid=$(claude_ancestor_pid)
if [[ -n "${claude_pid}" ]]; then
    caller+=", claude ${claude_pid}"
fi

# Keep the tag to characters that can't break out of the Lua string below.
caller="${caller//[^A-Za-z0-9_.,: -]/}"

hammerspoon_cli="/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"
log_dir="/tmp/claude-state-hook"

# Append a timestamped line to the log the Hammerspoon module writes too.
log() {
    mkdir -p -- "${log_dir}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >>"${log_dir}/follow_closed_full_screen_space.log"
}

if [[ "${OSTYPE}" != "darwin"* ]]; then
    exit 0
elif [[ ! -x "${hammerspoon_cli}" ]]; then
    log "${mode} [${caller}]: skipped: no Hammerspoon client at ${hammerspoon_cli}"
    exit 0
fi

# Read the terminal's bundle id off the variable macOS hands every process an
# app launches, so a window of some other app is never followed.
terminal_bundle_id="${__CFBundleIdentifier:-}"

if [[ -z "${terminal_bundle_id}" ]]; then
    log "${mode} [${caller}]: skipped: no __CFBundleIdentifier to name the terminal app"
    exit 0
fi

# Read the closing session's window id off the record announce_window_state.py
# writes at SessionStart (`<window id> <bundle id>`); pass Lua `nil` when there's
# none, so the focused window counts as the closing one.
closing_window_id="nil"
if [[ -z "${session_id}" ]]; then
    # Leave it nil for a caller with no session, such as `x` in a bare shell.
    :
elif [[ ! -f "${log_dir}/${session_id}.window" ]]; then
    log "${mode} [${caller}]: no window recorded for session ${session_id}"
else
    read -r recorded_window_id _ <"${log_dir}/${session_id}.window" || true
    if [[ "${recorded_window_id:-}" =~ ^[0-9]+$ ]]; then
        closing_window_id="${recorded_window_id}"
    else
        log "${mode} [${caller}]: no window id in the record for session ${session_id}"
    fi
fi

# Load the module on demand, so a Hammerspoon still running a config from before the module shipped can run it anyway.
if ! "${hammerspoon_cli}" -c "require('follow_closed_full_screen_space'); return followClosedFullScreenSpace.${lua_function}('${terminal_bundle_id}', ${closing_window_id}, '${caller}')" >/dev/null; then
    log "${mode} ${terminal_bundle_id} [${caller}]: failed: Hammerspoon couldn't run the hop"
    echo "Couldn't run the full-screen follow through Hammerspoon. Check it's running with the dot-star bootstrap block and require('hs.ipc') in ~/.hammerspoon/init.lua (./install.sh adds both), then reload its config." >&2
    exit 1
fi
