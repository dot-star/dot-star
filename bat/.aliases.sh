# Wrap `cat' with `bat' for syntax-highlighted interactive output.
pretty_cat() {
    local bat_cmd
    # Prefer `bat', falling back to Debian's renamed `batcat' binary.
    if command -v "bat" &>/dev/null; then
        bat_cmd="bat"
    elif command -v "batcat" &>/dev/null; then
        bat_cmd="batcat"
    else
        bat_cmd=""
    fi

    # Pretty-print interactively; pass through plain cat for pipes and scripts.
    if [[ -t 1 ]] && [[ -n "${bat_cmd}" ]]; then
        "${bat_cmd}" --style=plain "${@}"
    else
        command cat "${@}"
    fi
}
alias cat="pretty_cat"
