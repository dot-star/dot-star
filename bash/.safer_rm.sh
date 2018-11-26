safer_rm(){
    # Prohibited: rm *
    # Prohibited: rm * foo.txt
    # Prohibited: rm foo.txt *
    # Allowed:    rm foo.txt
    # Allowed:    rm foo*.txt

    dangerous_wildcard_detected=false
    for arg in "${@}"; do
        if [[ "${arg}" == "*" ]]; then
            dangerous_wildcard_detected=true
            break
        fi
    done

    if $dangerous_wildcard_detected; then
        echo "cowardly refusing to run \`rm' with a dangerous wildcard"
        return 1
    fi

    # Turn on filename expansion (globbing).
    set +f

    args=()
    for arg in "${@}"; do
        if [[ "${arg}" =~ " " ]]; then
            args+=("${arg}")
        else
            args+=(${arg})
        fi
    done

    command rm "${args[@]}"
}
alias rm="set -f && safer_rm"
