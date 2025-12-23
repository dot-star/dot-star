python_version() {
    python3 -V

    echo -e "\nwhich python3:"
    which python3
}
alias pyv="python_version"

update_pip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        set -x
        brew upgrade python
        set +x
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        set -x
        python3 -m pip install --upgrade pip
        set +x
    else
        echo "Unsupported OS type: ${OSTYPE}"
        return 1
    fi
}
alias pipup="update_pip"
alias upip="update_pip"
alias uppip="update_pip"