#!/usr/bin/env bash
# Tests for install_sudo_checks.sh under bash and zsh, both of which source it.
#
# Stubs dpkg and ipython3 on PATH to drive the linux branch from any host.
#
# Run: bash script/install_sudo_checks_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${SCRIPT_DIR}/install_sudo_checks.sh"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

passes=0
fails=0

check() {
    local label="${1}"
    local actual="${2}"
    local expected="${3}"

    if [ "${actual}" = "${expected}" ]; then
        passes=$((passes + 1))
        printf "  PASS  %s\n" "${label}"
    else
        fails=$((fails + 1))
        printf "  FAIL  %s\n" "${label}"
        diff <(echo "${expected}") <(echo "${actual}")
    fi
}

# Print the helper's verdict as an exit code, run in the named shell as linux with only the stubs on PATH.
# Set OSTYPE inside the shell, since each shell resets it at startup.
needs_sudo_on_linux() {
    local shell_binary="${1}"
    PATH="${stub}" "${shell_binary}" -c "OSTYPE=linux-gnu; source '${HELPER}'; dot_star_install_needs_sudo; echo \$?"
}

stub="${work}/stub"
mkdir -p "${stub}"
printf '#!/bin/sh\n' >"${stub}/ipython3"
/bin/chmod +x "${stub}/ipython3"

for shell_name in bash zsh; do
    shell_binary="$(command -v "${shell_name}")"
    if [[ -z "${shell_binary}" ]]; then
        continue
    fi

    # Report every apt package installed except jq.
    printf '#!/bin/sh\n[ "$2" != jq ]\n' >"${stub}/dpkg"
    /bin/chmod +x "${stub}/dpkg"
    check "${shell_name}: needs sudo when an apt package is missing" "$(needs_sudo_on_linux "${shell_binary}")" "0"

    printf '#!/bin/sh\nexit 0\n' >"${stub}/dpkg"
    check "${shell_name}: needs no sudo when everything is installed" "$(needs_sudo_on_linux "${shell_binary}")" "1"

    mv "${stub}/ipython3" "${work}/ipython3"
    check "${shell_name}: needs sudo when ipython3 is missing" "$(needs_sudo_on_linux "${shell_binary}")" "0"
    mv "${work}/ipython3" "${stub}/ipython3"
done

echo ""
echo "${passes} passed, ${fails} failed"

if [ "${fails}" -gt 0 ]; then
    exit 1
fi
