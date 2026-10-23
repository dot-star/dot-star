#!/usr/bin/env bash

# Have Hammerspoon follow a finished claude session's full-screen Space, once
# the window closes, to the next full-screen app rather than the desktop macOS
# falls back to, so the next terminal waiting on input lands in view.
#
# Arms the hop and returns at once; Hammerspoon waits for the Space to go away.
# Acts only when the focused window belongs to the terminal app this shell runs
# in and sits in a full-screen Space.
#
# Skips silently where it can't apply (no Hammerspoon installed, no terminal app
# to match). Fails loudly when Hammerspoon is installed but can't run the hop,
# since that is a missing `hs.ipc`, a stopped app or a missing bootstrap block.

set -euo pipefail

hammerspoon_cli="/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"

if [[ "${OSTYPE}" != "darwin"* || ! -x "${hammerspoon_cli}" ]]; then
    exit 0
fi

# Read the terminal's bundle id off the variable macOS hands every process an
# app launches, so a window of some other app is never followed.
terminal_bundle_id="${__CFBundleIdentifier:-}"

if [[ -z "${terminal_bundle_id}" ]]; then
    exit 0
fi

# Load the module on demand, so a Hammerspoon still running a config from before the module shipped can arm it anyway.
if ! "${hammerspoon_cli}" -c "require('follow_closed_full_screen_space'); return followClosedFullScreenSpace.arm('${terminal_bundle_id}')" >/dev/null; then
    echo "Couldn't arm the full-screen follow through Hammerspoon. Check it's running with the dot-star bootstrap block and require('hs.ipc') in ~/.hammerspoon/init.lua (./install.sh adds both), then reload its config." >&2
    exit 1
fi
