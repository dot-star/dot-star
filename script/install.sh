#!/usr/bin/env bash
set -x

# Create symlink to project files in home directory.
DOT_STAR_ROOT="$( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ))"
ln -vsf "${DOT_STAR_ROOT}/" "${HOME}/.dot-star"

dotstar_header="# Begin dot-star bootstrap."
dotstar_footer="# End dot-star bootstrap."

setup_bootstrap() {
    filename="${1}"
    script="${2}"

    # Remove any existing bootstrap.
    sed -i "" "/${dotstar_header}/,/${dotstar_footer}/d" "${filename}" &> /dev/null

    echo -e "${dotstar_header}" >> "${filename}"
    echo -e "${script}"         >> "${filename}"
    echo -e "${dotstar_footer}" >> "${filename}"
}

setup_bootstrap "${HOME}/.bash_profile" 'echo "if shopt -q login_shell; then
    [[ -r ~/.bashrc ]] && source ~/.bashrc
fi" >> "$HOME/.bash_profile"'

setup_bootstrap "${HOME}/.bashrc" 'echo "if shopt -q login_shell; then
    [[ -r ~/.dot-star/bash/.bash_profile ]] && source ~/.dot-star/bash/.bash_profile
fi" >> "$HOME/.bashrc"'

setup_bootstrap "${HOME}/.zshrc" '[[ -r ~/.dot-star/bash/.bash_profile ]] && source ~/.dot-star/bash/.bash_profile'

# Install inputrc.
if [ ! -L "${HOME}/.inputrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/bash/.inputrc" "${HOME}/.inputrc"
fi

# Install colordiff configuration.
if [ ! -L "${HOME}/.colordiffrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/colordiff/.colordiffrc" "${HOME}/.colordiffrc"
fi

if [ ! -L "${HOME}/.screenrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/screen/.screenrc" "${HOME}/.screenrc"
fi

install_ipython() {
    python3 -m ensurepip --upgrade
    python3 -m pip install --upgrade pip

    if [[ "${OSTYPE}" == "darwin"* ]]; then
        brew install python
    fi
    python3 -m pip install --user ipython

    # Add python binaries to PATH.
    echo -e "export PATH=$PATH:/Users/$(whoami)/Library/Python/2.7/bin\n\n" >> "${HOME}/.bash_profile"

    # Disable IPython's "Do you really want to exit ([y]/n)?".
    export PATH="$PATH:/Users/$(whoami)/Library/Python/2.7/bin"
    ipython profile create
    echo -e "c.TerminalInteractiveShell.confirm_exit = False\n" >> ~/.ipython/profile_default/ipython_config.py
    echo -e "c.TerminalInteractiveShell.editing_mode = 'vi'\n" >> ~/.ipython/profile_default/ipython_config.py
    echo -e "c.TerminalInteractiveShell.editor = 'vi'\n" >> ~/.ipython/profile_default/ipython_config.py
}
install_ipython

# Add bootstrap footer to bash profile.
echo -e "${dotstar_footer}" >> "$HOME/.bash_profile"

# TODO: Consolidate post install script into install script.
# Run post installation script.
source "${DOT_STAR_ROOT}/script/post_install.sh"

echo "install complete"
