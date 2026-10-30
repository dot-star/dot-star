#!/usr/bin/env bash
# Tests for .install_check.sh: when it installs unattended, when it asks, when it stays out of the way.
#
# Runs the check in interactive bash and zsh under a pseudo-terminal, against a fake HOME whose
# installer changed since the install stamp. A stub sudo helper picks the branch for each case.
#
# Run: bash tools/bash/.install_check_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="${SCRIPT_DIR}/.install_check.sh"

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

# Build a fake dot-star repo whose install.sh changed after the stamped commit.
repo="${work}/repo"
mkdir -p "${repo}/script"
printf '#!/usr/bin/env bash\necho FAKE_INSTALL_RAN\n' >"${repo}/script/install.sh"
/bin/chmod +x "${repo}/script/install.sh"
ln -s script/install.sh "${repo}/install.sh"
git -C "${repo}" init --quiet
git -C "${repo}" add .
git \
    -C "${repo}" \
    -c commit.gpgsign=false \
    commit \
    --quiet \
    --no-verify \
    --message="one"
ln -s "${repo}" "${work}/.dot-star"

reset_stamp() {
    git -C "${repo}" rev-parse HEAD~1 >"${work}/.dot-star-installed-commit"
    rm -f "${work}/.dot-star-install-checked-commit"
}

echo '# changed' >>"${repo}/script/install.sh"
git \
    -C "${repo}" \
    -c commit.gpgsign=false \
    commit \
    --quiet \
    --no-verify \
    --all \
    --message="two"

# Stub the prompt helper: show the question, answer from a file. Piping the answer through `script` races its end-of-file on macOS.
answer_file="${work}/answer"
cat >"${work}/run_check.sh" <<EOF
display_confirm_prompt_caution() {
    echo "PROMPT" >&2
    cat "${answer_file}"
}
source "${CHECK}"
EOF

stub_needs_sudo() {
    local verdict="${1}"
    printf 'dot_star_install_needs_sudo() {\n    return %s\n}\n' "${verdict}" >"${repo}/script/install_sudo_checks.sh"
}

# Run the check in an interactive shell on a pseudo-terminal, answering any prompt with the given reply.
run_interactive() {
    local shell_name="${1}"
    local reply="${2}"
    local shell_command
    echo "${reply}" >"${answer_file}"

    if [[ "${shell_name}" == "zsh" ]]; then
        shell_command="zsh -f -i -c 'source ${work}/run_check.sh'"
    else
        shell_command="bash --norc --noprofile -i -c 'source ${work}/run_check.sh'"
    fi

    if [[ "${OSTYPE}" == "darwin"* ]]; then
        HOME="${work}" script -q /dev/null sh -c "${shell_command}" </dev/null | tr -d '\r'
    else
        HOME="${work}" script --quiet --command "${shell_command}" /dev/null </dev/null | tr -d '\r'
    fi
}

# Print which of the prompt and the install happened, from the check's output.
summarize() {
    local output="${1}"
    local asked="no"
    local installed="no"
    if [[ "${output}" == *PROMPT* ]]; then
        asked="yes"
    fi

    if [[ "${output}" == *FAKE_INSTALL_RAN* ]]; then
        installed="yes"
    fi
    echo "asked=${asked} installed=${installed}"
}

for shell_name in bash zsh; do
    if ! command -v "${shell_name}" >/dev/null; then
        continue
    fi

    stub_needs_sudo 1
    reset_stamp
    check "${shell_name}: installs without asking when no step needs sudo" "$(summarize "$(run_interactive "${shell_name}" "n")")" "asked=no installed=yes"

    stub_needs_sudo 0
    reset_stamp
    check "${shell_name}: asks and skips on n when a step needs sudo" "$(summarize "$(run_interactive "${shell_name}" "n")")" "asked=yes installed=no"

    reset_stamp
    check "${shell_name}: asks and installs on y when a step needs sudo" "$(summarize "$(run_interactive "${shell_name}" "y")")" "asked=yes installed=yes"

    stub_needs_sudo 1
    reset_stamp
    check "${shell_name}: does nothing in a non-interactive shell" "$(summarize "$(HOME="${work}" "${shell_name}" -c "source ${work}/run_check.sh" 2>&1)")" "asked=no installed=no"
done

echo ""
echo "${passes} passed, ${fails} failed"

if [ "${fails}" -gt 0 ]; then
    exit 1
fi
