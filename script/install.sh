#!/usr/bin/env bash

set -e
#set -x

DOT_STAR_ROOT="$( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ))"
ln -sf "${DOT_STAR_ROOT}" "${HOME}"

# Find existing bootstrap in bash profile.
line_number=$(grep --line-number "# .dotstar bootstrap" "${HOME}/.bash_profile" | cut -d ":" -f "1")
if [ ! -z "${line_number}" ]; then
    # Remove installed bootstrap.
    next_line_number="${line_number}"
    (( next_line_number += 1 ))
    sed -i "" "${line_number},${next_line_number}d" "${HOME}/.bash_profile"
fi

# Add bootstrap to bash profile.
echo -e "# .dotstar bootstrap\n[[ -r ~/.dotstar/bash/.bash_profile ]] && . ~/.dotstar/bash/.bash_profile" >> "$HOME/.bash_profile"
