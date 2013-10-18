# Version Control Aliases

alias add.="git add ."
alias add="git add"
alias addp="git add --patch"
alias addu="git add --update"
alias amend="git commit --amend"
alias branch="rc_branch"
alias branches="rc_branches"
alias checkout="rc_checkout"
alias clone="git clone"
alias commit="git commit"
alias dcommit="git svn dcommit"
alias default="rc_master"
alias df="rc_diff"
alias drop="git_stash_drop"
alias fetch="git fetch"
alias filemode="git config core.filemode false"
alias g="git"
alias gco="grep_checkout"
alias list="git stash list"
alias log="rc_log"
alias master="rc_master"
alias merge="rc_merge"
alias pop="git stash pop"
alias pull="rc_pull"
alias push="rc_push"
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
    # git and hg support
    if is_git; then
        git branch
    elif is_hg; then
        hg branch
    elif is_svn; then
        # TODO: svn ls svn://www.example.com/svn/branches/
        # svn branch
        echo "NotImplementedError"
    fi
}

rc_branches() {
    # git and hg support
    if is_git; then
        git branch --all
    elif is_hg; then
        hg branches | sort
    elif is_svn; then
        echo "NotImplementedError"
    fi
}

rc_checkout() {
    # Revision Control checkout
    # git and hg support
    if is_git; then
        git checkout $@
    elif is_hg; then
        hg checkout $@
        return_code="${?}"
        # Display modified files when `hg checkout' fails with "abort: crosses
        # branches (merge branches or use --clean to discard changes)".
        if [ "${return_code}" -eq 255 ]; then
            hg status | \grep '^M '
        fi
    else
        echo "NotImplementedError"
    fi
}

rc_diff() {
    # Revision Control diff
    clear

    colordiff=$(which colordiff)
    if [ -z "$colordiff" ]; then
        echo "WARNING: colordiff does not seem to be installed."
        colordiff_installed=false
    else
        colordiff_installed=true
    fi

    if is_git; then
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
    elif is_svn; then
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
        if $colordiff_installed ; then
            hg diff --git . | colordiff | less --RAW-CONTROL-CHARS
            echo "hg diff --git . | colordiff | less --RAW-CONTROL-CHARS"
        else
            echo "hg diff --git ."
            hg diff --git .
        fi
    else
        \df $@
    fi
}

rc_log() {
    if is_git; then
        git log
    elif is_hg; then
        hg log | less
    else
        echo "NotImplementedError"
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

rc_merge() {
    # Revision Control merge.
    if is_git; then
        git merge $@
    elif is_hg; then
        hg merge $@
    else
        \merge $@
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

rc_push() {
    # Revision Control push
    # git and hg support
    if is_git; then
        git push $@
    elif is_hg; then
        hg push --new-branch $@
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

grep_checkout() {
    find="${@}"
    branch_list=$(branches | cut -d " " -f 1 | \grep "${find}")
    for branch in ${branch_list}; do
        replace="\033[38;5;160m${find}\033[39m"
        line=${branch//$find/$replace}
        echo -e "${line}"
    done
    for branch in ${branch_list}; do
        colorful_branch=$(echo -e "\033[38;5;141m${branch}\033[39m")
        question="Checkout ${colorful_branch}?"
        read -p "${question} " -n 1 -r
        echo # Move to a new line.
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "checking out ${branch}"
            checkout "${branch}"
            break
        fi
    done
}

source "version_control/git-completion.bash"
