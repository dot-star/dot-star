#!/usr/bin/env bash
#
# UserPromptSubmit hook: run each hook that can block the prompt, then mark the
# session busy only when none of them blocked it. Claude Code runs a group's
# hooks in parallel, so a separate state hook would mark a blocked prompt busy,
# and with no turn to end, no Stop would ever mark it ready again.

set -euo pipefail

hooks_dir="$(dirname -- "${BASH_SOURCE[0]}")"

# List every UserPromptSubmit hook that can answer `decision: "block"`. Each
# prints a block decision or nothing, since only one JSON answer reaches Claude.
blocking_hooks=(
    "fork_session_on_prompt.sh"
)

payload=$(cat)

for hook in "${blocking_hooks[@]}"; do
    # Count a hook that crashed as not blocking, since the turn still runs.
    if ! answer=$(printf '%s' "${payload}" | "${hooks_dir}/${hook}"); then
        answer=""
    fi

    if [[ -n "${answer}" ]]; then
        printf '%s\n' "${answer}"
        exit 0
    fi
done

printf '%s' "${payload}" |
    "${hooks_dir}/announce_window_state.py" "UserPromptSubmit"
