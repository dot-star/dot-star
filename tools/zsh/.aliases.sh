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
