#!/usr/bin/env bash
#
# SessionStart hook: create the session-scoped tmp dir and tell the model to
# write temporary files there instead of /tmp directly. The dir name abbreviates
# the session id git-short style (see claude_session_dir.inc.sh).

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/claude_session_dir.inc.sh"

session_id=$(command jq --raw-output '.session_id // empty')
dir=$(claude_session_dir "${session_id}")
if [ -z "${dir}" ]; then
    exit 0
fi

mkdir -p "${dir}"

# Link the harness scratchpad inside the session dir so `!o` reaches both. Match
# the full id; the project segment changes in a worktree. Layout is undocumented.
shopt -s nullglob
scratchpads=("/private/tmp/claude-$(id -u)"/*/"${session_id}"/scratchpad)
if [ "${#scratchpads[@]}" -eq 1 ]; then
    ln -sfn "${scratchpads[0]}" "${dir}/scratchpad"
fi

command jq -nc --arg dir "${dir}" \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:("Session-scoped tmp directory: "+$dir+" \u2014 use this for any temporary files instead of /tmp directly.")}}'
