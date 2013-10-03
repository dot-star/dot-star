# Git Aliases

alias g="git"

alias add="git add"
alias branch="rc_branch"
alias checkout="rc_checkout"
alias clone="git clone"
alias commit="git commit"
alias dcommit="git svn dcommit"
alias default="rc_master"
alias df="rc_diff"
alias drop="git_stash_drop"
alias fetch="git fetch"
alias filemode="git config core.filemode false"
alias list="git stash list"
alias log="git log"
alias master="rc_master"
alias pop="git stash pop"
alias pull="rc_pull"
alias push="git push"
alias st="rc_status"
alias stash="git stash"
alias tag="git tag"
alias tags="git tag --list"

git_stash_drop() {
    # Drop the specified git stash.
    # Usage: drop 0
    git stash drop "stash@{$@}"
}

is_git() {
    git log -1 &> /dev/null
    if [ $? -eq 0 ]; then
        return 0
    fi
    return 1
}

is_svn() {
    svn log --limit=1 &> /dev/null
    if [ $? -eq 0 ]; then
        return 0
    fi
    return 1
}

is_hg() {
    hg log --limit=1 &> /dev/null
    if [ $? -eq 0 ]; then
        return 0
    fi
    return 1
}

rc_branch() {
    # Revision Control diff
    # git, svn, and hg support
    if is_git; then
        git branch --all
    elif is_svn; then
        # TODO: svn ls svn://www.example.com/svn/branches/
        # svn branch
        return 1
    elif is_hg; then
        hg branch
    fi
}

rc_checkout() {
    # Revision Control checkout
    # git and hg support
    if is_git; then
        git checkout $@
    elif is_hg; then
        hg checkout $@
    else
        echo "NotImplementedError"
    fi
}

rc_diff() {
    # Revision Control diff
    clear

    if is_svn; then
        if [ $# == 0 ]; then
            svn diff . | colordiff | less -R
        else
            if [ $# == 1 ]; then
                svn diff "${1}" | colordiff | less -R
            else
                svn diff $@ | colordiff | less -R
            fi
        fi
    elif is_hg; then
        hg diff . | colordiff | less -R
    else
        if [ $# == 0 ]; then
            if [ "$(git diff --cached . | wc -l)" -gt 1 ]; then
                echo "git diff --cached ."
                git diff --cached .
            else
                echo "git diff ."
                git diff .
            fi
        else
            if [ -z "$(git diff --cached $@)" ]; then
                echo "git diff $@"
                git diff $@
            else
                echo "git diff --cached $@"
                git diff --cached $@
            fi
        fi
    fi
}

rc_master() {
    # Revision Control master / default (hg)
    # git and hg support
    if is_git; then
        git checkout master
    elif is_hg; then
        hg checkout default
    else
        echo "NotImplementedError"
    fi
}

rc_pull() {
    # Revision Control pull
    # git and hg support
    if is_git; then
        git pull $@
    elif is_hg; then
        hg pull $@
    else
        echo "NotImplementedError"
    fi
}

rc_status() {
    # Revision Control status
    # git, hg, and svn support

    clear

    # If params empty, retrieve status of current directory
    params=$@
    if [ -z "$params" ]; then
        if ! is_hg; then
            params="."
        fi
    fi

    if is_git; then
        echo "git status $params"
        git status $params
    elif is_hg; then
        echo "hg status $params"
        hg status $params
    elif is_svn; then
        echo "svn status $params"
        svn status $params
    else
        echo "NotImplementedError"
    fi
}

source "git/git-completion.bash"