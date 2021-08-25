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

if [ -d "/usr/local/Cellar/git/"*"/share/git-core/contrib/diff-highlight/diff-highlight" ]; then
    DIFF_HIGHLIGHT_INSTALLED=false
else
    DIFF_HIGHLIGHT_INSTALLED=true
fi
