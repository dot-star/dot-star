#!/usr/bin/env bash
#
# SessionStart hook: create the session-scoped tmp dir and tell the model to
# write temporary files there instead of /tmp directly. The dir name abbreviates
# the session id git-short style (see claude_session_dir.inc.sh).

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/claude_session_dir.inc.sh"

dir=$(claude_session_dir "$(command jq --raw-output '.session_id // empty')")
if [ -z "${dir}" ]; then
    exit 0
fi

mkdir -p "${dir}"

command jq -nc --arg dir "${dir}" \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:("Session-scoped tmp directory: "+$dir+" \u2014 use this for any temporary files instead of /tmp directly.")}}'
