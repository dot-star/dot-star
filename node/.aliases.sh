alias_node() {
    # Lazy-load nvm when node is called.

    unalias node
    unalias npm
    unalias npx

    # ...because this is slow:
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm

    node "${@}"
}

alias_npm() {
    # Lazy-load node when npm is called.

    unalias node
    unalias npm
    unalias npx

    # ...because this is slow:
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm

    npm "${@}"
}

alias_npx() {
    # Lazy-load nvm when npx is called.

    unalias node
    unalias npm
    unalias npx

    # ...because this is slow:
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm

    npx "${@}"
}

alias node="alias_node"
alias npm="alias_npm"
alias npx="alias_npx"