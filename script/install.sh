#!/usr/bin/env bash

# Create symlink to project files in home directory.
DOT_STAR_ROOT="$( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ))"
[ ! -L "${HOME}/.dot-star" ] && ln -vs "${DOT_STAR_ROOT}/" "${HOME}/.dot-star"

# Find existing bootstrap in bash profile.
line_number=$(grep --line-number "# .dotstar bootstrap" "${HOME}/.bash_profile" | cut -d ":" -f "1")
if [ ! -z "${line_number}" ]; then
    # Remove installed bootstrap.
    next_line_number="${line_number}"
    (( next_line_number += 1 ))
    sed -i "" "${line_number},${next_line_number}d" "${HOME}/.bash_profile" &> /dev/null
    if [ ! $? -eq 0 ]; then
        sed --in-place="" "${line_number},${next_line_number}d" "${HOME}/.bash_profile"
    fi
fi

# Add bootstrap to bash profile.
echo "
# .dotstar bootstrap
if shopt -q login_shell; then
    [[ -r ~/.bashrc ]] && source ~/.bashrc
fi" >> "$HOME/.bash_profile"

# Find existing bootstrap in bashrc.
line_number=$(grep --line-number "# .dotstar bootstrap" "${HOME}/.bashrc" | cut -d ":" -f "1")
if [ ! -z "${line_number}" ]; then
    # Remove installed bootstrap.
    next_line_number="${line_number}"
    (( next_line_number += 1 ))
    sed -i "" "${line_number},${next_line_number}d" "${HOME}/.bashrc" &> /dev/null
    if [ ! $? -eq 0 ]; then
        sed --in-place="" "${line_number},${next_line_number}d" "${HOME}/.bashrc"
    fi
fi

# Add bootstrap to bashrc.
echo "
# .dotstar bootstrap
if shopt -q login_shell; then
    [[ -r ~/.dot-star/bash/.bash_profile ]] && source ~/.dot-star/bash/.bash_profile
fi" >> "$HOME/.bashrc"

# Install inputrc.
if [ ! -L "${HOME}/.inputrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/bash/.inputrc" "${HOME}/.inputrc"
fi

# Install colordiff configuration.
if [ ! -L "${HOME}/.colordiffrc" ]; then
    ln -v -s "${DOT_STAR_ROOT}/colordiff/.colordiffrc" "${HOME}/.colordiffrc"
fi

# Disable IPython's "Do you really want to exit ([y]/n)?".
ipython profile create
sed --in-place --regexp-extended 's/# c.TerminalInteractiveShell.confirm_exit = True/c.TerminalInteractiveShell.confirm_exit = False/' ~/.ipython/profile_default/ipython_config.py

# Run post installation script.
source "${DOT_STAR_ROOT}/script/post_install.sh"
