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

    # Self-heal a missing virtualenv: create it from the current pyenv version
    # before activating, so `pyenv activate <env>` works after the env is gone.
    if [[ "${1}" == "activate" ]] && [[ -n "${2}" ]] && ! command pyenv virtualenv-prefix "${2}" >/dev/null 2>&1; then
        echo "pyenv: virtualenv \"${2}\" not found; creating it from $(command pyenv version-name)"
        command pyenv virtualenv "${2}"
    fi

    pyenv "${@}"
}

alias pyenv="alias_pyenv"

pyenv_deactivate() {
    if [[ -n "${VIRTUAL_ENV}" ]]; then
        deactivate
    fi
}

alias deactivate="pyenv_deactivate"
