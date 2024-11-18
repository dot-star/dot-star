conditional_b() {
    if [[ $# -eq 0 ]]; then
        branches
    else
        bak "${@}"
    fi
}
alias b="conditional_b"
