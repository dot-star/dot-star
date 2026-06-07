#!/usr/bin/env bash
# PreToolUse hook: surface the on-demand style guide for the file being written.
# Map the target path to the matching ~/.claude/styles/ guide and inject it as
# context so code lands in the user's style while it is written, not on request.
# Silent for paths with no matching guide.

set -u

# Slurp stdin once; a second `jq` reading the pipe would get an empty payload.
input=$(cat)

file_path=$(printf '%s' "${input}" |
    command jq --raw-output '.tool_input.file_path // empty')
if [ -z "${file_path}" ]; then
    exit 0
fi

tool_name=$(printf '%s' "${input}" |
    command jq --raw-output '.tool_name // empty')

guides=()

# Map by content type so the right guide is in context as the code is written.
case "${file_path}" in
*.py)
    guides+=("python-docstring-style.md")
    ;;
*.sh | *.bash | *.zsh | *.bashrc | *.zshrc | *.bash_profile | *.zprofile)
    guides+=("shell-style.md")
    ;;
esac

# Nudge the naming guide on Write; creating a file is when the name matters.
if [ "${tool_name}" = "Write" ]; then
    guides+=("file-naming-style.md")
fi

if [ "${#guides[@]}" -eq 0 ]; then
    exit 0
fi

reminder="Apply the user's style guide(s) to ${file_path} as you write it; read each now if not already read this session:"
for guide in "${guides[@]}"; do
    reminder+=" ~/.claude/styles/${guide}"
done

command jq --null-input --compact-output \
    --arg ctx "${reminder}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
