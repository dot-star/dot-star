alias zshrc="vim ${HOME}/.zshrc"

# Avoid duplicate history entries.
setopt hist_ignore_all_dups

# Recover from a removed cwd: cd up to the nearest existing ancestor when PWD
# no longer exists, and re-emit OSC 7 so Terminal.app's "Same Working Directory"
# tracker forgets the dead path. Without this, removing the cwd (e.g. wtd, wtp,
# manual `git worktree remove`) leaves the shell stuck in a phantom dir and
# pastes `## cd <dead-path> ##` into every new tab opened from here.
recover_dead_cwd() {
    if [[ -d "${PWD}" ]]; then
        return
    fi
    local target="${PWD}"
    while [[ -n "${target}" && ! -d "${target}" ]]; do
        target="${target%/*}"
    done
    cd "${target:-/}"

    # omz_termsupport_cwd already ran earlier in this precmd chain with the
    # dead PWD. Re-emit now so OSC 7 reflects the recovered cwd.
    if typeset -f omz_termsupport_cwd >/dev/null; then
        omz_termsupport_cwd
    fi
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd recover_dead_cwd

# Count each command line run, so `rc_push_guard` can tell whether `s` ran
# right before `pus`. Preexec skips empty lines, so a bare Enter doesn't count.
count_command_lines() {
    DOTSTAR_COMMAND_LINE_COUNT=$((${DOTSTAR_COMMAND_LINE_COUNT:-0} + 1))
}
add-zsh-hook preexec count_command_lines

# Show version control status at a new shell's first prompt, so a tab or split
# opened inside a repo (e.g. a worktree) skips the habitual `s`.
status_on_first_prompt() {
    local status_start="${EPOCHREALTIME}"

    add-zsh-hook -d precmd status_on_first_prompt
    unfunction status_on_first_prompt

    if is_git; then
        conditional_s
    fi

    # Credit the status run back to zsh's startup timer, so a requested `s`
    # never reads as a slow start.
    if [[ -n "${zsh_startup_start}" ]]; then
        zsh_startup_start=$((zsh_startup_start + EPOCHREALTIME - status_start))
    fi
}
add-zsh-hook precmd status_on_first_prompt
