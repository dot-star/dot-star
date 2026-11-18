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

# Print the process ID the marker names, or nothing when there is no marker.
read_install_marker() {
    local holder=""

    if [[ -r "${install_marker}" ]]; then
        read -r holder <"${install_marker}"
    fi

    echo "${holder}"
}

# Report whether the marker names a run that is still alive.
install_marker_is_live() {
    local holder
    holder="$(read_install_marker)"

    if [[ -z "${holder}" ]]; then
        return 1
    fi

    kill -0 "${holder}" 2>/dev/null
}

# Leave a live run's marker in place, so a run that loses the install lock can't unmark the one holding it.
if ! install_marker_is_live; then
    echo "$$" >"${install_marker}"
fi

# Clear only this run's own marker.
clear_install_marker() {
    if [[ "$(read_install_marker)" == "$$" ]]; then
        rm -f "${install_marker}"
    fi
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
