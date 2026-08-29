#!/usr/bin/env bash
# Exercise the worktree age-color tiers end to end: build a throwaway repo with
# one worktree per age, backdate each worktree's HEAD, then render the table the
# way `git status`'s summary and `wta` do and assert each row picked the right
# color. The `edge-*` rows sit one second either side of a tier boundary.
# Usage:
#   $ bash tools/version_control/.aliases_worktree_age_test.sh [<checkout to test>]

set -euo pipefail

# Default to the checkout this script lives in.
checkout="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
version_control_aliases="${checkout}/tools/version_control/.aliases.sh"
picker_aliases="${checkout}/tools/bash/.aliases.sh"

# Name each sample worktree and the age its HEAD gets backdated to.
samples=(
    "months:10368000"
    "weeks:1814400"
    "edge-24h:86400"
    "edge-23h:86399"
    "days:172800"
    "edge-60m:3600"
    "edge-59m:3599"
    "hours:18000"
    "minutes:960"
    "edge-60s:60"
    "edge-59s:59"
    "seconds:30"
)

backdate() {
    # Set a file's mtime to N seconds ago. Go through perl rather than `touch`,
    # whose backdating flags differ between BSD and GNU.
    local file="${1}"
    local seconds_ago="${2}"

    local epoch
    epoch=$(($(command date +%s) - seconds_ago))

    perl -e 'utime $ARGV[0], $ARGV[0], $ARGV[1]' "${epoch}" "${file}"
}

repo="$(command mktemp -d)"
trap 'rm -rf "${repo}"' EXIT

cd "${repo}"
git init \
    --quiet \
    --initial-branch=master \
    .
git \
    -c user.name="test" \
    -c user.email="test@example.com" \
    commit \
    --quiet \
    --allow-empty \
    --message="Seed the test repo"

# Add one worktree per sample, on the auto-generated `worktree-<name>` branch
# name so the branch column stays out of the way, then backdate its HEAD. The
# age comes from HEAD's mtime, which is what the table ranks and prints.
for sample in "${samples[@]}"; do
    name="${sample%%:*}"
    seconds_ago="${sample##*:}"
    git worktree add \
        --quiet \
        -b "worktree-${name}" \
        "${repo}/${name}"
    backdate "${repo}/.git/worktrees/${name}/HEAD" "${seconds_ago}"
done

# Render through the real functions rather than a copy of their awk.
output="$(
    source "${version_control_aliases}" 2>/dev/null
    git_worktree_list_sorted |
        git_worktree_list_render 0
)"

echo "Rendered table:"
echo
echo "${output}"
echo

seconds_color="48;5;22"
recent_color="38;5;78"

check_row() {
    # Assert the named row's age carries the wanted color escape, or (with
    # "faded") neither highlight color, so it fell through to the age ramp.
    local name="${1}"
    local want="${2}"

    # Match the name column by the escape that opens it, so a name like "hours"
    # picks its own row instead of every row whose age reads "N hours ago".
    local row
    row="$(echo "${output}" | grep --fixed-strings -- "80m${name}" || true)"

    if [[ -z "${row}" ]]; then
        echo "✗ ${name}: no row rendered"
        failures=$((failures + 1))
        return
    fi

    local held="faded"
    if [[ "${row}" == *"${seconds_color}"* ]]; then
        held="${seconds_color}"
    elif [[ "${row}" == *"${recent_color}"* ]]; then
        held="${recent_color}"
    fi

    if [[ "${held}" == "${want}" ]]; then
        echo "✓ ${name}: ${want}"
    else
        echo "✗ ${name}: wanted ${want}, got ${held}"
        failures=$((failures + 1))
    fi
}

failures=0

echo "Color tiers:"
check_row "seconds" "${seconds_color}"
check_row "edge-59s" "${seconds_color}"
check_row "edge-60s" "${recent_color}"
check_row "minutes" "${recent_color}"
check_row "edge-59m" "${recent_color}"
check_row "edge-60m" "${recent_color}"
check_row "hours" "${recent_color}"
check_row "edge-23h" "${recent_color}"
check_row "edge-24h" "faded"
check_row "days" "faded"
check_row "weeks" "faded"
check_row "months" "faded"
echo

# Compare the two copies of the tier block: the table and `wt`'s fzf picker
# each carry their own awk, so they can drift apart silently.
tier_block() {
    grep --extended-regexp "rel ~ /second/|rel ~ /minute/|age_color = " "${1}" |
        tr -d ' '
}

echo "Table vs. picker:"
if diff <(tier_block "${version_control_aliases}") <(tier_block "${picker_aliases}") >/dev/null; then
    echo "✓ tier blocks match"
else
    echo "✗ tier blocks differ:"
    diff <(tier_block "${version_control_aliases}") <(tier_block "${picker_aliases}") || true
    failures=$((failures + 1))
fi
echo

if [[ "${failures}" -gt 0 ]]; then
    echo "${failures} check(s) failed"
    exit 1
fi

echo "All checks passed"
