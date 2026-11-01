#!/usr/bin/env bash

# Have Hammerspoon follow a finished claude session's full-screen Space, once
# the window closes, to the next session showing the green check (else the next
# full-screen app) rather than the desktop macOS falls back to, so the next
# terminal waiting on input lands in view.
#
# Usage:
#   follow_closed_full_screen_space.sh on-close  # hop once the Space goes away
#   follow_closed_full_screen_space.sh now       # hop now, for a window sure to close
#
# Returns at once either way; after `on-close`, Hammerspoon waits for the Space to go
# away. Acts only when the focused window belongs to the terminal app this shell
# runs in and sits in a full-screen Space.
#
# Skips silently where it can't apply (no Hammerspoon installed, no terminal app
# to match). Fails loudly when Hammerspoon is installed but can't run the hop,
# since that is a missing `hs.ipc`, a stopped app or a missing bootstrap block.
#
# Logs every skip and hop, this script's and Hammerspoon's, to one file:
#   tail -f /tmp/claude-state-hook/follow_closed_full_screen_space.log

set -euo pipefail

mode="$1"
if [[ "${mode}" == "on-close" ]]; then
    lua_function="onClose"
elif [[ "${mode}" == "now" ]]; then
    lua_function="now"
else
    echo "Usage: $(basename "$0") on-close|now" >&2
    exit 2
fi

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
    log "${mode}: skipped: no Hammerspoon client at ${hammerspoon_cli}"
    exit 0
fi

# Read the terminal's bundle id off the variable macOS hands every process an
# app launches, so a window of some other app is never followed.
terminal_bundle_id="${__CFBundleIdentifier:-}"

if [[ -z "${terminal_bundle_id}" ]]; then
    log "${mode}: skipped: no __CFBundleIdentifier to name the terminal app"
    exit 0
fi

# Load the module on demand, so a Hammerspoon still running a config from before the module shipped can run it anyway.
if ! "${hammerspoon_cli}" -c "require('follow_closed_full_screen_space'); return followClosedFullScreenSpace.${lua_function}('${terminal_bundle_id}')" >/dev/null; then
    log "${mode} ${terminal_bundle_id}: failed: Hammerspoon couldn't run the hop"
    echo "Couldn't run the full-screen follow through Hammerspoon. Check it's running with the dot-star bootstrap block and require('hs.ipc') in ~/.hammerspoon/init.lua (./install.sh adds both), then reload its config." >&2
    exit 1
fi
