#!/usr/bin/env bash
#
# SessionStart hook: warn when a personal context doc isn't banked in its own
# repo. ai/contexts/private-* are gitignored symlinks, so a dangling link, an
# untracked target, or an edited target never shows in this repo's
# `git status` and is easy to lose. Print the report on stdout and exit 0, so
# it lands in the session's context and Claude raises it; stay silent when
# every link resolves to a tracked, clean file.

set -euo pipefail

contexts_dir="${CLAUDE_CONTEXTS_DIR:-${HOME}/.dot-star/ai/contexts}"

# Describe one link's problem, or print nothing when it is banked and clean.
personal_context_problem() {
    local link="$1"
    local target
    local target_dir
    local status

    target="$(readlink -- "${link}" || true)"
    if [ -z "${target}" ]; then
        # Skip a regular file; it is tracked or ignored by this repo's own rules.
        return 0
    elif [ ! -e "${target}" ]; then
        echo "dangling: ${link} -> ${target}"
        return 0
    fi

    target_dir="$(dirname -- "${target}")"
    if ! git -C "${target_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "outside any git repo: ${target}"
    elif ! git -C "${target_dir}" ls-files --error-unmatch -- "${target}" >/dev/null 2>&1; then
        echo "untracked: ${target}"
    else
        status="$(git -C "${target_dir}" status --porcelain -- "${target}")"
        if [ -n "${status}" ]; then
            echo "uncommitted edits: ${target}"
        fi
    fi
}

report=""
for link in "${contexts_dir}"/private-*; do
    if [ ! -e "${link}" ] && [ ! -L "${link}" ]; then
        # Skip the literal glob when the directory holds no private-* entries.
        continue
    fi

    problem="$(personal_context_problem "${link}")"
    if [ -n "${problem}" ]; then
        report+="${problem}"$'\n'
    fi
done

if [ -z "${report}" ]; then
    exit 0
fi

printf '🔴 Personal context docs not banked in their repo (dot-star ignores the symlinks, so only that repo shows them):\n%s' "${report}"
