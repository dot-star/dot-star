#!/usr/bin/env bash
# Keep the listed gitk settings out of git: a clean filter (bound in .gitattributes) that swaps each one's staged line back in, or drops it when none is staged.
# Leave the working file as gitk wrote it, so a setting changed in the UI survives restarts.
# Change a listed setting's committed value on purpose by staging with the filter bypassed:
#   git -c filter.gitk-ignore-listed.clean=cat add tools/version_control/gitk
set -euo pipefail

# List each setting gitk rewrites from its UI that git should keep at the committed value. Match each entry as a glob against the setting's name.
ignored_settings=(
    "geometry(*)"
    "mainfont"
    "textfont"
)

is_ignored() {
    local name="$1"
    local ignored

    for ignored in "${ignored_settings[@]}"; do
        # Leave the entry unquoted so it matches as a glob.
        if [[ "${name}" == ${ignored} ]]; then
            return 0
        fi
    done
    return 1
}

path="$1"
staged="$(git show ":${path}" 2>/dev/null || true)"

while IFS= read -r line || [[ -n "${line}" ]]; do
    read -r keyword name _ <<<"${line}"

    if [[ "${keyword}" != "set" ]]; then
        printf '%s\n' "${line}"
        continue
    elif ! is_ignored "${name}"; then
        printf '%s\n' "${line}"
        continue
    fi

    # Find the staged copy by fixed string, since names like geometry(main) carry regex characters.
    staged_line="$(grep --fixed-strings --max-count=1 "set ${name} " <<<"${staged}" || true)"

    # Drop an ignored line with no staged copy, so a setting gitk adds never shows as new.
    if [[ -n "${staged_line}" ]]; then
        printf '%s\n' "${staged_line}"
    fi
done
