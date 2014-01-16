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
            --ignore=.hg \
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
                --ignore=.hg \
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
        ls -a -l -F -G
    fi
}

_grep() {
    grep \
        --color \
        --exclude-dir=".git" \
        --exclude-dir=".hg" \
        --exclude-dir=".svn" \
        --line-number \
        "$@"
}
alias grep="_grep"

alias h="history"
alias j="jobs"
alias l="_ls"
alias m="mate ."
alias o="_open"
alias oo="_open ."
alias s="subl ."
alias t="tree"

alias addrepo="sudo add-apt-repository"
alias autoclean="sudo apt-get autoclean"
alias autoremove="sudo apt-get autoremove"
alias clean="sudo apt-get clean"
alias distupgrade="sudo apt-get dist-upgrade"
alias upgrade="sudo apt-get upgrade"

_open() {
    open "$@" &> /dev/null
    if [ ! $? -eq 0 ]; then
        nautilus "$@"
    fi
}

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

alias bashprofile="vim ${HOME}/.bash_profile"
alias bashrc="vim ${HOME}/.bashrc"
