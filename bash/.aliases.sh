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
            --ignore=.swp \
            --ignore=.*.swp \
            --ignore=.DS_Store \
            --ignore=.git \
            --ignore=.gitignore \
            --ignore=.sass-cache \
            --ignore=.svn \
            --literal \
            --time-style=local \
            -X \
            -l \
            -v
    else
        # OS X `ls`
        ls -l -F -G
    fi
}

alias grep="grep --color --line-number"
alias h="history"
alias j="jobs"
alias l="_ls"
alias m="mate ."
alias o="open"
alias oo="open ."
alias s="subl ."
alias t="tree"

alias ip="ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //' | sort | sed 's/\('$(ipconfig getifaddr en1)'\)/\1 [LOCAL]/'"

alias dotstar="cd ${HOME}/.dot-star && l"
alias extra="vim ${HOME}/.dot-star/bash/extra.sh"
