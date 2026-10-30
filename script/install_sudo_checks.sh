# Name each installer step that escalates to sudo, so tools/bash/.install_check.sh can ask before an install that would stop at a password prompt.
# Sourced by install.sh (which hands it on to post_install.sh) and by tools/bash/.install_check.sh in bash and zsh alike.

# Package is `bat' on Debian/Ubuntu but installs the binary as `batcat'
# to avoid clashing with an unrelated `bat' package.
dot_star_apt_packages=(
    bat
    colordiff
    fzf
    git-delta
    jq
    python3-pip
    tig
)

dot_star_apt_package_missing() {
    local package="${1}"
    ! dpkg --status "${package}" >/dev/null 2>&1
}

dot_star_brew_missing() {
    ! command -v brew >/dev/null
}

dot_star_ipython3_missing() {
    ! command -v ipython3 >/dev/null
}

# Probe a tool that does real work, not `xcodebuild -version`: the version
# query answers whatever the license state, so it can't see the pending
# agreement. `xcrun --find clang` is what Homebrew's own
# `check_xcode_license_approved` probes.
# Match only the license message, so a machine where `xcrun` fails for its own
# reasons (no Xcode, command line tools only) gets no password prompt.
dot_star_xcode_license_pending() {
    local xcrun_status
    xcrun_status="$(/usr/bin/xcrun --find clang 2>&1)"
    [[ "${xcrun_status}" == *license* ]]
}

# Succeed when any sudo step above would run on this machine.
dot_star_install_needs_sudo() {
    local package
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        if dot_star_brew_missing; then
            return 0
        elif dot_star_xcode_license_pending; then
            return 0
        fi
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        if dot_star_ipython3_missing; then
            return 0
        fi

        for package in "${dot_star_apt_packages[@]}"; do
            if dot_star_apt_package_missing "${package}"; then
                return 0
            fi
        done
    fi
    return 1
}
