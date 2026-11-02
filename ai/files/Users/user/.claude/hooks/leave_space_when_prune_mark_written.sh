#!/usr/bin/env bash
#
# PostToolUse hook: leave the full-screen Space the moment the model writes this
# session's prune mark, rather than once its reply ends, so the window drops out
# of view while the recap still renders. exit_session_when_marked_for_prune.sh
# closes the session after the reply.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/exit_session.inc.sh"

# Read every field in one jq call, since the hook runs on every Write.
{
    IFS= read -r -d '' session_id
    IFS= read -r -d '' file_path
} < <(
    command jq \
        --raw-output0 \
        '.session_id // "", .tool_input.file_path // ""'
)

if [[ -z "${session_id}" ]]; then
    exit 0
elif [[ "${file_path}" != "${prune_marks_dir}/${session_id}" ]]; then
    exit 0
fi

# Pass no claude pid, since this hook never looks one up; the hop walks for it.
leave_full_screen_space "${session_id}" ""
