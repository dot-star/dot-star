#!/usr/bin/env bash
#
# SessionStart hook: write the session id into the marker claude_run exports,
# so claude_run closes its window only after a session actually ran and can
# name that session's window to the full-screen follow. A picker that exits
# without starting one leaves the marker absent and its message on screen.

set -euo pipefail

if [[ -z "${CLAUDE_RUN_STARTED_MARKER:-}" ]]; then
    exit 0
fi

command jq --raw-output '.session_id // empty' >"${CLAUDE_RUN_STARTED_MARKER}"
