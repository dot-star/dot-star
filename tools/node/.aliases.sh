unalias_node() {
    unalias node
    unalias npm
    unalias npx
    unalias nvm
}

load_nvm() {
    # Load nvm when this function is called.
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh" --no-use

    # Switch to the default version unless an nvm-installed node is already on PATH; the switch is the slow part.
    if [[ "$(command -v node)" != "${NVM_DIR:-$HOME/.nvm}"/* ]]; then
        nvm use default >/dev/null
    fi
}

alias_node() {
    # Lazy-load nvm when node is called.
    unalias_node

    # ...because this is slow:
    load_nvm

    node "${@}"
}

alias_npm() {
    # Lazy-load node when npm is called.
    unalias_node

    # ...because this is slow:
    load_nvm

    npm "${@}"
}

alias_npx() {
    # Lazy-load nvm when npx is called.
    unalias_node

    # ...because this is slow:
    load_nvm

    npx "${@}"
}

alias_nvm() {
    # Lazy-load nvm when nvm is called.
    unalias_node

    # ...because this is slow:
    load_nvm

    nvm "${@}"
}

alias node="alias_node"
alias npm="alias_npm"
alias npx="alias_npx"
alias nvm="alias_nvm"
