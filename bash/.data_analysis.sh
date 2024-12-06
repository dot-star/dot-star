alias_before_after() {
    # Edit files to run a comparison and display live diff.

    local before_file_name=~"/Desktop/before.txt"
    local after_file_name=~"/Desktop/after.txt"

    touch "${before_file_name}" "${after_file_name}"
    edit "${before_file_name}" "${after_file_name}"

    cd ~/Desktop &&
        while :; do
            wd
            exit_code="${?}"
            if [[ "${exit_code}" -eq 0 ]]; then
                diff --unified "${before_file_name}" "${after_file_name}" |
                    diff_highlight |
                    colordiff
            else
                return "${exit_code}"
            fi
        done
}
alias ab="alias_before_after"
alias ba="alias_before_after"

from_clipboard() {
    # Usage:
    #   $ from_clipboard | jq
    #   $ fc | jq

    # TODO: Add support for non-macos
    pbpaste
}
alias fc="from_clipboard"

clipboard() {
    # Remove trailing newline from stdin and copy it to the clipboard.
    if which "xsel" &> /dev/null; then
        perl -p -e 'chomp if eof' | xsel --clipboard
    elif which "pbcopy" &> /dev/null; then
        perl -p -e 'chomp if eof' | pbcopy
    fi
}
alias clip="clipboard"
alias copy="clipboard"

count_lines() {
    # $ echo -n "a\nb\nc" | wc -l
    # 2
    #
    # $ echo -n "a\nb\nc" | awk 'NF' | wc -l
    # 3
    if which "gwc" &> /dev/null; then
        awk 'NF' |
        gwc --lines
    else
        awk 'NF' |
        wc --lines
    fi
}
alias lines_count="count_lines"
alias wcl="count_lines"

difference() {
    if [[ -t 1 ]] && $COLORDIFF_INSTALLED && $DIFF_HIGHLIGHT_INSTALLED; then
        command='diff --exclude=".git" --recursive --unified "'"${1}"'" "'"${2}"'" | diff_highlight | colordiff | less -R'
    elif [[ -t 1 ]] && $COLORDIFF_INSTALLED; then
        command='diff --exclude=".git" --recursive --unified "'"${1}"'" "'"${2}"'" | colordiff | less -R'
    elif [[ -t 1 ]]; then
        command='diff --exclude=".git" --recursive --unified "'"${1}"'" "'"${2}"'" | less -R'
    else
        command='diff --exclude=".git" --recursive --unified "'"${1}"'" "'"${2}"'"'
    fi

    echo "${command}"
    eval $command
}

_diff_line_numbers() {
    # Usage:
    #   diff_line_numbers $filename1 $start1 $stop1 $filename2 $start2 $stop2
    #   diff_line_numbers file1.py 80 142 file2.py 144 229
    #
    # TODO: Add support for
    #   diff_line_numbers $start1 $stop1 $start2 $stop2 $filename

    if [[ $# == 0 ]]; then
        echo "Syntax:"
        echo "$ diff_line_numbers filename1 start stop filename2 start stop"
        return
    fi

    file_1_name="${1}"
    file_1_start="${2}"
    file_1_end="${3}"

    file_2_name="${4}"
    file_2_start="${5}"
    file_2_end="${6}"

    diff \
        --recursive \
        --unified \
        <(sed -n "${file_1_start}","${file_1_end}p" "${file_1_name}") \
        <(sed -n "${file_2_start}","${file_2_end}p" "${file_2_name}") |
        if $DIFF_HIGHLIGHT_INSTALLED; then
            diff_highlight
        else
            cat
        fi |
        if $COLORDIFF_INSTALLED; then
            colordiff
        else
            cat
        fi |
        less -R
}
alias diff_line_numbers="_diff_line_numbers"

require_jq() {
    command jq --help &> /dev/null
    exit_code="${?}"

    if [[ "${exit_code}" -eq 127 ]]; then
        if [[ "${OSTYPE}" == "darwin"* ]]; then
            brew install jq
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get install jq
        fi
    fi
}

# Wrap jq command to allow debugging a jq filter interactively.
# To use, run `jq $filename'. Press return when the desired filter has been
# entered. The entered filter will be displayed and put in the clipboard for
# immediate use.
alias_jq() {
    require_jq

    export JQ_COLORS="1;37:0;33:0;33:0;31:0;32:1;39:1;39"

    if [[ -f "/opt/homebrew/bin/jq" ]]; then
        jq_bin="/opt/homebrew/bin/jq"

    elif [[ -f "/usr/local/bin/jq" ]]; then
        jq_bin="/usr/local/bin/jq"

    else
        jq_bin=""
    fi

    if [[ -z "${jq_bin}" ]]; then
        echo "Error: jq not found"
        which jq
        return
    fi

    # Detect when a file has been passed to jq.
    if [[ $# -eq 1 ]] && [[ -f "${1}" ]]; then
        use_preview=true
        file_path="${1}"

    # Handle non-interactive shell (e.g. "$ cat response.json | jq").
    elif [[ ! -t 0 ]]; then
        use_preview=true
        file_path="$(mktemp).json"

        # Read stdin into variable.
        local input="$(< /dev/stdin)"

        # Handle formatting the string representation of a python dictionary as
        # well.
        #
        # Both supported:
        #   $ echo "{'errors': [{'override': None, 'message': 'An error occurred.', 'code': None}]}" | jq
        #   $ echo '{"errors": [{"override": null, "message": "An error occurred.", "code": null}]}' | jq
        script="
import ast
import json
import sys

stdin = sys.stdin.read()
try:
    result = ast.literal_eval(stdin)
except ValueError:
    pass
except SyntaxError:
    pass
else:
    formatted = json.dumps(result, indent=4, sort_keys=False)
    print(formatted)
"
        formatted="$(echo -E "${input}" | python3 -c "${script}")"
        exit_code="${?}"
        # echo "exit_code: ${exit_code}"
        if [[ "${exit_code}" -eq 0 ]] && [[ ! -z "${formatted}" ]]; then
            input="${formatted}"
        fi

        # Write stdin to temporary file.
        # Use -E to avoid duplicate newlines in the resulting file.
        echo -E "${input}" > "${file_path}"

    else
        use_preview=false
    fi

    # echo "input: <<<${input}>>>"
    # echo "use_preview: ${use_preview}"

    if [[ $use_preview ]]; then
        # echo "using preview"

        # Start fzf finder with an initial query of "." to avoid error on
        # initial load:
        #   jq: error: Top-level program not given (try ".")
        #   jq: 1 compile error
        local query="."

        # Open an interactive view for entering a jq filter and viewing the
        # result in the fzf preview window.
        jq_filter=$(echo "" |
            fzf \
                --info=hidden \
                --preview "cat \"${file_path}\" | jq --color-output {q}" \
                --preview-window=up:100,wrap \
                --print-query \
                --query="${query}"
        )
        if [[ -z "${jq_filter}" ]]; then
            echo "(no filter submitted)"
            return
        fi

        # Display a preview of the file using the selected jq filter.
        echo "$ jq -C \"${jq_filter}\" \"${file_path}\" | head"
        "${jq_bin}" -C "${jq_filter}" "${file_path}" | head

        # Put the selected jq filter in the clipboard.
        echo "${jq_filter}" | clip

        # Display the selected jq filter.
        echo ""
        echo "jq filter (also in clipboard):"
        echo "${jq_filter}"

    else
        # echo "not using preview"

        "${jq_bin}" "${@}"
    fi
}
alias jq="alias_jq"
alias pretty="alias_jq"
