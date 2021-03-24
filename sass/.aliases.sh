sasswatch() {
    # Usage:
    #   $ sasswatch
    #   sass [...] --watch "style.scss:style.css"
    #
    #   $ sasswatch "style.scss:style.css"
    #   sass [...] --watch "style.scss:style.css"
    #
    #   $ sasswatch my_style
    #   sass [...] --watch "my_style.scss:my_style.css"
    #
    #   $ sasswatch my_style.css
    #   sass [...] --watch "my_style.scss:my_style.css"
    #
    #   $ sasswatch my_style.scss
    #   sass [...] --watch "my_style.scss:my_style.css"

    local command
    if [[ "${#}" -eq 0 ]]; then
        command="style.scss:style.css"
    elif [[ "${#}" -eq 1 ]] && [[ "${1}" == *":"* ]]; then
        command="${1}"
    elif [[ "${#}" -eq 1 ]] && [[ "${1}" != *":"* ]]; then
        arg="${1}"
        arg="${arg/.css/}"
        arg="${arg/.scss/}"
        command="${arg}.scss:${arg}.css"
    fi

    sass \
        --no-source-map="none" \
        --style="expanded" \
        --watch "${command}"
}
