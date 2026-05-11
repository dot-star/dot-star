#!/usr/bin/env bash

# Nag if script/install.sh or script/post_install.sh has changed since the
# last `./install.sh` run, so the user knows a re-install is needed beyond
# the cheap re-source.
dot_star_check_install_stale() {
    local stamp_file="${HOME}/.dot-star-installed-commit"
    if [[ ! -f "${stamp_file}" ]]; then
        return 0
    fi

    local installed_commit
    installed_commit="$(cat "${stamp_file}" 2>/dev/null)"
    if [[ -z "${installed_commit}" ]]; then
        return 0
    fi

    local current_commit
    current_commit="$(git -C "${HOME}/.dot-star" rev-parse HEAD 2>/dev/null)"
    if [[ -z "${current_commit}" ]] || [[ "${current_commit}" = "${installed_commit}" ]]; then
        return 0
    fi

    # Cheap re-source covers everything except these two; only nag when one of them changed.
    local changed_installer_files
    changed_installer_files="$(git -C "${HOME}/.dot-star" diff --name-only "${installed_commit}" HEAD -- script/install.sh script/post_install.sh 2>/dev/null)"
    if [[ -z "${changed_installer_files}" ]]; then
        return 0
    fi

    local yellow=$'\033[33m'
    local reset=$'\033[0m'
    echo "${yellow}dot-star: installer changed since last install; run \`~/.dot-star/install.sh\` to re-install.${reset}" >&2
}

dot_star_check_install_stale
unset -f dot_star_check_install_stale
