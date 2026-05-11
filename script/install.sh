#!/usr/bin/env bash
set -x

if [[ -z "${HOME:-}" ]]; then
    echo "HOME must be set" >&2
    exit 1
fi

WARNINGS=()

# Append a warning to WARNINGS and emit it to stderr without xtrace noise.
# Optional second arg is a suggested command, shown on its own line in cyan.
warn() {
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
    echo "WARNING: ${message}" >&2
    # Print the suggested command on its own line if provided.
    if [ -n "${suggested_command}" ]; then
        printf '    %sRun: %s%s\n' "${cyan}" "${suggested_command}" "${reset}" >&2
    fi
    set -x
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

# Install Claude Code settings.
mkdir -p "${HOME}/.claude"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/settings.json" "${HOME}/.claude/settings.json"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"
ensure_symlink "${DOT_STAR}/ai/files/Users/user/.claude/commit-message-style.md" "${HOME}/.claude/commit-message-style.md"

# Install Claude Code skills, commands, and hooks by symlinking the parent
# dirs. New files in the repo show up automatically, and any unexpected entry
# under ~/.claude/skills, ~/.claude/commands, or ~/.claude/hooks surfaces as
# untracked in `git status`. The first loop migrates the prior
# per-entry-symlink layout: drop legacy symlinks and the now-empty parent so
# the directory symlink can land.
for parent in "${HOME}/.claude/skills" "${HOME}/.claude/commands" "${HOME}/.claude/hooks"; do
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

# Install inputrc.
ensure_symlink "${DOT_STAR}/bash/.inputrc" "${HOME}/.inputrc"

# Install colordiff configuration.
ensure_symlink "${DOT_STAR}/colordiff/.colordiffrc" "${HOME}/.colordiffrc"

ensure_symlink "${DOT_STAR}/screen/.screenrc" "${HOME}/.screenrc"

install_ipython() {
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        brew install ipython
        # Re-link in case a prior install left the keg unlinked.
        brew link --overwrite ipython
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        sudo apt-get install -y ipython3
    fi

    ipython profile create
    echo -e "c.TerminalInteractiveShell.confirm_exit = False\n" >>~/.ipython/profile_default/ipython_config.py
    echo -e "c.TerminalInteractiveShell.editing_mode = 'vi'\n" >>~/.ipython/profile_default/ipython_config.py
    echo -e "c.TerminalInteractiveShell.editor = 'vi'\n" >>~/.ipython/profile_default/ipython_config.py
}
install_ipython

# TODO: Consolidate post install script into install script.
# Run post installation script.
source "${DOT_STAR_ROOT}/script/post_install.sh"

if [ ${#WARNINGS[@]} -gt 0 ]; then
    set +x
    echo
    echo "warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - ${warning}"
    done
    echo
    set -x
fi

echo "✅ install complete"
