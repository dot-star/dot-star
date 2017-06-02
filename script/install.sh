#!/usr/bin/env bash
set -x

# Create symlink to project files in home directory.
DOT_STAR_ROOT="$( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ))"
[ ! -L "${HOME}/.dot-star" ] && ln -vs "${DOT_STAR_ROOT}/" "${HOME}/.dot-star"

dotstar_header="# Begin dot-star bootstrap."
dotstar_footer="# End dot-star bootstrap."

# Remove any existing bootstrap in bash profile.
sed -i "" "/${dotstar_header}/,/${dotstar_footer}/d" "${HOME}/.bash_profile" &> /dev/null

# Add bootstrap header to bash profile.
echo -e "${dotstar_header}" >> "$HOME/.bash_profile"

echo "if shopt -q login_shell; then
    [[ -r ~/.bashrc ]] && source ~/.bashrc
fi" >> "$HOME/.bash_profile"

# Remove any existing bootstrap in bashrc.
sed -i "" "/${dotstar_header}/,/${dotstar_footer}/d" "${HOME}/.bashrc" &> /dev/null

# Add bootstrap header to bashrc.
echo -e "${dotstar_header}" >> "$HOME/.bashrc"

echo "if shopt -q login_shell; then
    [[ -r ~/.dot-star/bash/.bash_profile ]] && source ~/.dot-star/bash/.bash_profile
fi" >> "$HOME/.bashrc"

# Add bootstrap footer to bashrc.
echo -e "${dotstar_footer}" >> "$HOME/.bashrc"

# Install inputrc.
if [ ! -L "${HOME}/.inputrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/bash/.inputrc" "${HOME}/.inputrc"
fi

# Install colordiff configuration.
if [ ! -L "${HOME}/.colordiffrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/colordiff/.colordiffrc" "${HOME}/.colordiffrc"
fi

install_ipython() {
    sudo easy_install pip
    pip install --upgrade pip

    if [[ "${OSTYPE}" == "darwin"* ]]; then
        brew install python
    fi
    pip install --user ipython

    # Add python binaries to PATH.
    echo -e "export PATH=$PATH:/Users/$(whoami)/Library/Python/2.7/bin" >> "${HOME}/.bash_profile"

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
