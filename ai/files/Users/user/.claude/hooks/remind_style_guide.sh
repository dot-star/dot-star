#!/usr/bin/env bash
# PreToolUse hook: surface the on-demand style guide for the file being written.
# Map the target path to the matching ~/.claude/styles/ guide and inject it as
# context so code lands in the user's style while it is written, not on request.
# Ask for a trim pass on docs loaded into context.
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
context_docs=()
trim_reminder=""

# Point at the language-agnostic code rules on any edit that isn't prose.
case "${file_path}" in
*.md | *.txt)
    # Skip prose; CLAUDE.md's Writing style already covers it every session.
    :
    ;;
*)
    context_docs+=("code-style.md")
    ;;
esac

# Point at the banking rules on a todo file, where banked entries get written.
case "${file_path}" in
todo.md | */todo.md | TODO.md | */TODO.md)
    context_docs+=("todo-banking.md")
    ;;
esac

# Ask for a trim pass on docs loaded into context, where every word costs every session.
case "${file_path}" in
CLAUDE.md | */CLAUDE.md | */CLAUDE_*.md | */ai/contexts/*.md | */.claude/projects/*/memory/*.md | */skills/*/SKILL.md)
    trim_reminder="After this edit lands, re-read what it added to ${file_path} and trim it: cut every word whose loss keeps the meaning. Keep a reason or edge case only when a reader with the instruction alone would break or misapply it."
    ;;
esac

# Map by content type so the right guide is in context as the code is written.
case "${file_path}" in
*.py)
    guides+=("python-docstring-style.md")
    guides+=("python-typing-style.md")
    ;;
*.sh | *.bash | *.zsh | *.bashrc | *.zshrc | *.bash_profile | *.zprofile)
    guides+=("shell-style.md")
    ;;
esac

# Add the test guide on test files, on top of the docstring guide above.
case "${file_path}" in
*_test.py | */test_*.py)
    guides+=("python-test-style.md")
    ;;
esac

# Nudge the naming guide on Write; creating a file is when the name matters.
if [ "${tool_name}" = "Write" ]; then
    guides+=("file-naming-style.md")
fi

if [ "${#guides[@]}" -eq 0 ] && [ "${#context_docs[@]}" -eq 0 ] && [ -z "${trim_reminder}" ]; then
    exit 0
fi

reminder=""

if [ "${#guides[@]}" -gt 0 ] || [ "${#context_docs[@]}" -gt 0 ]; then
    reminder="Apply the user's style guide(s) to ${file_path} as you write it; read each now if not already read this session:"
fi

# Guard each loop; bash 3.2 under `set -u` treats an empty array as unbound.
if [ "${#context_docs[@]}" -gt 0 ]; then
    for context_doc in "${context_docs[@]}"; do
        reminder+=" ~/.dot-star/ai/contexts/${context_doc}"
    done
fi

if [ "${#guides[@]}" -gt 0 ]; then
    for guide in "${guides[@]}"; do
        reminder+=" ~/.claude/styles/${guide}"
    done
fi

if [ -n "${trim_reminder}" ] && [ -n "${reminder}" ]; then
    reminder+=" ${trim_reminder}"
elif [ -n "${trim_reminder}" ]; then
    reminder="${trim_reminder}"
fi

command jq --null-input --compact-output \
    --arg ctx "${reminder}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
