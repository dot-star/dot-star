#!/usr/bin/env bash
set -x

WARNINGS=()

# Append a warning to WARNINGS and emit it to stderr without xtrace noise.
warn() {
    WARNINGS+=("${1}")
    set +x
    echo "WARNING: ${1}" >&2
    set -x
}

# Symlink path -> expected_target; warn instead of overwriting if path already exists.
ensure_symlink() {
    local path="${1}"
    local expected_target="${2}"
    if [ -L "${path}" ]; then
        local actual_target
        actual_target="$(readlink "${path}")"
        if [ "${actual_target}" = "${expected_target}" ]; then
            return 0
        fi
        warn "${path} is a symlink to ${actual_target}, expected ${expected_target}"
        return 0
    fi
    if [ -e "${path}" ]; then
        warn "${path} exists but is not a symlink, expected symlink to ${expected_target}"
        return 0
    fi
    ln -v -s "${expected_target}" "${path}"
}

# Create symlink to project files in home directory.
DOT_STAR_ROOT="$(dirname $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd))"
rm -f "${HOME}/.dot-star"
ln -vs "${DOT_STAR_ROOT}" "${HOME}/.dot-star"

dotstar_header="# Begin dot-star bootstrap."
dotstar_footer="# End dot-star bootstrap."

setup_bootstrap() {
    filename="${1}"
    script="${2}"

    # Remove any existing bootstrap.
    while grep -q "${dotstar_header}" "${filename}" 2>/dev/null; do
        sed -i "" "/${dotstar_header}/,/${dotstar_footer}/d" "${filename}"
    done
    grep -v "${dotstar_footer}" "${filename}" >"${filename}.tmp" && mv "${filename}.tmp" "${filename}"

    echo -e "${dotstar_header}" >>"${filename}"
    echo -e "${script}" >>"${filename}"
    echo -e "${dotstar_footer}" >>"${filename}"
}

setup_bootstrap "${HOME}/.bash_profile" 'echo "if shopt -q login_shell; then
    [[ -r ~/.bashrc ]] && source ~/.bashrc
fi" >> "$HOME/.bash_profile"'

setup_bootstrap "${HOME}/.bashrc" 'echo "if shopt -q login_shell; then
    [[ -r ~/.dot-star/bash/.bash_profile ]] && source ~/.dot-star/bash/.bash_profile
fi" >> "$HOME/.bashrc"'

# Install inputrc.
ensure_symlink "${HOME}/.inputrc" "${DOT_STAR_ROOT}/bash/.inputrc"

# Install Claude Code settings.
mkdir -p "${HOME}/.claude"
ensure_symlink "${HOME}/.claude/settings.json" "${DOT_STAR_ROOT}/ai/files/Users/user/.claude/settings.json"
ensure_symlink "${HOME}/.claude/CLAUDE.md" "${DOT_STAR_ROOT}/ai/files/Users/user/.claude/CLAUDE.md"

# Install colordiff configuration.
ensure_symlink "${HOME}/.colordiffrc" "${DOT_STAR_ROOT}/colordiff/.colordiffrc"

ensure_symlink "${HOME}/.screenrc" "${DOT_STAR_ROOT}/screen/.screenrc"

install_ipython() {
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        brew install ipython
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        sudo apt-get install -y ipython3
    fi

    ipython profile create
    echo -e "c.TerminalInteractiveShell.confirm_exit = False\n" >>~/.ipython/profile_default/ipython_config.py
    echo -e "c.TerminalInteractiveShell.editing_mode = 'vi'\n" >>~/.ipython/profile_default/ipython_config.py
    echo -e "c.TerminalInteractiveShell.editor = 'vi'\n" >>~/.ipython/profile_default/ipython_config.py
}
install_ipython

# TODO: Consolidate post install script into install script.
# Run post installation script.
source "${DOT_STAR_ROOT}/script/post_install.sh"

if [ ${#WARNINGS[@]} -gt 0 ]; then
    set +x
    echo
    echo "warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - ${warning}"
    done
    echo
    set -x
fi

echo "install complete"
