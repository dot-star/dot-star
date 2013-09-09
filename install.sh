#!/usr/bin/env bash

#set -e
#set -x

[[ $(basename "${BASH_SOURCE}") = "install.sh" ]] && install=true || install=false
[[ "${install}" = true ]] && update=false || update=true
echo "install: ${install}"
echo "update: ${update}"

if $install; then
    echo -n "Installing..."
    source "script/install.sh"
fi

if $update; then
    echo -n "Updating..."
    source "script/update.sh"
fi

echo "Done"
