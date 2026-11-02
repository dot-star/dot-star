#!/usr/bin/env bash
#
# PostToolUse hook: leave the full-screen Space the moment the model writes this
# session's prune mark, rather than once its reply ends, so the window drops out
# of view while the recap still renders. exit_session_when_marked_for_prune.sh
# closes the session after the reply.

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/exit_session.inc.sh"

input=$(cat)
session_id=$(command jq --raw-output '.session_id // empty' <<<"${input}")
file_path=$(command jq --raw-output '.tool_input.file_path // empty' <<<"${input}")

if [[ -z "${session_id}" ]]; then
    exit 0
elif [[ "${file_path}" != "${prune_marks_dir}/${session_id}" ]]; then
    exit 0
fi

leave_full_screen_space
