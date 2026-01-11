alias_npx() {
    # Lazy-load nvm when npx is called.

    # type npx
    unalias npx
    # type npx

    # ...because this is slow:
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm

    npx "${@}"
}
alias npx="alias_npx"