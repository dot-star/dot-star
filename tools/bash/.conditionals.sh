conditional_b() {
    if [[ $# -eq 0 ]]; then
        bell
    else
        bak "${@}"
    fi
}
alias b="conditional_b"
