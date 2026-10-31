#!/usr/bin/env bash
# Exercise git_series_diff end to end: queue a two-commit series over a throwaway
# repo (the first commit staged, the second unstaged), run it from outside the
# repo and assert each commit number shows only its own paths.
# Usage:
#   $ bash tools/version_control/.aliases_series_diff_test.sh [<checkout to test>]

set -euo pipefail

# Default to the checkout this script lives in.
checkout="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
version_control_aliases="${checkout}/tools/version_control/.aliases.sh"

repo="$(command mktemp -d)"
series_dir="/tmp/claude/series-diff-test-$$/series"
trap 'rm -rf "${repo}" "$(dirname "${series_dir}")"' EXIT

cd "${repo}"
git init \
    --quiet \
    --initial-branch=master \
    .

echo "before" >first.txt
echo "before" >second.txt
git add -- first.txt second.txt
git \
    -c user.name="test" \
    -c user.email="test@example.com" \
    commit \
    --quiet \
    --message="sample:base"

echo "staged change" >first.txt
git add -- first.txt
echo "unstaged change" >second.txt

mkdir -p "${series_dir}"
printf '%s\n' "staged" "${repo}" "first.txt" >"${series_dir}/1"
printf '%s\n' "unstaged" "${repo}" "second.txt" >"${series_dir}/2"

# Run from outside the repo, the way a new terminal tab would.
show() {
    local commit_number="${1}"

    (
        cd /
        source "${version_control_aliases}" 2>/dev/null
        clear() {
            :
        }
        GIT_PAGER=cat git_series_diff "${commit_number}"
    )
}

failures=0

check_show() {
    local commit_number="${1}"
    local wanted="${2}"
    local unwanted="${3}"
    local output
    output="$(show "${commit_number}")"

    if [[ "${output}" != *"+${wanted}"* ]]; then
        echo "✗ commit ${commit_number}: missing '${wanted}'"
        echo "${output}"
        failures=$((failures + 1))
    elif [[ "${output}" == *"+${unwanted}"* ]]; then
        echo "✗ commit ${commit_number}: shows '${unwanted}' from another commit"
        echo "${output}"
        failures=$((failures + 1))
    else
        echo "✓ commit ${commit_number}: shows only its own change"
    fi
}

check_show 1 "staged change" "unstaged change"
check_show 2 "unstaged change" "staged change"

if show 9 2>/dev/null; then
    echo "✗ commit 9: wanted a failure for a commit with no series file"
    failures=$((failures + 1))
else
    echo "✓ commit 9: fails with no series file"
fi

if [[ "${failures}" -gt 0 ]]; then
    echo "${failures} check(s) failed"
    exit 1
fi

echo "All checks passed"
