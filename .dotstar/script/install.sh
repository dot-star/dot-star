#!/usr/bin/env bash

set -e
#set -x

DOT_STAR_ROOT="$( dirname $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ))"
ln -sf "${DOT_STAR_ROOT}" "${HOME}"

# Add bootstrap to bash profile.
if ! grep --quiet "# .dotstar bootstrap" "$HOME/.bash_profile"; then
    echo -e "\n# .dotstar bootstrap\n[[ -r ~/.dotstar/bash/.bash_profile ]] && . ~/.dotstar/bash/.bash_profile\n" >> "$HOME/.bash_profile"
fi
