#!/usr/bin/env bash

# Profile a run with:
# DOT_STAR_PROFILE=1 ./install.sh
# to emit a nested timing tree of each section (helpers in `bash/.timer.sh`).
# The flag disables `set -x` xtrace so the tree stays readable.
if [[ -z "${DOT_STAR_PROFILE:-}" ]]; then
    set -x
fi

# Resume xtrace after a temporary `set +x`, unless profiling.
_resume_xtrace() {
    if [[ -z "${DOT_STAR_PROFILE:-}" ]]; then
        set -x
    fi
}

if [[ -z "${HOME:-}" ]]; then
    echo "HOME must be set" >&2
    exit 1
fi

WARNINGS=()

# Append a warning to WARNINGS and emit it to stderr without xtrace noise.
# Optional second arg is a suggested command, shown on its own line in cyan.
warn() {
    local bold_yellow=$'\033[1;33m'
    local cyan=$'\033[36m'
    local reset=$'\033[0m'

    local message="${1}"
    local suggested_command="${2:-}"
    local entry="${message}"

    # Include the suggested command in the warning message if provided.
    if [ -n "${suggested_command}" ]; then
        entry="${message}"$'\n'"    ${cyan}Run: ${suggested_command}${reset}"
    fi

    WARNINGS+=("${entry}")

    set +x
    printf '%sWARNING:%s %s\n' "${bold_yellow}" "${reset}" "${message}" >&2
    # Print the suggested command on its own line if provided.
    if [ -n "${suggested_command}" ]; then
        printf '    %sRun: %s%s\n' "${cyan}" "${suggested_command}" "${reset}" >&2
    fi
    _resume_xtrace
}

# `ln -s src dest`, but warn instead of overwriting if dest already exists.
ensure_symlink() {
    local src="${1}"
    local dest="${2}"
    # Check for any symlink (working or broken) as destination.
    if [ -L "${dest}" ]; then
        local actual_src
        actual_src="$(readlink "${dest}")"
        if [ "${actual_src}" = "${src}" ]; then
            # Already canonical.
            return 0
        elif [ -e "${dest}" ] && [ -e "${src}" ] && [ "${dest}" -ef "${src}" ]; then
            # Check that both paths exist (-e) and resolve to the same inode (-ef); refresh to canonical src path.
            rm "${dest}"
            ln -v -s "${src}" "${dest}"
        else
            # Symlink points at a different file; don't clobber.
            warn "${dest} is a symlink to ${actual_src}, expected ${src}." "diff ${actual_src} ${src}"
        fi
    # Check for any existing path (regular file, directory, socket, FIFO, etc.) as destination.
    elif [ -e "${dest}" ]; then
        # Check for a regular file with content matching src; safe to replace with symlink.
        if [ -f "${dest}" ] && [ -f "${src}" ] && cmp -s "${dest}" "${src}"; then
            rm "${dest}"
            ln -v -s "${src}" "${dest}"
        else
            # Don't clobber.
            warn "${dest} exists but is not a symlink, expected symlink to ${src}." "diff ${dest} ${src}"
        fi
    # No entry at destination.
    else
        ln -v -s "${src}" "${dest}"
    fi
}

# Create symlink to project files in home directory.
DOT_STAR_ROOT="$(dirname $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P))"
DOT_STAR="${HOME}/.dot-star"

# Installing from a worktree silently repoints ~/.dot-star at the worktree
# and stamps the wrong commit, leaving the main checkout looking outdated.
if [ -f "${DOT_STAR_ROOT}/.git" ]; then
    set +x
    bold_red=$'\033[1;31m'
    cyan=$'\033[36m'
    reset=$'\033[0m'
    printf '%sERROR:%s install.sh was invoked from a worktree: %s\n' "${bold_red}" "${reset}" "${DOT_STAR_ROOT}" >&2
    if [[ "${DOT_STAR_ROOT}" == */.claude/worktrees/* ]]; then
        main_checkout="${DOT_STAR_ROOT%/.claude/worktrees/*}"
        printf '       %sRun: %s/install.sh%s\n' "${cyan}" "${main_checkout}" "${reset}" >&2
    else
        printf '       Run it from the main checkout instead.\n' >&2
    fi
    exit 1
fi

# Source the timer helper when profiling, else stub it out.
if [[ -n "${DOT_STAR_PROFILE:-}" ]]; then
    source "${DOT_STAR_ROOT}/bash/.timer.sh"
else
    bt_push() { :; }
    bt_pop() { :; }
    bt_comment() { :; }
fi

bt_push "install.sh"

bt_push "dot-star symlink"
# Remove stray /.dot-star at filesystem root from a prior empty-HOME run.
if [ -L "/.dot-star" ]; then
    unlink "/.dot-star"
fi

if [ -L "${DOT_STAR}" ]; then
    # Replace existing symlink.
    rm "${DOT_STAR}"
    ln -vs "${DOT_STAR_ROOT}" "${DOT_STAR}"
elif [ -e "${DOT_STAR}" ]; then
    # Refuse to clobber a real file or directory.
    warn "${DOT_STAR} exists and is not a symlink, refusing to clobber"
else
    # Create symlink.
    ln -vs "${DOT_STAR_ROOT}" "${DOT_STAR}"
fi
bt_pop

bt_push "claude config + dirs"
# Install Claude Code settings.
mkdir -p "${HOME}/.claude"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/settings.json" "${HOME}/.claude/settings.json"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"

# Migrate the legacy per-file style symlink now that styles live under
# ~/.claude/styles/.
if [ -L "${HOME}/.claude/CLAUDE_commit-message-style.md" ]; then
    unlink "${HOME}/.claude/CLAUDE_commit-message-style.md"
fi

# Install Claude Code skills, commands, hooks, and styles by symlinking the
# parent dirs. New files in the repo show up automatically, and any unexpected
# entry under ~/.claude/{skills,commands,hooks,styles} surfaces as untracked
# in `git status`. The first loop migrates the prior per-entry-symlink layout:
# drop legacy symlinks and the now-empty parent so the directory symlink can
# land.
for parent in "${HOME}/.claude/skills" "${HOME}/.claude/commands" "${HOME}/.claude/hooks" "${HOME}/.claude/styles"; do
    if [ -d "${parent}" ] && [ ! -L "${parent}" ]; then
        for legacy in "${parent}"/*; do
            if [ -L "${legacy}" ]; then
                unlink "${legacy}"
            fi
        done
        rmdir "${parent}" 2>/dev/null || true
    fi
done

ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/skills" "${HOME}/.claude/skills"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/commands" "${HOME}/.claude/commands"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/hooks" "${HOME}/.claude/hooks"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/styles" "${HOME}/.claude/styles"
bt_pop

bt_push "bootstrap snippets"
dotstar_header="# Begin dot-star bootstrap."
dotstar_footer="# End dot-star bootstrap."

setup_bootstrap() {
    filename="${1}"
    script="${2}"

    # Remove any existing bootstrap.
    while grep -q "${dotstar_header}" "${filename}" 2>/dev/null; do
        sed -i "" "/${dotstar_header}/,/${dotstar_footer}/d" "${filename}"
    done
    grep -v "${dotstar_footer}" "${filename}" >"${filename}.tmp" && mv "${filename}.tmp" "${filename}"

    echo -e "${dotstar_header}" >>"${filename}"
    echo -e "${script}" >>"${filename}"
    echo -e "${dotstar_footer}" >>"${filename}"
}

setup_bootstrap "${HOME}/.bash_profile" 'echo "if shopt -q login_shell; then
    [[ -r ~/.bashrc ]] && source ~/.bashrc
fi" >> "$HOME/.bash_profile"'

setup_bootstrap "${HOME}/.bashrc" 'echo "if shopt -q login_shell; then
    [[ -r ~/.dot-star/bash/.bash_profile ]] && source ~/.dot-star/bash/.bash_profile
fi" >> "$HOME/.bashrc"'
bt_pop

bt_push "rc file symlinks"
# Install inputrc.
ensure_symlink "${DOT_STAR}/bash/.inputrc" "${HOME}/.inputrc"

# Install colordiff configuration.
ensure_symlink "${DOT_STAR}/colordiff/.colordiffrc" "${HOME}/.colordiffrc"

ensure_symlink "${DOT_STAR}/screen/.screenrc" "${HOME}/.screenrc"
bt_pop

bt_push "ipython"
install_ipython() {
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        if ! command -v ipython >/dev/null; then
            brew install ipython
            brew link --overwrite ipython
        fi
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        if ! command -v ipython3 >/dev/null; then
            sudo apt-get install -y ipython3
        fi
    fi

    ipython profile create
    local config_file=~/.ipython/profile_default/ipython_config.py
    local header="# Begin dot-star ipython config."
    local footer="# End dot-star ipython config."
    local managed_lines=(
        "c.TerminalInteractiveShell.confirm_exit = False"
        "c.TerminalInteractiveShell.editing_mode = 'vi'"
        "c.TerminalInteractiveShell.editor = 'vi'"
    )

    # Drop any prior managed block AND any bare duplicates of managed lines
    # left over from when the install just `>>`-appended them every run.
    # `|`-delimited because BSD awk rejects newlines in `-v` values.
    local managed_joined
    managed_joined="$(
        IFS='|'
        echo "${managed_lines[*]}"
    )"
    local tmp_config="${config_file}.tmp"
    awk \
        -v header="${header}" \
        -v footer="${footer}" \
        -v managed="${managed_joined}" '
        BEGIN {
            n = split(managed, arr, "|")
            for (i = 1; i <= n; i++) drop[arr[i]] = 1
        }
        $0 == header { in_block = 1; next }
        $0 == footer { in_block = 0; next }
        in_block { next }
        $0 in drop { next }
        { print }
    ' "${config_file}" >"${tmp_config}" && mv "${tmp_config}" "${config_file}"

    {
        echo "${header}"
        printf '%s\n' "${managed_lines[@]}"
        echo "${footer}"
    } >>"${config_file}"
}
install_ipython
bt_pop

bt_push "post_install.sh"
# TODO: Consolidate post install script into install script.
# Run post installation script.
source "${DOT_STAR_ROOT}/script/post_install.sh"
bt_pop

if [ ${#WARNINGS[@]} -gt 0 ]; then
    bold_yellow=$'\033[1;33m'
    reset=$'\033[0m'
    set +x
    echo
    printf '%sWarnings:%s\n' "${bold_yellow}" "${reset}"
    for warning in "${WARNINGS[@]}"; do
        printf '  %s-%s %s\n' "${bold_yellow}" "${reset}" "${warning}"
    done
    echo
    _resume_xtrace
fi

# Stamp the installed commit so bash/.install_check.sh can detect later
# pulls that change install.sh or post_install.sh.
git -C "${DOT_STAR_ROOT}" rev-parse HEAD >"${HOME}/.dot-star-installed-commit"

bt_pop # install.sh

echo "✅ install complete"
