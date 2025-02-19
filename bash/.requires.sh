_require_jq() {
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

