# Vim aliases

alias_vim() {
    ask_to_create_files "${@}"

    if is_ssh; then
        \vim -p "${@}"
    elif which "mvim" &> /dev/null; then
        if [[ $# -eq 0 ]]; then
            mvim
        else
            # The following did not work:
            #   $ mvim "${@}"
            #   Fails to open files tabs when more than 1 file is specified.
            #
            #   $ mvim --remote-tab-silent "${@}"
            #   Fails to open files on first run. However, running the same command again correctly opens files in tabs.

            # Open tabs for each file in MacVim.
            # Be sure to set MacVim > Preferences > Open files from applications: in the current window with a tab for
            # each file so that subsequent files are opened in new tabs in the existing window.
            open -a "MacVim.app" "${@}"
        fi
    elif which "gvim" &> /dev/null; then
        xdotool=$(which xdotool)
        if [[ -z "${xdotool}" ]]; then
            echo -e '\x1b[0;93mWARNING\x1b[0m: xdotool does not seem to be installed.'
        else
          window_id=$(xdotool search --name ") - GVIM")
          if [[ ! -z "${window_id}" ]]; then
            xdotool windowactivate "${window_id}"
          fi
        fi

        (gvim -f -p --remote-tab-silent "${@}" &> /dev/null &)
    else
        \vim -p "${@}"
    fi
}

alias v.="edit ."
alias v="edit"
alias vi="alias_vim"
alias vim="alias_vim"
alias vpy="edit *.py"

alias vimrc="alias_vim ~/.vimrc"

# Use vi-style command line editing.
set -o vi

# Use vim as the default editor.
export EDITOR="vim"
export VISUAL="vim"

if which "mvim" &> /dev/null; then
    export EDITOR="mvim"

    # Background MacVim when using visual selection on the command line.
    export VISUAL="mvim -f"
fi
