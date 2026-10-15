#!/usr/bin/env bash

# Abort on an unset variable, and on a failure anywhere in a pipeline rather
# than only in its last stage. Both carry into the scripts sourced below.
#
# Leave `errexit` off: the install sections report their own failures through
# `warn` and keep going, so one missing package still leaves the rest installed
# and the collected warnings printed at the end.
set -o nounset
set -o pipefail

# Mark the run as live, so a shell opened meanwhile skips the slow-start investigation.
install_marker="${XDG_STATE_HOME:-${HOME}/.local/state}/dot-star/install.pid"
mkdir -p "$(dirname "${install_marker}")"
echo "$$" >"${install_marker}"
trap 'rm -f "${install_marker}"' EXIT

[[ $(basename "${BASH_SOURCE}") = "install.sh" ]] && install=true || install=false
[[ "${install}" = true ]] && update=false || update=true

if $install; then
    echo -n "Installing..."
    source "script/install.sh"
fi

if $update; then
    echo -n "Updating..."
    source "script/update.sh"
fi

echo "Done"
