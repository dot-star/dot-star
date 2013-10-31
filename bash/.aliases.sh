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
            --ignore=.sass-cache \
            --ignore=.svn \
            --ignore=.swp \
            --literal \
            --time-style=local \
            -X \
            -l \
            -v \
            2> /dev/null

        if [[ $? -ne 0 ]]; then
            ls \
                --almost-all \
                --classify \
                --color=always \
                --hide-control-chars \
                --human-readable \
                --ignore=*.pyc \
                --ignore=.*.swp \
                --ignore=.DS_Store \
                --ignore=.git \
                --ignore=.sass-cache \
                --ignore=.svn \
                --ignore=.swp \
                --literal \
                --time-style=local \
                -X \
                -l \
                -v
        fi
    else
        # OS X `ls`
        ls -l -F -G
    fi
}

_grep() {
    grep \
        --color \
        --exclude-dir=".git" \
        --exclude-dir=".svn" \
        --line-number \
        "$@"
}
alias grep="_grep"

alias h="history"
alias j="jobs"
alias l="_ls"
alias m="mate ."
alias o="open"
alias oo="open ."
alias s="subl ."
alias t="tree"

_ip() {
    if [ -x /sbin/ifconfig ]; then
        /sbin/ifconfig
    else
        ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //' | sort | sed 's/\('$(ipconfig getifaddr en1)'\)/\1 [LOCAL]/'
    fi
}
alias ip="_ip"

alias dotstar="cd ${HOME}/.dot-star && l"
alias extra="vim ${HOME}/.dot-star/bash/extra.sh"
