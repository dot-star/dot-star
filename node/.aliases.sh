unalias_node() {
    unalias node
    unalias npm
    unalias npx
}

load_nvm() {
    # Load nvm when this function is called.
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
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

alias node="alias_node"
alias npm="alias_npm"
alias npx="alias_npx"