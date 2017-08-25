# Use coreutils from brew. Install via `$ brew install coreutils'.
which brew &> /dev/null
if [[ $? -eq 0 ]]; then
    # Use string path as this brew command is slow.
    # coreutils_path=$(brew --prefix coreutils)
    coreutils_path="/usr/local/opt/coreutils"
    export PATH="${coreutils_path}/libexec/gnubin:${PATH}"
    export MANPATH="${coreutils_path}/libexec/gnuman:${MANPATH}"
fi
