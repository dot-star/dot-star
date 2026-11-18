#!/usr/bin/env bash

# Abort on an unset variable, and on a failure anywhere in a pipeline rather
# than only in its last stage. Both carry into the scripts sourced below.
#
# Leave `errexit` off: the install sections report their own failures through
# `warn` and keep going, so one missing package still leaves the rest installed
# and the collected warnings printed at the end.
set -o nounset
set -o pipefail

# Run from the checkout holding this script, so the relative paths below resolve
# from any cwd and a worktree's copy never sources the main checkout's installer.
if ! cd "$(dirname "${BASH_SOURCE[0]}")"; then
    exit 1
fi

# Mark the run as live, so a shell opened meanwhile skips the slow-start investigation.
install_marker="${XDG_STATE_HOME:-${HOME}/.local/state}/dot-star/install.pid"
mkdir -p "$(dirname "${install_marker}")"
echo "$$" >"${install_marker}"
clear_install_marker() {
    rm -f "${install_marker}"
}
trap clear_install_marker EXIT

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
