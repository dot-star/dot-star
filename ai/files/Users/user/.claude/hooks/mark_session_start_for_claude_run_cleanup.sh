#!/usr/bin/env bash
#
# SessionStart hook: touch the marker claude_run exports, so claude_run closes
# its window only after a session actually ran. A picker that exits without
# starting one leaves the marker absent and its message on screen.

set -euo pipefail

if [[ -z "${CLAUDE_RUN_STARTED_MARKER:-}" ]]; then
    exit 0
fi

touch -- "${CLAUDE_RUN_STARTED_MARKER}"
