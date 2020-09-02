sasswatch() {
    # Usage:
    #   $ sasswatch
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

    if [[ "${#}" -eq 1 ]]; then
        arg="${1}"
        arg="${arg/.css/}"
        arg="${arg/.scss/}"
        command="${arg}.scss:${arg}.css"
    else
        command="style.scss:style.css"
    fi

    sass \
        --no-source-map="none" \
        --style="expanded" \
        --watch "${command}"
}
