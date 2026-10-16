#!/usr/bin/env bash
# Check that every on-demand doc a tracked markdown file points at exists.
#
# The instruction docs load context docs and style guides by path, and nothing
# else notices when one gets renamed; the pointer just leads nowhere. Personal
# `private-*` docs are gitignored, so they're skipped.
#
# Run: bash script/check_doc_pointers_resolve.sh

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

passes=0
fails=0

# Map a home-relative pointer to the repo path it resolves to.
resolve_pointer() {
    local pointer="$1"

    case "${pointer}" in
    "~/.dot-star/"*)
        echo "${REPO_ROOT}/${pointer#"~/.dot-star/"}"
        ;;
    "~/.claude/"*)
        echo "${REPO_ROOT}/ai/files/Users/user/.claude/${pointer#"~/.claude/"}"
        ;;
    esac
}

while IFS=: read -r source pointer; do
    if [[ "${pointer}" == *"/private-"* ]]; then
        continue
    fi

    target="$(resolve_pointer "${pointer}")"
    if [[ -f "${target}" ]]; then
        passes=$((passes + 1))
    else
        fails=$((fails + 1))
        printf "  FAIL  %s points at missing %s\n" "${source}" "${pointer}"
    fi
done < <(
    git -C "${REPO_ROOT}" ls-files -z '*.md' |
        xargs -0 -I {} grep \
            --only-matching \
            --with-filename \
            --extended-regexp \
            '~/\.(dot-star/ai/contexts|claude/styles)/[A-Za-z0-9_.-]+\.md' \
            "${REPO_ROOT}/{}" |
        sed "s|^${REPO_ROOT}/||" |
        sort --unique
)

echo "Resolved: ${passes}  Missing: ${fails}"
if [[ "${fails}" -gt 0 ]]; then
    exit 1
fi
