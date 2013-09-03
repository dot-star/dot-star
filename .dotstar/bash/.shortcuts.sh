# Shortcuts

_ls(){
    clear
    if ls --color > /dev/null 2>&1; then
        # GNU `ls`
        ls \
            --almost-all \
            --classify \
            --color=always \
            --group-directories-first \
            --hide-control-chars \
            --human-readable \
            --ignore=*.pyc \
            --ignore=.*.swp \
            --ignore=.DS_Store \
            --ignore=.git \
            --ignore=.gitignore \
            --ignore=.svn \
            --literal \
            --time-style=local \
            -X \
            -l \
            -v
    else
        # OS X `ls`
        ls -G
    fi
}

alias h="history"
alias j="jobs"
alias l="_ls"
alias m="mate ."
alias o="open"
alias oo="open ."
alias s="subl ."
alias t="tree"
alias v="vim"
