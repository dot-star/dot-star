alias_node() {
    # Lazy-load nvm when node is called.

    unalias node
    unalias npx

    # ...because this is slow:
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm

    node "${@}"
}

alias_npx() {
    # Lazy-load nvm when npx is called.

    unalias npx
    unalias node

    # ...because this is slow:
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm

    npx "${@}"
}

alias node="alias_node"
alias npx="alias_npx"