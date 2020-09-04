# Version Control Aliases

alias add.="git add ."
alias add="rc_add"
alias addp.="git add --patch ."
alias addp="git add --patch"
alias addu.="git add --update ."
alias addu="git add --update"
alias adu="git add --update"
alias amend="git commit --amend"
alias ap.="git add --patch ."
alias ap="git add --patch"
alias apply="git_stash_apply"
alias au="git add --update"
alias br="rc_branch"
alias branch="rc_branch"
alias branches="rc_branches"
alias checkout="rc_checkout"
alias ci="rc_commit"
alias clone="git clone"
alias cm="rc_commit"
alias co="rc_checkout"
alias commit="rc_commit"
alias d.="git diff ."
alias dcommit="git svn dcommit"
alias default="rc_master"
alias df="rc_diff"
alias difflast="git_diff_last"
alias difftool="git difftool"
alias drop="git_stash_drop"
alias fetch="git fetch"
alias fetch_tags="rc_fetch_tags"
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
alias pull_tags="rc_fetch_tags"
alias pus="rc_push"
alias push="rc_push"
alias shallow_clone="git clone --depth 1"
alias show="git_stash_show"
alias s.="rc_status ."
alias st="rc_status"
alias stash="git_stash"
alias tag="git tag"
alias tags="git tag --list | sort --version-sort"
alias unshallow="git fetch --unshallow"

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
EOF
)
    if [[ -z "${filename}" ]]; then
        echo ".git/config not found"
    else
        v "${filename}"
    fi
}

git_diff_last() {
    # Display diff of last commit, optionally with a path.
    clear

    if [[ -z "${1}" ]]; then
        # Display last diff of project when path is not specified.
        git log --max-count=1 --patch
    else
        # Display last diff of path when path is specified.
        path="${1}"
        git log --max-count=1 --patch "${path}"
    fi
}

git_ignore() {
    touch .gitignore
    vim .gitignore
}

git_reset_author() {
    git commit --amend --reset-author
}
alias reset_author="git_reset_author"

git_stash() {
    message="${1}"
    if [ -z "${message}" ]; then
        echo "message required"
    else
        set -x
        git stash save --include-untracked "${message}"
        set +x
    fi
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
    git add "$@"
}

rc_branch() {
    git branch
}

rc_branches() {
    git branch --all
}

rc_checkout() {
    git checkout $@
}

rc_commit() {
    if [ $# == 0 ]; then
        git commit
    else
        git commit -m "${@}"
    fi
}

rc_diff() {
    clear

    if is_git; then
        # No arguments passed to `git diff'.
        if [[ $# == 0 ]]; then
            # Display staged diff (cached) when available.
            if [[ ! -z "$(git diff --cached)" ]]; then
                echo "git diff --cached"
                git diff --cached
            # Display current directory diff.
            elif [[ ! -z "$(git diff .)" ]]; then
                echo "git diff ."
                git diff .
            else
                echo "git diff"
                git diff
            fi
        # Arguments passed to `git diff'.
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
        if is_g; then
            p4 diff
        else
            \df "${@}"
        fi
    fi
}

rc_fetch_tags() {
    git fetch --tags $@
}

rc_log() {
    git log --graph --pretty=format:"%C(red)%h%Creset -%C(magenta)%d%Creset %s %C(green)(%cr)%Creset %C(238)%an <%ae>%n%-b" "${@}"
}

rc_master() {
    git checkout master
}

rc_merge() {
    if is_git; then
        git merge $@
    else
        \merge $@
    fi
}

rc_pull() {
    git pull $@
}

rc_push() {
    git push $@
}

rc_status() {
    clear

    if is_git; then
        echo "git status"
        git status $@
    elif is_g; then
        pending
    else
        l
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

export P4DIFF="~/.dot-star/version_control/p4diff.sh"
