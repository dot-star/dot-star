#!/usr/bin/env bash

# Open a Ghostty window running a Claude session that investigates a problem,
# then hand focus back to the window that was in front.
#
# Usage:
#   open_investigation_window.sh <key> <objective> <task>
#
# <key> names the problem for the cooldown, so one burst of the same failure
# opens one window. Exits 0 when the window is opening, 1 when skipped.

set -euo pipefail

key="${1}"
objective="${2}"
task="${3}"
stamp_file="${XDG_CACHE_HOME:-${HOME}/.cache}/dot-star/investigations/${key}"

# Skip inside Claude's own shells and inside an investigation window, which may hit the same problem itself.
if [[ "${TERM_PROGRAM:-}" != "ghostty" ]] || [[ -n "${CLAUDECODE:-}" ]] || [[ -n "${CLAUDE_INVESTIGATING:-}" ]]; then
    exit 1
fi

# Open one window per burst; Ghostty restoring several windows at launch would otherwise open one each.
if [[ -n "$(find "${stamp_file}" -mmin -10 2>/dev/null)" ]]; then
    exit 1
fi

mkdir -p "${stamp_file%/*}"
: >|"${stamp_file}"

printf -v command_line 'claude_run --obj %q %q' "${objective}" "${task}"

# Run in the background so the AppleScript round trip doesn't hold up the caller.
osascript - "${HOME}/.dot-star" "${command_line}"$'\n' >/dev/null 2>&1 <<'APPLESCRIPT' &
on run argv
    tell application "Ghostty"
        set original_window to front window
        new window with configuration {initial working directory:item 1 of argv, initial input:item 2 of argv, environment variables:{"CLAUDE_INVESTIGATING=1"}}
        activate window original_window
    end tell
end run
APPLESCRIPT
