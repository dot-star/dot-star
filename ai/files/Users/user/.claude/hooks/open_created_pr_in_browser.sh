#!/usr/bin/env bash
# PostToolUse hook (Bash): open each PR that `gh pr create` just made in the
# browser, so the user lands on it without clicking the link in the reply.

set -u

payload=$(cat)
cmd=$(command jq --raw-output '.tool_input.command // empty' <<<"${payload}")
# Fire only for `gh pr create`; every other command passes through untouched.
case "${cmd}" in
*"gh pr create"*) ;;
*) exit 0 ;;
esac

# Skip `--web`, which already opens the browser on its own.
case "${cmd}" in
*--web*) exit 0 ;;
esac

# Take the URL gh prints on success; a failed create prints none, so nothing opens.
url=$(command jq --raw-output '[.tool_response // "" | tostring | scan("https://github\\.com/[^/\\s]+/[^/\\s]+/pull/[0-9]+")] | last // empty' <<<"${payload}")
if [[ -z "${url}" ]]; then
    exit 0
fi

open "${url}"

# Tell Claude the tab is open, so the reply carries the link without opening it twice.
message="Opened ${url} in the browser. Include the URL in the reply; don't open it again."
command jq \
    --null-input \
    --compact-output \
    --arg msg "${message}" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$msg}}'
