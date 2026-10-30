#!/usr/bin/env bash

# Re-install if script/install.sh or script/post_install.sh has changed since
# the last `./install.sh` run, since the cheap re-source on shell startup misses
# those two.
dot_star_check_install_stale() {
    local stamp_file="${HOME}/.dot-star-installed-commit"
    local checked_file="${HOME}/.dot-star-install-checked-commit"
    local installed_commit=""
    if [[ -f "${stamp_file}" ]]; then
        installed_commit="$(<"${stamp_file}")"
    fi

    local current_commit
    current_commit="$(git -C "${HOME}/.dot-star" rev-parse HEAD 2>/dev/null)"
    if [[ -z "${current_commit}" ]] || [[ "${current_commit}" = "${installed_commit}" ]]; then
        return 0
    fi

    # Skip the diff for a commit already found clean; each new shell would otherwise re-run it until the next install.
    local checked_commit=""
    if [[ -f "${checked_file}" ]]; then
        checked_commit="$(<"${checked_file}")"
    fi

    if [[ "${checked_commit}" = "${installed_commit} ${current_commit}" ]]; then
        return 0
    fi

    # Cheap re-source covers everything except these two; only prompt when one of them changed.
    # Count both installer files as changed when no stamp exists. A host installed before the stamp was added has nothing to diff against, and skipping it would hide every later post-install change (a git pager swap, say) from that host for good.
    local installer_files=(
        script/install.sh
        script/install_sudo_checks.sh
        script/post_install.sh
    )
    local changed_installer_files="${installer_files[*]}"
    if [[ -n "${installed_commit}" ]]; then
        changed_installer_files="$(git -C "${HOME}/.dot-star" diff --name-only "${installed_commit}" HEAD -- "${installer_files[@]}" 2>/dev/null)"
    fi

    if [[ -z "${changed_installer_files}" ]]; then
        echo "${installed_commit} ${current_commit}" >"${checked_file}"
        return 0
    fi

    # Skip in non-interactive shells and when stdin isn't a tty, so a script that sources the rc file neither starts an install nor hangs on `read`.
    if [[ "$-" != *i* ]] || [[ ! -t 0 ]]; then
        return 0
    fi

    # Ask only when a step would stop at a sudo password prompt; otherwise install unattended.
    local answer="y"
    source "${HOME}/.dot-star/script/install_sudo_checks.sh"
    if dot_star_install_needs_sudo; then
        answer="$(display_confirm_prompt_caution "dot-star: installer changed since last install and a step needs sudo. Run \`~/.dot-star/install.sh\` now? This will take a minute. [y/N]")"
        echo >&2
    fi

    if [[ "${answer}" = "y" ]] || [[ "${answer}" = "Y" ]]; then
        DOT_STAR_PROFILE=1 "${HOME}/.dot-star/install.sh"
    fi

    # Restart zsh's startup timer, so neither the wait on this prompt nor the install reads as a slow start.
    if [[ -n "${zsh_startup_start}" ]]; then
        zsh_startup_start="${EPOCHREALTIME}"
    fi
}

dot_star_check_install_stale
unset -f dot_star_check_install_stale
