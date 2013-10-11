# Use coreutils from brew. Install via `$ brew install coreutils'.
which brew &> /dev/null
if [[ $? -eq 0 ]]; then
    export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
fi
