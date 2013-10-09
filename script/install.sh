#!/usr/bin/env bash

#set -e
#set -x

# Create symlink to project files in home directory.
DOT_STAR_ROOT="$( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ))"
[ ! -L "${HOME}/.dot-star" ] && ln -vs "${DOT_STAR_ROOT}/" "${HOME}/.dot-star"

# Find existing bootstrap in bash profile.
line_number=$(grep --line-number "# .dotstar bootstrap" "${HOME}/.bash_profile" | cut -d ":" -f "1")
if [ ! -z "${line_number}" ]; then
    # Remove installed bootstrap.
    next_line_number="${line_number}"
    (( next_line_number += 1 ))
    sed -i "" "${line_number},${next_line_number}d" "${HOME}/.bash_profile"
fi

# Add bootstrap to bash profile.
echo -e "# .dotstar bootstrap\n[[ -r ~/.bashrc ]] && source ~/.bashrc" >> "$HOME/.bash_profile"

# Find existing bootstrap in bashrc.
line_number=$(grep --line-number "# .dotstar bootstrap" "${HOME}/.bashrc" | cut -d ":" -f "1")
if [ ! -z "${line_number}" ]; then
    # Remove installed bootstrap.
    next_line_number="${line_number}"
    (( next_line_number += 1 ))
    sed -i "" "${line_number},${next_line_number}d" "${HOME}/.bashrc"
fi

# Add bootstrap to bashrc.
echo -e "# .dotstar bootstrap\n[[ -r ~/.dot-star/bash/.bash_profile ]] && source ~/.dot-star/bash/.bash_profile" >> "$HOME/.bashrc"

# Run post installation script.
source "${DOT_STAR_ROOT}/script/post_install.sh"
