# Vim aliases

_vim() {
    # FIXME: Only proceed to open files that exist or were created. (e.g. $ v foo File "foo.txt" doesn't exist. Create
    # file? n The file /path/to/foo.txt does not exist.)
    files="${@}"
    for filename in "${files}"; do
        # Not (exists and is a directory).
        if [[ ! -d "${filename}" ]]; then
            # Not (file exists).
            if [[ ! -e "${filename}" ]]; then
                read -p "File \"${filename}\" doesn't exist. Create file? " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    touch "${filename}"
                fi
            fi
        fi
    done

    if is_ssh; then
        \vim -p "${files}"
    elif which "mvim" &> /dev/null; then
        if [[ $# -eq 0 ]]; then
            mvim
        else
            mvim --remote-tab-silent "${files}"
        fi
    elif which "gvim" &> /dev/null; then
        xdotool=$(which xdotool)
        if [ -z "${xdotool}" ]; then
            echo -e '\x1b[0;93mWARNING\x1b[0m: xdotool does not seem to be installed.'
        else
          window_id=$(xdotool search --name ") - GVIM")
          if [ ! -z "${window_id}" ]; then
            xdotool windowactivate "${window_id}"
          fi
        fi

        (gvim -f -p --remote-tab-silent "${files}" &> /dev/null &)
    else
        \vim -p "${files}"
    fi
}

alias v="_vim"
alias vi="_vim"
alias vim="_vim"

alias vimrc="_vim ~/.vimrc"

# Use vi-style command line editing.
set -o vi

# Use vim as the default editor.
export EDITOR="vim"
export VISUAL="vim"

if which "mvim" &> /dev/null; then
    # Background MacVim when using visual selection on the command line.
    export VISUAL="mvim -f"
fi
