#!/usr/bin/env bash
# PreToolUse hook: deny a flag whose spelling doesn't match the build of the
# tool it's handed to, where it would abort with "illegal option" or "invalid
# option". This machine mixes builds, so the mistake runs both ways: a GNU long
# flag reaching the BSD awk, sed, or xargs, and a BSD-only short flag reaching
# the GNU date or stat that Homebrew's coreutils puts on PATH. The build itself
# decides, so each check stops firing once the other build takes over.

set -u

cmd=$(command jq --raw-output '.tool_input.command')

# Match a long flag sitting in the option block right after a candidate command,
# so a `--` inside a later script or pattern argument doesn't trip the hook.
gnu_long_flag_after_bsd_tool='(^|[[:space:]|;&(])(awk|sed|xargs)([[:space:]]+-[[:alnum:]]+)*[[:space:]]+--[[:alpha:]]'

# Match a BSD-only short flag the same way, bundled cluster (date -jf) included.
# `-j` and `-v` have no GNU counterpart at all; `-f` exists in both stat builds
# but means "format" only on BSD, so key it on the `%` format string after it.
bsd_only_flag_after_date='(^|[[:space:]|;&(])date([[:space:]]+-[[:alnum:]]+)*[[:space:]]+-[[:alnum:]]*[jv]'
bsd_only_flag_after_stat='(^|[[:space:]|;&(])stat([[:space:]]+-[[:alnum:]]+)*[[:space:]]+-[[:alnum:]]*f[[:space:]]+.?%'

# Report whether the command holds the given pattern.
command_matches() {
    local pattern="$1"

    printf '%s' "${cmd}" |
        command grep --quiet --extended-regexp -- "${pattern}"
}

# Name which candidate took the long flag, so the probe reads that build rather
# than the whole set.
matched_bsd_tool() {
    printf '%s' "${cmd}" |
        command grep --extended-regexp --only-matching -- "${gnu_long_flag_after_bsd_tool}" |
        command head --lines=1 |
        command grep --extended-regexp --only-matching -- 'awk|sed|xargs'
}

tool=""
if command_matches "${gnu_long_flag_after_bsd_tool}"; then
    tool=$(matched_bsd_tool)
    flag_build="GNU"
    guidance=$'It has no long options at all and would abort with "illegal option -- -". Rewrite using short flags (sed -n \'14,35p\', not sed --quiet \'14,35p\'); check the manual page for the short spelling.\n'
    guidance+=$'\nTo print a line range out of a file, skip the shell entirely and call Read with offset/limit.'
elif command_matches "${bsd_only_flag_after_date}"; then
    tool="date"
    flag_build="BSD"
    guidance='Use the GNU spelling: date --date="2026-06-30" "+%A %b %e", not date -j -f "%Y-%m-%d" 2026-06-30.'
elif command_matches "${bsd_only_flag_after_stat}"; then
    tool="stat"
    flag_build="BSD"
    guidance='Use the GNU spelling: stat --format="%s" file, not stat -f "%z" file.'
fi

if [[ -z "${tool}" ]]; then
    exit 0
fi

# Read the build off its own banner. The GNU ones name themselves; the BSD ones
# answer --version with their own text or reject the flag outright.
installed_build() {
    if command "${tool}" --version </dev/null 2>&1 | command grep --quiet -- 'GNU'; then
        printf 'GNU'
    else
        printf 'BSD'
    fi
}

actual_build=$(installed_build)
if [[ "${actual_build}" == "${flag_build}" ]]; then
    exit 0
fi

reason="The ${tool} on this machine is the ${actual_build} build, not the ${flag_build} one that flag spelling comes from."$'\n'
reason+=$'\n'"${guidance}"$'\n'
reason+=$'\nThis machine mixes builds (GNU date, readlink, stat; BSD awk, sed, xargs), so check `<tool> --version` before reaching for a platform-specific flag.'

command jq --null-input --compact-output \
    --arg reason "${reason}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
