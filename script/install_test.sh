#!/usr/bin/env bash
# Tests for setup_bootstrap in install.sh.
#
# Sources just the bootstrap block writer out of install.sh (the rest of the
# script touches the real home directory) and runs it against rc-file fixtures.
#
# Run: bash script/install_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="${SCRIPT_DIR}/install.sh"
SNIPPET='[[ -r ~/.dot-star/bootstrap/.bash_profile ]] && source ~/.dot-star/bootstrap/.bash_profile'

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# Pull the header/footer assignments and the function body out of install.sh.
awk '/^dotstar_header=/,/^}$/' "${INSTALL}" >"${work}/setup_bootstrap.sh"
source "${work}/setup_bootstrap.sh"

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

# Create the file when it does not exist yet.
missing="${work}/missing_rc"
setup_bootstrap "${missing}" "${SNIPPET}"
check "creates a missing file" "$(cat "${missing}")" "# Begin dot-star bootstrap.
${SNIPPET}
# End dot-star bootstrap."

# Append the block when the file carries none.
blockless="${work}/blockless_rc"
printf 'export PATH="/opt/bin:$PATH"\n' >"${blockless}"
setup_bootstrap "${blockless}" "${SNIPPET}"
check "appends to a blockless file" "$(cat "${blockless}")" "export PATH=\"/opt/bin:\$PATH\"
# Begin dot-star bootstrap.
${SNIPPET}
# End dot-star bootstrap."

# Leave the block alone when another installer appended below it.
midfile="${work}/midfile_rc"
cat >"${midfile}" <<EOF
export EDITOR=vim
# Begin dot-star bootstrap.
${SNIPPET}
# End dot-star bootstrap.

# Added by Some CLI installer
export PATH="/opt/other/bin:\$PATH"
EOF
before="$(cat "${midfile}")"
setup_bootstrap "${midfile}" "${SNIPPET}"
check "leaves the block where it sits" "$(cat "${midfile}")" "${before}"

setup_bootstrap "${midfile}" "${SNIPPET}"
check "stays idempotent on a second run" "$(cat "${midfile}")" "${before}"

# Rewrite a changed snippet without moving the block.
setup_bootstrap "${midfile}" 'source ~/.dot-star/bootstrap/.bash_profile'
check "updates the snippet in place" "$(cat "${midfile}")" 'export EDITOR=vim
# Begin dot-star bootstrap.
source ~/.dot-star/bootstrap/.bash_profile
# End dot-star bootstrap.

# Added by Some CLI installer
export PATH="/opt/other/bin:$PATH"'

# Collapse duplicate blocks and drop a stray footer.
messy="${work}/messy_rc"
cat >"${messy}" <<EOF
# End dot-star bootstrap.
export EDITOR=vim
# Begin dot-star bootstrap.
stale snippet
# End dot-star bootstrap.
export LANG=en_US.UTF-8
# Begin dot-star bootstrap.
another stale snippet
# End dot-star bootstrap.
EOF
setup_bootstrap "${messy}" "${SNIPPET}"
check "collapses duplicates and stray footers" "$(cat "${messy}")" "export EDITOR=vim
# Begin dot-star bootstrap.
${SNIPPET}
# End dot-star bootstrap.
export LANG=en_US.UTF-8"

# Write through a symlinked rc file without replacing the symlink.
target="${work}/linked_target"
link="${work}/linked_rc"
printf 'export EDITOR=vim\n' >"${target}"
ln -s "${target}" "${link}"
setup_bootstrap "${link}" "${SNIPPET}"

if [ -L "${link}" ]; then
    passes=$((passes + 1))
    printf "  PASS  %s\n" "keeps the symlink intact"
else
    fails=$((fails + 1))
    printf "  FAIL  %s\n" "keeps the symlink intact"
fi

check "writes through the symlink" "$(cat "${target}")" "export EDITOR=vim
# Begin dot-star bootstrap.
${SNIPPET}
# End dot-star bootstrap."

echo ""
echo "${passes} passed, ${fails} failed"

if [ "${fails}" -gt 0 ]; then
    exit 1
fi
