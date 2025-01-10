alias hd="hexdump"

alias numeric="sort --numeric-sort"
alias numeric_sort="sort --numeric-sort"

_strip() {
    script="
import sys
for line in sys.stdin.read().splitlines():
    print(line.strip())
"
    cat - | python3 -c "${script}"
}

alias strip="_strip"
alias trim="_strip"

alias lower="tr '[:upper:]' '[:lower:]'"
alias upper="tr '[:lower:]' '[:upper:]'"

_first() {
    # Display first line of output.
    #
    # Usage:
    #  $ echo -e "1\n2\n3"
    #  1
    #  2
    #  3
    #
    #  $ echo -e "1\n2\n3" | first
    #  1
    head --lines=1
}
alias first="_first"

format_xml() {
    # Handle interactive without arguments (e.g. `format_xml').
    if [[ -t 0 ]] && [[ $# -eq 0 ]]; then
        script='
            $xml = trim(stream_get_contents(STDIN));

            $dom = new DOMDocument();
            $dom->preserveWhiteSpace = false;
            $dom->formatOutput = true;
            $dom->loadXML($xml);
            $out = $dom->saveXML();
            echo $out;'
        result="$(pbpaste | php -r "${script}")"
        exit_code="${?}"
        if [[ "${exit_code}" -ne 0 ]]; then
            echo "Error: command failed. Exit code: ${exit_code}"
        else
            tmp_xml_file="$(mktemp).xml"
            echo "${result}" > "${tmp_xml_file}"

            echo "Written to temporary XML file:\n${tmp_xml_file}"
            edit "${tmp_xml_file}"
        fi

    # Handle interactive with arguments (e.g. `format_xml data.xml').
    elif [[ -t 0 ]]; then
        file_path="${1}"
        script='
            $file_path = trim(stream_get_contents(STDIN));
            $xml = file_get_contents($file_path);

            $dom = new DOMDocument();
            $dom->preserveWhiteSpace = false;
            $dom->formatOutput = true;
            $dom->loadXML($xml);
            $out = $dom->saveXML();
            echo $out;'
        result=$(echo "${file_path}" | php -r "${script}")
        exit_code="${?}"
        if [[ "${exit_code}" -ne 0 ]]; then
            echo "Error: command failed. Exit code: ${exit_code}"
        else
            tmp_xml_file="$(mktemp).xml"
            echo "${result}" > "${tmp_xml_file}"

            echo "Written to temporary XML file:\n${tmp_xml_file}"
            edit "${tmp_xml_file}"
        fi

    # Handle non-interactive (e.g. `cat data.xml | format_xml').
    else
        script='
            $xml = trim(stream_get_contents(STDIN));

            $dom = new DOMDocument();
            $dom->preserveWhiteSpace = false;
            $dom->formatOutput = true;
            $dom->loadXML($xml);
            $out = $dom->saveXML();
            echo $out;'
        result="$(php -r "${script}" < /dev/stdin)"
        exit_code="${?}"
        if [[ "${exit_code}" -ne 0 ]]; then
            echo "Error: command failed. Exit code: ${exit_code}"
        else
            tmp_xml_file="$(mktemp).xml"
            echo "${result}" > "${tmp_xml_file}"

            echo "Written to temporary XML file:\n${tmp_xml_file}"
            edit "${tmp_xml_file}"
        fi
    fi
}
alias fx="format_xml"

htmlspecialchars_decode() {
    php -r '
        $stdin = stream_get_contents(STDIN);
        echo htmlspecialchars_decode($stdin);
    '
}
alias decode="htmlspecialchars_decode"
alias without_htmlspecialchars="htmlspecialchars_decode"

strip_tags() {
    script=$(cat <<"EOF"
        function remove_empty_lines($string) {
            $lines = explode("\n", $string);
            $lines = array_filter($lines, function($line) {
                return trim($line) !== '';
            });
            return implode("\n", $lines);
        }

        $stdin = stream_get_contents(STDIN);
        $without_tags = strip_tags($stdin);
        $without_empty_lines = remove_empty_lines($without_tags);
        echo $without_empty_lines;
EOF
)
    php -r "${script}"
}
alias without_tags="strip_tags"

with_newlines() {
    script=$(cat <<"EOF"
        $stdin = stream_get_contents(STDIN);
        $with_newlines = str_replace('\r\n', "\n", $stdin);
        echo $with_newlines;
EOF
)
    php -r "${script}"
}
alias newlines="with_newlines"

without_whitespace() {
    script=$(cat <<"EOF"
        function remove_line_whitespace($string) {
            $lines = explode("\n", $string);
            $lines = array_map('trim', $lines);
            return implode("\n", $lines);
        }

        $stdin = stream_get_contents(STDIN);
        $without_line_whitespace = remove_line_whitespace($stdin);
        echo $without_line_whitespace;
EOF
)
    php -r "${script}"
}

with_readability() {
    script=$(cat <<"EOF"
        $s = stream_get_contents(STDIN);
        $s = str_replace('><', '>' . "\n" . '<', $s);
        $s = str_replace('\n', "\n", $s);
        echo $s;
EOF
)
    php -r "${script}"
}
alias readability="with_readability"

escape_sed() {
    # Escape characters / and & for sed find and replace.
    printf '%s' "${1}" | sed 's/[\/&]/\\&/g'
}

find_and_replace() {
    find_str="$(escape_sed "${1}")"
    replace_str="$(escape_sed "${2}")"

    if sed v < /dev/null 2> /dev/null; then
        LC_ALL=C find . -type f -exec sed -i"" -e "s/${find_str}/${replace_str}/g" {} +
    else
        LC_ALL=C find . -type f -exec sed -i "" -e "s/${find_str}/${replace_str}/g" {} +
    fi
}
alias fr="find_and_replace"
