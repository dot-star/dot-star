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

load_pyenv() {
    # Load pyenv and its virtualenv plugin into the shell when this is called.
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
}

alias_pyenv() {
    # Lazy-load pyenv when pyenv is called, so `pyenv activate <env>` works
    # without remembering to source the init lines, and startup stays fast.
    unalias pyenv

    # ...because this is slow:
    load_pyenv

    pyenv "${@}"
}

alias pyenv="alias_pyenv"

pyenv_deactivate() {
    if [[ -n "${VIRTUAL_ENV}" ]]; then
        deactivate
    fi
}

alias deactivate="pyenv_deactivate"
