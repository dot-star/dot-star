#!/usr/bin/env bash
set -x

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
if [ ! -L "${HOME}/.inputrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/bash/.inputrc" "${HOME}/.inputrc"
fi

# Install Claude Code settings.
mkdir -p "${HOME}/.claude"
if [ ! -L "${HOME}/.claude/settings.json" ]; then
    ln -v -s "${DOT_STAR_ROOT}/ai/files/Users/user/.claude/settings.json" "${HOME}/.claude/settings.json"
fi

# Install colordiff configuration.
if [ ! -L "${HOME}/.colordiffrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/colordiff/.colordiffrc" "${HOME}/.colordiffrc"
fi

if [ ! -L "${HOME}/.screenrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/screen/.screenrc" "${HOME}/.screenrc"
fi

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

echo "install complete"
