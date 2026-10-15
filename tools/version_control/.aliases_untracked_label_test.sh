#!/usr/bin/env bash
# Exercise the untracked-path labeling end to end: build a throwaway repo holding
# a staged edit and untracked files, render `git status` through the real filter
# and assert every untracked path starts in the same column as the staged one.
# Usage:
#   $ bash tools/version_control/.aliases_untracked_label_test.sh [<checkout to test>]

set -euo pipefail

# Default to the checkout this script lives in.
checkout="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
version_control_aliases="${checkout}/tools/version_control/.aliases.sh"

repo="$(command mktemp -d)"
trap 'rm -rf "${repo}"' EXIT

cd "${repo}"
git init \
    --quiet \
    --initial-branch=master \
    .

echo "before" >tracked.sh
git add -- tracked.sh
git \
    -c user.name="test" \
    -c user.email="test@example.com" \
    commit \
    --quiet \
    --message="sample:base"

echo "after" >tracked.sh
git add -- tracked.sh
mkdir nested
echo "new" >tracked_test.sh
echo "new" >"nested/with: colon.json"

# Render through the real function, stripping color so columns count as cells.
render() {
    local color="${1}"

    (
        source "${version_control_aliases}" 2>/dev/null
        git -c color.status="${color}" status --untracked-files=all |
            label_untracked_paths
    ) |
        sed $'s/\033\\[[0-9;]*m//g'
}

# Print the column each listed path starts in, one "<column> <path>" per line.
path_columns() {
    awk '
        /^\t/ {
            if (match($0, /^\t[a-z][a-z ]*:[ ]+/)) {
                print RLENGTH + 1, substr($0, RLENGTH + 1)
            }
        }
    '
}

failures=0

check_render() {
    local color="${1}"
    local output
    output="$(render "${color}")"

    echo "Rendered (color=${color}):"
    echo "${output}"
    echo

    local columns
    columns="$(echo "${output}" | path_columns)"

    local distinct
    distinct="$(echo "${columns}" | cut -d " " -f 1 | sort --unique | wc -l | tr -d " ")"

    local untracked_count
    untracked_count="$(echo "${output}" | grep --count $'^\tuntracked:' || true)"

    if [[ "${untracked_count}" -ne 2 ]]; then
        echo "✗ color=${color}: wanted 2 untracked labels, got ${untracked_count}"
        failures=$((failures + 1))
    elif [[ "${distinct}" -ne 1 ]]; then
        echo "✗ color=${color}: paths start in ${distinct} different columns"
        echo "${columns}"
        failures=$((failures + 1))
    else
        echo "✓ color=${color}: every path starts in one column"
    fi
    echo
}

check_render "always"
check_render "never"

if [[ "${failures}" -gt 0 ]]; then
    echo "${failures} check(s) failed"
    exit 1
fi

echo "All checks passed"
