#!/usr/bin/env bash

# Minimize the terminal window a finished claude session ran in, so the
# cleanup that follows runs out of the way until the shell exits and closes it.
#
# Acts on the focused window, since the user just typed /exit there, and only
# when that window belongs to the terminal app this shell runs in. A window
# holding other tabs gets this tab moved into a window of its own first, so the
# minimize leaves the sibling tabs on screen.
#
# Fails soft: without Hammerspoon (and `hs.ipc` loaded in its config) nothing
# happens and the cleanup runs in the open as before.

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

"${hammerspoon_cli}" -c "
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
" >/dev/null 2>&1 ||
    true
