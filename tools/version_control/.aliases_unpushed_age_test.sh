#!/usr/bin/env bash
# Exercise the unpushed-commit listing's age-color tiers end to end: build a
# throwaway repo holding one backdated commit per age, print the summary the way
# `git status` does and assert each row picked the right color. The `edge-*`
# commits sit either side of a tier boundary, placed at git's own relative-date
# thresholds (90 seconds, 90 minutes, 36 hours) rather than the round ones.
# Usage:
#   $ bash tools/version_control/.aliases_unpushed_age_test.sh [<checkout to test>]

set -euo pipefail

# Default to the checkout this script lives in.
checkout="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
version_control_aliases="${checkout}/tools/version_control/.aliases.sh"

# Name each sample commit and the age its committer date gets backdated to,
# oldest first so the listing's newest-first order falls out of the loop. Stay
# under the listing's nine-row cap so every sample gets a row.
# Back a below-the-boundary age off by ten seconds rather than one: the age is
# measured again at render, so the commits and the render itself have to fit in
# the gap or the sample ages out of the tier it is asserting.
samples=(
    "months:10368000"
    "days:172800"
    "edge-36h:129600"
    "edge-35h:126000"
    "minutes:960"
    "edge-90s:90"
    "edge-80s:80"
    "seconds:30"
)

repo="$(command mktemp -d)"
remote="${repo}.remote"
trap 'rm -rf "${repo}" "${remote}"' EXIT

cd "${repo}"
git init \
    --quiet \
    --initial-branch=master \
    .

# Point the repo at an empty remote, so the summary counts every commit as
# unpushed. Without a remote it warns about that instead and lists nothing.
git init \
    --quiet \
    --bare \
    "${remote}"
git remote add origin "${remote}"

now="$(command date +%s)"

# Commit one sample per age, tagging each subject with its sample name so the
# assertions can pick that row back out of the summary.
for sample in "${samples[@]}"; do
    name="${sample%%:*}"
    seconds_ago="${sample##*:}"

    when="$((now - seconds_ago))"
    GIT_AUTHOR_DATE="${when} +0000" GIT_COMMITTER_DATE="${when} +0000" git \
        -c user.name="test" \
        -c user.email="test@example.com" \
        commit \
        --quiet \
        --allow-empty \
        --message="sample:${name}"
done

# Render through the real function rather than a copy of its awk.
output="$(
    source "${version_control_aliases}" 2>/dev/null
    rc_status
)"

echo "Rendered listing:"
echo
echo "${output}" | grep --fixed-strings -- "sample:"
echo

seconds_color="48;5;22"
recent_color="38;5;78"

check_row() {
    # Assert the named sample's age carries the wanted color escape, or (with
    # "faded") neither highlight color, so it fell through to git's own dim.
    local name="${1}"
    local want="${2}"

    # Match the subject tag rather than the name alone, so a sample like "days"
    # picks its own row instead of every row whose age reads "N days ago".
    local row
    row="$(echo "${output}" | grep --fixed-strings -- "sample:${name}" || true)"

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
check_row "edge-80s" "${seconds_color}"
check_row "edge-90s" "${recent_color}"
check_row "minutes" "${recent_color}"
check_row "edge-35h" "${recent_color}"
check_row "edge-36h" "faded"
check_row "days" "faded"
check_row "months" "faded"
echo

if [[ "${failures}" -gt 0 ]]; then
    echo "${failures} check(s) failed"
    exit 1
fi

echo "All checks passed"
