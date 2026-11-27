#!/usr/bin/env bash
# Keep the listed gitk settings out of git: a clean filter (bound in .gitattributes) that swaps each one's staged line back in.
# Leave the working file as gitk wrote it, so a setting changed in the UI survives restarts.
# Change a listed setting's committed value on purpose by staging with the filter bypassed:
#   git -c filter.gitk-ignore-listed.clean=cat add tools/version_control/gitk
set -euo pipefail

# List each setting gitk rewrites from its UI that git should keep at the committed value.
ignored_settings=(
    "mainfont"
    "textfont"
)

is_ignored() {
    local name="$1"
    local ignored

    for ignored in "${ignored_settings[@]}"; do
        if [[ "${name}" == "${ignored}" ]]; then
            return 0
        fi
    done
    return 1
}

path="$1"
staged="$(git show ":${path}" 2>/dev/null || true)"

while IFS= read -r line || [[ -n "${line}" ]]; do
    read -r keyword name _ <<<"${line}"
    staged_line=""

    if [[ "${keyword}" == "set" ]]; then
        if is_ignored "${name}"; then
            staged_line="$(grep --max-count=1 "^set ${name} " <<<"${staged}" || true)"
        fi
    fi

    if [[ -n "${staged_line}" ]]; then
        printf '%s\n' "${staged_line}"
    else
        printf '%s\n' "${line}"
    fi
done
