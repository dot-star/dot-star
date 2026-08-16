#!/usr/bin/env bash
# PreToolUse hook: deny a BSD-only flag handed to a tool whose installed build
# is GNU (Homebrew's coreutils shadows the macOS date, stat, and readlink),
# where it would abort with "invalid option". Mirror of block_bsd_long_flags.sh,
# which catches the opposite mistake. The build itself decides, so the hook
# stops firing once a BSD build is back on PATH.

set -u

cmd=$(command jq --raw-output '.tool_input.command')

# Match a BSD-only flag sitting in the option block right after its command,
# bundled cluster (date -jf) included, so the same letter in a later argument
# doesn't trip the hook. `-j` and `-v` have no GNU counterpart at all; `-f`
# exists in both stat builds but means "format" only on BSD, so key it on the
# `%` format string that follows.
bsd_only_flag_after_date='(^|[[:space:]|;&(])date([[:space:]]+-[[:alnum:]]+)*[[:space:]]+-[[:alnum:]]*[jv]'
bsd_only_flag_after_stat='(^|[[:space:]|;&(])stat([[:space:]]+-[[:alnum:]]+)*[[:space:]]+-[[:alnum:]]*f[[:space:]]+.?%'

# Report whether the command holds the given pattern.
command_matches() {
    local pattern="$1"

    printf '%s' "${cmd}" |
        command grep --quiet --extended-regexp -- "${pattern}"
}

tool=""
if command_matches "${bsd_only_flag_after_date}"; then
    tool="date"
elif command_matches "${bsd_only_flag_after_stat}"; then
    tool="stat"
fi

if [[ -z "${tool}" ]]; then
    exit 0
fi

# Read a GNU build as rejecting the flag. The BSD ones answer --version with
# their own banner or reject the flag outright.
is_gnu_build() {
    command "${tool}" --version </dev/null 2>&1 |
        command grep --quiet -- 'GNU'
}

if ! is_gnu_build; then
    exit 0
fi

# Name the GNU spelling of whichever BSD invocation was attempted.
case "${tool}" in
date)
    replacement='date --date="2026-06-30" "+%A %b %e", not date -j -f "%Y-%m-%d" 2026-06-30'
    ;;
stat)
    replacement='stat --format="%s" file, not stat -f "%z" file'
    ;;
esac

reason="The ${tool} on this machine is the GNU build (Homebrew coreutils), not the BSD one that flag comes from."$'\n'
reason+=$'\nUse the GNU spelling: '"${replacement}"$'.\n'
reason+=$'\nThis machine mixes builds (GNU date, readlink, stat; BSD awk, sed, xargs), so check `<tool> --version` before reaching for a platform-specific flag.'

command jq --null-input --compact-output \
    --arg reason "${reason}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
