sasswatch() {
    # Usage:
    #   $ sasswatch
    #   sass [...] --watch "style.scss:style.css"
    #
    #   $ sasswatch "style.scss"
    #   sass [...] --watch "style.scss:style.css"
    #
    #   $ sasswatch my_style.scss
    #   sass [...] --watch "my_style.scss:my_style.css"

    local input=""
    local output=""

    if [[ "${#}" -eq 0 ]]; then
        input="$(find . -type f -name "*.scss" | fzf)"
    elif [[ "${#}" -eq 1 ]]; then
        input="${1}"
    fi

    input="${input/.css/}"
    input="${input/.scss/}"
    if [[ ! -z "${input}" ]] && [[ "${input}" != *".scss" ]]; then
        input="${input}.scss"
    fi

    if [[ -z "${output}" ]] && [[ ! -z "${input}" ]]; then
        output="${input}"
        output="${output/.css/}"
        output="${output/.scss/}"
        output="${output}.css"
    fi

    if [[ ! -z "${input}" ]]; then
        echo "input: ${input}"
    fi

    if [[ ! -z "${output}" ]]; then
        echo "output: ${output}"
    fi

    if [[ ! -z "${input}" ]] && [[ ! -z "${output}" ]]; then
        set -x
        sass \
            --no-source-map \
            --style="expanded" \
            --watch \
            "${input}:${output}"
        set +x
    fi
}
alias sw="sasswatch"
