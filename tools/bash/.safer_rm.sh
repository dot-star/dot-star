safer_rm() {
    # Prohibited: rm *
    # Prohibited: rm * foo.txt
    # Prohibited: rm foo.txt *
    # Allowed:    rm foo.txt
    # Allowed:    rm foo*.txt

    # Pick untracked files to remove with fzf when no arguments are given.
    if [[ "${#}" -eq 0 ]]; then
        untracked_files="$(git ls-files --others --exclude-standard 2>/dev/null)"
        # Stop when not in a git repository or there are no untracked files.
        if [[ -z "${untracked_files}" ]]; then
            echo "(no untracked files to remove)"
            return
        fi

        selected_files="$(
            echo "${untracked_files}" |
                fzf \
                    --multi \
                    --preview="cat {}" \
                    --prompt="rm untracked: "
        )"
        # Stop when nothing was selected (e.g. canceled with ESC).
        if [[ -z "${selected_files}" ]]; then
            echo "(no file selected)"
            return
        fi

        # Collect the picks into an array, reading line by line so paths with
        # spaces stay intact.
        files_to_remove=()
        while IFS= read -r selected_file; do
            files_to_remove+=("${selected_file}")
        done <<<"${selected_files}"

        command rm "${files_to_remove[@]}"
        return
    fi

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
