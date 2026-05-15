#!/usr/bin/env bash

# Prompt to re-install if script/install.sh or script/post_install.sh has
# changed since the last `./install.sh` run, since the cheap re-source on
# shell startup misses those two.
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

    # Cheap re-source covers everything except these two; only prompt when one of them changed.
    local changed_installer_files
    changed_installer_files="$(git -C "${HOME}/.dot-star" diff --name-only "${installed_commit}" HEAD -- script/install.sh script/post_install.sh 2>/dev/null)"
    if [[ -z "${changed_installer_files}" ]]; then
        return 0
    fi

    # Skip in non-interactive shells and when stdin isn't a tty; otherwise a script that sources the rc file would hang on `read`.
    if [[ "$-" != *i* ]] || [[ ! -t 0 ]]; then
        return 0
    fi

    local answer
    answer="$(display_confirm_prompt_caution "dot-star: installer changed since last install. Run \`~/.dot-star/install.sh\` now? This will take a minute. [y/N]")"
    echo >&2
    if [[ "${answer}" != "y" ]] && [[ "${answer}" != "Y" ]]; then
        return 0
    fi

    "${HOME}/.dot-star/install.sh"
}

dot_star_check_install_stale
unset -f dot_star_check_install_stale
