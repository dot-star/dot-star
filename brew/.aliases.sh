# Make commands available without needing the "g" prefix (e.g. gls -> ls, ggrep -> grep).
# Use coreutils from brew. Install via `$ brew install coreutils'.
# Use grep from brew. Install via `$ brew install grep'.
which brew &> /dev/null
if [[ $? -eq 0 ]]; then
    local homebrew_prefix="${HOMEBREW_PREFIX}"
    if [[ -z "${HOMEBREW_PREFIX}" ]]; then
        homebrew_prefix="/usr/local"
    fi

    # Use string path as this brew command is slow:
    #   coreutils_path=$(brew --prefix coreutils)
    coreutils_path="${homebrew_prefix}/opt/coreutils"

    export PATH="${coreutils_path}/libexec/gnubin:${PATH}"
    export PATH="${homebrew_prefix}/opt/grep/libexec/gnubin:$PATH"
    export MANPATH="${coreutils_path}/libexec/gnuman:${MANPATH}"

    # Increase verbosity of brew commands. Useful for seeing some progress when calling `brew update' on a slower
    # connection.
    #
    # Before:
    #   $ brew update
    # After:
    #   $ brew update --debug --verbose
    _original_brew="$(which brew)"
    _brew() {
        set -x
        "${_original_brew}" $@ --debug --verbose
        set +x
    }

    alias brew="_brew"
fi
