#!/usr/bin/env bash

# Minimize the terminal window a finished claude session ran in, so the
# cleanup that follows runs out of the way until the shell exits and closes it.
#
# Acts on the focused window, since the user just typed /exit there, and only
# when that window belongs to the terminal app this shell runs in. A window
# holding other tabs gets this tab moved into a window of its own first, so the
# minimize leaves the sibling tabs on screen.
#
# Skips silently where minimizing can't apply (no Hammerspoon installed, no
# terminal app to match). Fails loudly when Hammerspoon is installed but its
# client can't reach it, since that is a missing `hs.ipc` or a stopped app.

set -euo pipefail

hammerspoon_cli="/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"

if [[ "${OSTYPE}" != "darwin"* || ! -x "${hammerspoon_cli}" ]]; then
    exit 0
fi

# Read the terminal's bundle id off the variable macOS hands every process an
# app launches, so a window of some other app is never touched.
terminal_bundle_id="${__CFBundleIdentifier:-}"

if [[ -z "${terminal_bundle_id}" ]]; then
    exit 0
fi

if ! "${hammerspoon_cli}" -c "
local window = hs.window.focusedWindow()
if window == nil or window:application():bundleID() ~= '${terminal_bundle_id}' then
    return
end
if (window:tabCount() or 0) > 1 then
    window:application():selectMenuItem({'Window', 'Move Tab to New Window'})
    window = hs.window.focusedWindow()
end
if window ~= nil then
    window:minimize()
end
" >/dev/null; then
    echo "Couldn't minimize through Hammerspoon. Check it's running with require('hs.ipc') in ~/.hammerspoon/init.lua (./install.sh adds it), then reload its config." >&2
    exit 1
fi
