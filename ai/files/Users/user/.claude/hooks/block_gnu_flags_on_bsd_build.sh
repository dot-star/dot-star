#!/usr/bin/env bash
# PreToolUse hook: deny a GNU-style long flag handed to a tool whose installed
# build has no long options (stock macOS ships BSD awk, sed, and xargs), where
# it would only abort with "illegal option -- -". The candidate list is a cheap
# pre-filter; the build itself decides, so the hook stops firing once a GNU
# replacement lands on PATH.

set -u

cmd=$(command jq --raw-output '.tool_input.command')

# Match a long flag sitting in the option block right after a candidate command,
# so a `--` inside a later script or pattern argument doesn't trip the hook.
long_flag_after_candidate='(^|[[:space:]|;&(])(awk|sed|xargs)([[:space:]]+-[[:alnum:]]+)*[[:space:]]+--[[:alpha:]]'

match=$(printf '%s' "${cmd}" |
    command grep --extended-regexp --only-matching -- "${long_flag_after_candidate}" |
    command head --lines=1)

if [[ -z "${match}" ]]; then
    exit 0
fi

# Recover which candidate matched, to probe that build rather than the whole set.
tool=$(printf '%s' "${match}" |
    command grep --extended-regexp --only-matching -- '(awk|sed|xargs)' |
    command head --lines=1)

# Read a GNU build as long-flag capable. The BSD ones never print "GNU": they
# answer --version with their own banner or reject the flag outright.
supports_long_flags() {
    command "${tool}" --version </dev/null 2>&1 |
        command grep --quiet -- 'GNU'
}

if supports_long_flags; then
    exit 0
fi

reason="The ${tool} on this machine is the BSD build, which has no long options at all."$'\n'
reason+=$'\nIt would abort with "illegal option -- -". Rewrite using short flags (sed -n \'14,35p\', not sed --quiet \'14,35p\'); check the manual page for the short spelling.\n'
reason+=$'\nTo print a line range out of a file, skip the shell entirely and call Read with offset/limit.'

command jq --null-input --compact-output \
    --arg reason "${reason}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
