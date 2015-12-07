# Version Control Aliases

alias add.="git add ."
alias add="rc_add"
alias addp="git add --patch"
alias addu="git add --update"
alias adu="git add --update"
alias amend="git commit --amend"
alias apply="git_stash_apply"
alias br="rc_branch"
alias branch="rc_branch"
alias branches="rc_branches"
alias checkout="rc_checkout"
alias ci="rc_commit"
alias clone="git clone"
alias cm="rc_commit"
alias co="rc_checkout"
alias commit="rc_commit"
alias dcommit="git svn dcommit"
alias default="rc_master"
alias df="rc_diff"
alias drop="git_stash_drop"
alias fetch="git fetch"
alias filemode="git config core.filemode false"
alias g="git"
alias gco="grep_checkout"
alias gconf="git_config"
alias gitconfig="git_config"
alias gitignore="git_ignore"
alias gm="grep_merge"
alias list="git stash list"
alias log="rc_log"
alias master="rc_master"
alias merge="rc_merge"
alias pop="git stash pop"
alias pul="rc_pull"
alias pull="rc_pull"
alias pus="rc_push"
alias push="rc_push"
alias shallow_clone="git clone --depth 1"
alias show="git_stash_show"
alias st="rc_status"
alias stash="git stash"
alias stashu="git stash --include-untracked"
alias tag="git tag"
alias tags="git tag --list"

git_config() {
    filename=$(cat <<EOF | python -
import os


dirs = os.getcwd().split(os.sep)
for i, _ in enumerate(dirs):
    paths = dirs[:len(dirs) - i]
    paths.append('.git')
    paths.append('config')
    filename = os.path.join(os.sep, *paths)
    try:
        open(filename, 'r')
    except IOError:
        pass
    else:
        print filename
        break
EOF)
    if [[ -z "${filename}" ]]; then
        echo ".git/config not found"
    else
        v "${filename}"
    fi
}

git_ignore() {
    touch .gitignore
    vim .gitignore
}

git_stash_apply() {
    # Apply the specified git stash.
    # Usage: apply 0
    git stash apply "stash@{$@}"
}

git_stash_drop() {
    # Drop the specified git stash.
    # Usage: drop 0
    git stash drop "stash@{$@}"
}

git_stash_show() {
    # Show the specified git stash.
    # Usage: show 0
    git stash show -p "stash@{$@}"
}

is_g() {
    search=$(find . -mindepth 1 -maxdepth 1 -type f -print -quit | xargs g4 log -m 1 2> /dev/null)
    if [ ! -z "${search}" ]; then
        return 0
    fi

    return 1
}

is_git() {
    git log -1 &> /dev/null
    if [ $? -eq 0 ]; then
        return 0
    else
        # Check again in case this is a new repository that doesn't have
        # history.
        git status &> /dev/null
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi

    return 1
}

rc_add() {
    if is_git; then
        git add "$@"
    fi
}

rc_branch() {
    if is_git; then
        git branch
    fi
}

rc_branches() {
    if is_git; then
        git branch --all
    fi
}

rc_checkout() {
    # Revision Control checkout
    if is_git; then
        git checkout $@
    else
        echo "NotImplementedError"
    fi
}

rc_commit() {
    if is_git; then
        git commit -m "$@"
    fi
}

rc_diff() {
    # Revision Control diff
    clear

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
    else
        colordiff=$(which colordiff)
        if [ -z "$colordiff" ]; then
            colordiff_installed=false
        else
            colordiff_installed=true
        fi

        if is_g; then
            p4 diff
        else
            \df $@
        fi
    fi
}

rc_log() {
    if is_git; then
        git log "${@}"
    else
        echo "NotImplementedError"
    fi
}

rc_master() {
    # Revision Control master.
    if is_git; then
        git checkout master
    else
        echo "NotImplementedError"
    fi
}

rc_merge() {
    # Revision Control merge.
    if is_git; then
        git merge $@
    else
        \merge $@
    fi
}

rc_pull() {
    # Revision Control pull
    if is_git; then
        git pull $@
    else
        echo "NotImplementedError"
    fi
}

rc_push() {
    # Revision Control push
    if is_git; then
        git push $@
    else
        echo "NotImplementedError"
    fi
}

rc_status() {
    # Revision Control status
    clear

    # If params empty, retrieve status of current directory
    params=$@
    if [ -z "$params" ]; then
        params="."
    fi

    if is_git; then
        echo "git status $params"
        git status $params
    elif is_g; then
        echo "g4 pending"
        g4 pending
    else
        echo "NotImplementedError"
    fi
}

grep_checkout() {
    find="${@}"
    branch_list=$(branches | sed 's/^[ *]*//g' | \grep "${find}")
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

grep_merge() {
    find="${@}"
    branch_list=$(branches | sed 's/^[ *]*//g' | \grep "${find}")
    for branch in ${branch_list}; do
        replace="\033[38;5;160m${find}\033[39m"
        line=${branch//$find/$replace}
        echo -e "${line}"
    done
    for branch in ${branch_list}; do
        colorful_branch=$(echo -e "\033[38;5;141m${branch}\033[39m")
        question="Merge ${colorful_branch}?"
        read -p "${question} " -n 1 -r
        echo # Move to a new line.
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "merging ${branch}"
            merge "${branch}"
            break
        fi
    done
}

source "version_control/git-completion.bash"

export P4DIFF="~/.dot-star/version_control/p4diff.sh"
