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

# `ln -s src dest`, but warn instead of overwriting if dest already exists.
ensure_symlink() {
    local src="${1}"
    local dest="${2}"
    # Check for any symlink (working or broken) as destination.
    if [ -L "${dest}" ]; then
        local actual_src
        actual_src="$(readlink "${dest}")"
        if [ "${actual_src}" = "${src}" ]; then
            # Already canonical.
            return 0
        elif [ -e "${dest}" ] && [ -e "${src}" ] && [ "${dest}" -ef "${src}" ]; then
            # Check that both paths exist (-e) and resolve to the same inode (-ef); refresh to canonical src path.
            rm "${dest}"
            ln -v -s "${src}" "${dest}"
        else
            # Symlink points at a different file; don't clobber.
            warn "${dest} is a symlink to ${actual_src}, expected ${src}"
        fi
    # Check for any existing path (regular file, directory, socket, FIFO, etc.) as destination.
    elif [ -e "${dest}" ]; then
        # Check for a regular file with content matching src; safe to replace with symlink.
        if [ -f "${dest}" ] && [ -f "${src}" ] && cmp -s "${dest}" "${src}"; then
            rm "${dest}"
            ln -v -s "${src}" "${dest}"
        else
            # Don't clobber.
            warn "${dest} exists but is not a symlink, expected symlink to ${src}"
        fi
    # No entry at destination.
    else
        ln -v -s "${src}" "${dest}"
    fi
}

# Create symlink to project files in home directory.
DOT_STAR_ROOT="$(dirname $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd))"
DOT_STAR="${HOME}/.dot-star"
if [ -L "${DOT_STAR}" ]; then
    # Replace existing symlink.
    rm "${DOT_STAR}"
    ln -vs "${DOT_STAR_ROOT}" "${DOT_STAR}"
elif [ -e "${DOT_STAR}" ]; then
    # Refuse to clobber a real file or directory.
    warn "${DOT_STAR} exists and is not a symlink, refusing to clobber"
else
    # Create symlink.
    ln -vs "${DOT_STAR_ROOT}" "${DOT_STAR}"
fi

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
ensure_symlink "${DOT_STAR}/bash/.inputrc" "${HOME}/.inputrc"

# Install Claude Code settings.
mkdir -p "${HOME}/.claude"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/settings.json" "${HOME}/.claude/settings.json"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"

# Install colordiff configuration.
ensure_symlink "${DOT_STAR}/colordiff/.colordiffrc" "${HOME}/.colordiffrc"

ensure_symlink "${DOT_STAR}/screen/.screenrc" "${HOME}/.screenrc"

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
