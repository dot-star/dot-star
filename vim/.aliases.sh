# Vim aliases

alias_vim() {
    # FIXME: Only proceed to open files that exist or were created. (e.g. $ v foo File "foo.txt" doesn't exist. Create
    # file? n The file /path/to/foo.txt does not exist.)

    create_all_subsequent_files=false
    for filename in "${@}"; do
        # Skip parameter specified for setting cursor line position.
        if [[ "${filename}" == "+"* ]]; then
          continue
        fi

        # Not (exists and is a directory).
        if [[ ! -d "${filename}" ]]; then
            # Not (file exists).
            if [[ ! -e "${filename}" ]]; then

                if $create_all_subsequent_files; then
                    response="y"
                else
                    response="$(display_confirm_prompt "File \"${filename}\" doesn't exist. Create file? [y/n/a]")"
                    if [[ "${response}" =~ ^[Aa]$ ]]; then
                        create_all_subsequent_files=true
                        response="y"
                    fi
                fi
                # echo "response: ${response}"

                if [[ "${response}" =~ ^[Yy]$ ]]; then
                    # echo "creating file: ${filename}"
                    touch "${filename}"
                else
                    echo "not creating file: ${filename}"
                fi
            fi
        fi
    done

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

alias v.="alias_vim ."
alias v="edit"
alias vi="alias_vim"
alias vim="alias_vim"

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
