# Set default editor.
export EDITOR="vim"
export VISUAL="vim"

if which "mvim" &> /dev/null; then
    export EDITOR="mvim"

    # Background MacVim when using visual selection on the command line.
    export VISUAL="mvim -f"
fi

colordiff="$(which colordiff)"
if [[ -z "${colordiff}" ]]; then
    COLORDIFF_INSTALLED=false
else
    COLORDIFF_INSTALLED=true
fi

diff_so_fancy="$(which diff-so-fancy)"
if [[ -z "${diff_so_fancy}" ]]; then
    DIFF_SO_FANCY_INSTALLED=false
else
    DIFF_SO_FANCY_INSTALLED=true
fi

DIFF_HIGHLIGHT_INSTALLED=false
if which diff-highlight &> /dev/null; then
    DIFF_HIGHLIGHT_INSTALLED=true
else
    compgen &> /dev/null
    if [[ $? -ne 127 ]]; then
        compgen -G "/usr/local/Cellar/git/*/share/git-core/contrib/diff-highlight/diff-highlight" > /dev/null
        if [ $? -eq 0 ]; then
            DIFF_HIGHLIGHT_INSTALLED=true
        fi
    fi
fi

# echo "COLORDIFF_INSTALLED: ${COLORDIFF_INSTALLED}"
# echo "DIFF_HIGHLIGHT_INSTALLED: ${DIFF_HIGHLIGHT_INSTALLED}"
# echo "DIFF_SO_FANCY_INSTALLED: ${DIFF_SO_FANCY_INSTALLED}"
