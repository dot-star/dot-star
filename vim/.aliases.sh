# Vim aliases

_vim () {
    param_count="${#}"
    if [ "${param_count}" -ge 1 ]; then
        for param in "$@"; do
            if [ ! -d "${param}" ]; then
                file="${param}"
                if [ ! -e "${file}" ]; then
                    read -p "File \"${file}\" doesn't exist. Create file? " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        touch "${file}"
                    fi
                fi
            fi
        done
    fi

    if $ssh; then
        \vim -p "$@"
    elif which "gvim" &> /dev/null; then
        xdotool=$(which xdotool)
        if [ -z "${xdotool}" ]; then
            echo -e '\x1b[0;93mWARNING\x1b[0m: xdotool does not seem to be installed.'
        else
          window_id=$(xdotool search --name ") - GVIM")
          xdotool windowactivate "${window_id}"
        fi

        gvim -p --remote-tab-silent "$@"
    elif which "mvim" &> /dev/null; then
        open -a MacVim "$@"
    else
        \vim -p "$@"
    fi
}

alias v="_vim"
alias vi="_vim"
alias vim="_vim"

if which "mvim" &> /dev/null; then
    alias mvim="open -a MacVim"
fi

alias vimrc="_vim ~/.vimrc"
