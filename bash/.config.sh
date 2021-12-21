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

compgen -G "/usr/local/Cellar/git/*/share/git-core/contrib/diff-highlight/diff-highlight" > /dev/null
if [ $? -ne 0 ]; then
    DIFF_HIGHLIGHT_INSTALLED=false
else
    DIFF_HIGHLIGHT_INSTALLED=true
fi
