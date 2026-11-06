#!/usr/bin/env bash
# Notification hook: chime when Claude Code is blocked on the user (permission
# prompt, idle wait), so a tabbed-away user comes back to answer it.

set -u

"${HOME}/.claude/hooks/play_chime_unless_recent.py" "Glass"
