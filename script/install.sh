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
echo -e "# .dotstar bootstrap\n[[ -r ~/.bashrc ]] && source ~/.bashrc" >> "$HOME/.bash_profile"

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
echo -e "# .dotstar bootstrap\n[[ -r ~/.dot-star/bash/.bash_profile ]] && source ~/.dot-star/bash/.bash_profile" >> "$HOME/.bashrc"

# Find existing settings in inputrc.
line_number=$(grep --line-number "# .dotstar" "${HOME}/.inputrc" | cut -d ":" -f "1")
if [ ! -z "${line_number}" ]; then
    # Remove installed settings
    next_line_number="${line_number}"
    (( next_line_number += 1 ))
    sed -i "" "${line_number},${next_line_number}d" "${HOME}/.inputrc" &> /dev/null
    if [ ! $? -eq 0 ]; then
        sed --in-place="" "${line_number},${next_line_number}d" "${HOME}/.inputrc"
    fi
fi

# Add settings to inputrc.
echo -e "# .dotstar\nset completion-ignore-case on" >> "$HOME/.inputrc"

# Run post installation script.
source "${DOT_STAR_ROOT}/script/post_install.sh"
