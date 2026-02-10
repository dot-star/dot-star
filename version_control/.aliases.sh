# Version Control Aliases

alias a.="git add ."
alias abort="git rebase --abort"
alias add.="git add ."
alias add="rc_add"
alias addp.="git add --patch ."
alias addp="git add --patch"
alias addu.="git add --update ."
alias addu="git add --update"
alias adu="git add --update"
alias am="amend"
alias amend="git commit --amend --date=now"
alias ap.="git add --patch ."
alias ap="git add --patch"
alias apply="git_stash_apply"
alias au.="git add --update ."
alias au="git add --update"
alias br="rc_branch"
alias branch="rc_branch"
alias branches="rc_branches"
alias brs="rc_branches"

commit_bump() {
    # $ bump
    # >> git commit -m "Bump"
    # $ bump the thing
    # >> git commit -m "Bump the thing"
    thing="${@}"

    if [[ -z "${thing}" ]]; then
        message="Bump"
    else
        message="Bump ${thing}"
    fi

    rc_commit "${message}"
}

alias bump="commit_bump"

alias checkout="rc_checkout"
alias cu='git commit -m "Clean up"'

# TODO: Implement `git cherry-pick' with selection using fzf.
alias cherry_pick="git cherry-pick"

alias ci="rc_commit"

git_clone() {
    # Clone the repository and change into the directory automatically.

    tmp_filename="/tmp/git_clone.txt"
    echo "" > "${tmp_filename}"

    set -o pipefail

    git clone --progress "${@}" 2>&1 |
        tee "${tmp_filename}"
    exit_code="${?}"

    set +o pipefail

    if [[ "${exit_code}" -ne 0 ]]; then
        return
    fi

    humanish_dir="$(
        cat "${tmp_filename}" |
        grep "Cloning into '" |
        perl -pe "s/Cloning into '(.*)'\.\.\.$/\1/"
    )"

    rm "${tmp_filename}"

    cd "${humanish_dir}" &&
        l
}

alias clone="git_clone"
alias cm="rc_commit"
alias co="rc_checkout"
alias cob="rc_checkout_before"
alias commit="rc_commit"

git_continue() {
    if [[ -d ".git/rebase-apply" ]]; then
        git rebase --continue
    else
        echo "Error: Nothing to continue detected."
        return 1
    fi
}
alias con="git_continue"
alias cont="git_continue"
alias cop="git checkout --patch"
alias create_patch_from_changes="patch_changes"
alias create_patch_from_last="patch_last"
alias d.="git diff ."
alias d1="git diff HEAD~1"
alias d2="git diff HEAD~2"
alias d3="git diff HEAD~3"
alias d4="git diff HEAD~4"
alias d5="git diff HEAD~5"
alias d6="git diff HEAD~6"
alias d7="git diff HEAD~7"
alias d8="git diff HEAD~8"
alias d9="git diff HEAD~9"
alias dcommit="git svn dcommit"
alias default="rc_checkout_default_branch master"
alias delete_branch="git_delete_branch"

_delete_commit() {
    git reset --hard HEAD~1
}
alias delete_commit="_delete_commit"

alias delete_tag="git tag -d"
alias df="rc_diff"
alias dfl.="git_diff_last ."
alias dfl="git_diff_last"
alias dfm="git_diff_master"
alias difflast="git_diff_last"
alias difftool="git difftool"
alias drop="git_stash_drop"
alias edit_commit="git_rebase_interactive"
alias fetch="git fetch"
alias fetch_tags="rc_fetch_tags"
alias filemode="git config core.filemode false"

commit_fix() {
    # $ fix
    # >> git commit -m "Fix"
    # $ fix the thing
    # >> git commit -m "Fix the thing"
    thing="${@}"

    if [[ -z "${thing}" ]]; then
        message="Fix"
    else
        message="Fix ${thing}"
    fi

    rc_commit "${message}"
}
alias fix="commit_fix"

conditional_g() {
    # Supports alias g with and without arguments.
    if [[ "${#}" -eq 0 ]]; then
        git_browser
    elif [[ "${#}" -eq 1 ]] && [[ -f "${1}" ]]; then
        git_browser "${1}"
    elif [[ "${#}" -eq 1 ]] && [[ -d "${1}" ]]; then
        git_browser "${1}"
    else
        git ${@}
    fi

}
alias g="conditional_g"

git_browser() {
    # Remove line causing gitk to crash:
    #   "set geometry(state) zoomed"
    sed -i "" '/set geometry(state) /d' ~/.config/git/gitk

    gitk "${@}"
}

alias g.="git_browser ."
alias gco="grep_checkout"
alias gconf="git_config"
alias gitconfig="git_config"
alias gitignore="git_ignore"
alias gitk.="git_browser ."
alias gitk="git_browser"
alias gk.="git_browser ."
alias gk="git_browser"
alias gm="grep_merge"
alias l.="rc_log ."
alias lint='git commit -m "Lint"'
alias list="git_stash_list"
alias lo="rc_log"
alias log="rc_log"
alias main="rc_checkout_default_branch main"
alias master="rc_checkout_default_branch master"
alias merge="rc_merge"
alias n="rc_no_verify"
alias nv="rc_no_verify"
_patch_changes() {
    file_name="patch_$(uuidgen).patch"
    git diff > "${file_name}"
    echo "Created patch file: ${file_name}"
}
alias patch_changes="_patch_changes"
alias patch_last="git format-patch -n HEAD^"
alias pop="git_stash_pop"
alias pt="rc_fetch_tags"
alias pul="rc_pull"
alias pull="rc_pull"
alias pull_tags="rc_fetch_tags"
alias pull_with_rebase="rc_pull_with_rebase"
alias pus="rc_push"
alias push="rc_push"
alias rb="git_rebase"
alias rb0="git_rebase 10"
alias rb2="git_rebase 2"
alias rb3="git_rebase 3"
alias rb4="git_rebase 4"
alias rb5="git_rebase 5"
alias rb6="git_rebase 6"
alias rb7="git_rebase 7"
alias rb8="git_rebase 8"
alias rb9="git_rebase 9"

git_rebase_last_two() {
    # Squash the last two commits into one commit.
    combined_message="$(git log -2 --pretty=format:"%B")"

    git reset --soft HEAD~2 &&
        git commit --message "${combined_message}"
}
alias rbl2="git_rebase_last_two"
alias rbl="git_rebase_last_two"

git_rebase_master() {
    local_branches="refs/heads/"
    branches="$(git for-each-ref \
        --format="%(refname:short)" \
        "${local_branches}"
    )"

    if echo "${branches}" | grep -q "^master$"; then
        base_branch="master"
    elif echo "${branches}" | grep -q "^main$"; then
        base_branch="main"
    else
        echo 'Error: Neither "master" nor "main" branch was detected'
        return
    fi

    set -x
    git pull origin "${base_branch}" --rebase
    set +x
}
alias rbm="git_rebase_master"

git_rebase_self() {
    # Rebase the current branch onto its remote tracking branch.
    current_branch="$(git rev-parse --abbrev-ref HEAD)"
    echo "rebasing current branch (${current_branch})"
    set -x
    git pull "origin" "${current_branch}" --rebase
    set +x
}

alias rbs="git_rebase_self"
alias re="git_rebase"
alias reb="git_rebase"
alias rebase="git_rebase"
alias rebase_pull="rc_pull_with_rebase"
alias s.="rc_status ."

git_revert_select_files() {
    # Reverts the specified files to their state in the previous commit.
    files_to_revert="${@}"
    set -x &&
        git checkout HEAD~1 -- ${files_to_revert} &&
        set +x &&
        echo "✅ Reverted files to the previous commit: ${files_to_revert}"
}
alias revert_select_files="git_revert_select_files"

git_shallow_clone() {
    # Shallow clone the repository and change into the directory.

    tmp_filename="/tmp/git_shallow_clone.txt"
    echo "" > "${tmp_filename}"

    git clone --depth 1 --progress "${@}" 2>&1 |
        tee "${tmp_filename}"

    humanish_dir="$(
        cat "${tmp_filename}" |
        grep "Cloning into '" |
        perl -pe "s/Cloning into '(.*)'\.\.\.$/\1/"
    )"

    rm "${tmp_filename}"

    cd "${humanish_dir}" &&
        l
}
alias shallow_clone="git_shallow_clone"

alias show="git_shows"
alias st="rc_status"
alias stash="git_stash"
alias tag="git tag"
alias tags="git tag --list | sort --reverse --version-sort | less -X -F"
alias unshallow="git fetch --unshallow"

_view_diff() {
    commit="${1}"

    # View commit diff with headers.
    git log --max-count=1 --patch "${commit}~1" "${commit}"
}
alias view_diff="_view_diff"

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
        print(filename)
        break
EOF
)
    if [[ -z "${filename}" ]]; then
        echo ".git/config not found"
    else
        v "${filename}"
    fi
}

git_delete_branch() {
    branch_name="$(branches | fzf --ansi --ignore-case)"
    branch_name="${branch_name#"${branch_name%%[![:space:]]*}"}"
    branch_name="$(echo "${branch_name}" | perl -pe 's/(.*) \(.*\)/\1/')"
    if [[ ! -z "${branch_name}" ]]; then
        git branch --delete -- "${branch_name}"
    fi
}

git_diff_master() {
    local_branches="refs/heads/"
    branches="$(git for-each-ref \
        --format="%(refname:short)" \
        "${local_branches}"
    )"

    if echo "${branches}" | grep -q "^main$"; then
        branch_to_compare="origin/main"
    elif echo "${branches}" | grep -q "^master$"; then
        branch_to_compare="origin/master"
    else
        echo 'Error: Neither "master" nor "main" branch was detected'
        return
    fi

    first_unmerged_commit="$(git log "${branch_to_compare}..HEAD" --oneline --format=%H | tail -n 1)"
    if [[ -z "${first_unmerged_commit}" ]]; then
        echo "(no local unmerged commits found)"
    else
        git diff "${first_unmerged_commit}~1"
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
        file_path="${1}"
        git log --max-count=1 --patch "${file_path}"
    fi
}

git_ignore() {
    touch .gitignore
    vim .gitignore
}

git_rebase() {
    # $ rebase
    # git rebase -i HEAD~2
    #
    # $ rebase 3
    # git rebase -i HEAD~3
    #
    # $ rebase 4
    # git rebase -i HEAD~4

    if [[ "${#}" -eq 0 ]]; then
        target="HEAD~2"
    else
        target="HEAD~${1}"
    fi

    set -x
    git rebase -i "${target}"
    set +x
}

git_rebase_interactive() {
    thing="${1}"

    if [[ "${thing}" != *"^" ]]; then
        thing="${thing}^"
    fi

    set -x
    git rebase --interactive "${thing}"
    set +x
}

git_reset_author() {
    git commit --amend --reset-author
}
alias reset_author="git_reset_author"

git_stash() {
    message="${1}"
    if [ -z "${message}" ]; then
        message="$(display_input_prompt "Enter stash message:")"
    fi

    if [ -z "${message}" ]; then
        message="Stash $(date)"
    fi

    set -x
    git stash save --include-untracked "${message}"
    set +x
}

git_stash_apply() {
    # Apply the specified git stash.
    # Usage: apply 0
    git stash apply "stash@{$@}"
}

git_stash_drop() {
    # Drop the selected git stash.
    exit_with_code=true
    local git_stash="$(git_stash_list "${exit_with_code}")"
    exit_code="${?}"
    if [[ "${exit_code}" -eq 1 ]]; then
        # Display "(no stashes found)".
        echo "${git_stash}"
    elif [[ ! -z "${git_stash}" ]]; then
        # Confirm before dropping the selected git stash.
        response="$(display_confirm_prompt "Drop stash ${git_stash}?")"
        if [[ "${response}" =~ ^[Yy]$ ]]; then
            echo
            git stash drop "${git_stash}"
        fi
    fi
}

git_stash_list() {
    exit_with_code="${1}"
    if [[ -z "${exit_with_code}" ]]; then
        exit_with_code=false
    fi

    result="$(git stash list |
        fzf \
            --exit-0 \
            --info="hidden" \
            --preview='stash=$(echo {} | sed "s/}.*/}/"); git stash show --patch --include-untracked "${stash}" --color=always' \
            --preview-window="up:100")"
    exit_code="${?}"
    if [[ "${exit_code}" -eq 0 ]]; then
        local git_stash="$(echo ${result} | sed "s/}.*/}/")"
        echo "${git_stash}"
    elif [[ "${exit_code}" -eq 1 ]]; then
        echo "(no stashes found)"
        if ${exit_with_code}; then
            exit "${exit_code}"
        fi
    elif [[ "${exit_code}" -eq 2 ]]; then
        echo "(fzf error)"
        if ${exit_with_code}; then
            exit "${exit_code}"
        fi
    elif [[ "${exit_code}" -eq 130 ]]; then
        # Handle Ctrl-C and Esc exit gracefully.
        return
    fi
}

git_stash_pop() {
    # Pop the selected git stash.
    exit_with_code=true
    local git_stash="$(git_stash_list "${exit_with_code}")"
    exit_code="${?}"
    if [[ "${exit_code}" -eq 1 ]]; then
        # Display "(no stashes found)".
        echo "${git_stash}"
    elif [[ ! -z "${git_stash}" ]]; then
        # Display stash.
        git stash show --patch --include-untracked "${git_stash}"

        # Confirm before popping the selected git stash.
        response="$(display_confirm_prompt "Pop stash ${git_stash}?")"
        if [[ "${response}" =~ ^[Yy]$ ]]; then
            echo
            git stash pop "${git_stash}"
        fi
    fi
}

git_stash_show() {
    # Show the specified git stash.
    # Usage:
    #   $ show 0
    git stash show -p "stash@{$@}"
}

git_show() {
    # Show the specified git commit.
    # Usage:
    #   $ show <commit-hash>
    #   $ show <commit-hash>:path/to/file.txt
    git show "${@}"
}

git_shows() {
    # Handle both git stash show and git show based on parameters passed.
    if [[ "${1}" =~ ^[0-9]+$ ]]; then
        git_stash_show "${1}"
    else
        git_show "${@}"
    fi
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
    # Display a list of local branches.
    # An improvement on `git branch --all'.
    local_branches="refs/heads/"
    git for-each-ref \
      --sort="committerdate" \
      --format=$'\e[33m%(refname:short)\e[0m \e[32m(%(committerdate:relative))\e[0m' \
      "${local_branches}"
}

rc_checkout() {
    if [[ "${#}" -eq 0 ]]; then
        # Display list of branches to checkout when no parameters have been
        # passed.
        branch_name="$(branches | fzf --ansi --ignore-case)"
        branch_name="${branch_name#"${branch_name%%[![:space:]]*}"}"
        branch_name="$(echo "${branch_name}" | perl -pe 's/(.*) \(.*\)/\1/')"
        if [[ ! -z "${branch_name}" ]]; then
            set -x
            git checkout "${branch_name}"
            set +x
        fi
    elif [[ "${#}" -eq 1 ]]; then
        # Attempt to checkout the specified branch name.
        branch_name="$(echo "${1}" | lower)"

        git checkout "${branch_name}" 2>/dev/null
        exit_code="${?}"
        if [[ "${exit_code}" -ne 0 ]]; then
            # Attempt to checkout the branch filtering by keyword.
            branch_name="$(
                branches |
                \grep "${branch_name}" |
                trim |
                fzf --ansi --ignore-case --select-1
            )"
            branch_name="${branch_name#"${branch_name%%[![:space:]]*}"}"
            branch_name="$(echo "${branch_name}" | perl -pe 's/(.*) \(.*\)/\1/')"

            git checkout "${branch_name}"
        fi
    else
        git checkout $@
    fi
}

rc_checkout_before() {
    # Checks out the commit before the specified commit hash.
    commit_hash="${1}"
    commit_before="$(git rev-parse "${commit_hash}^")"

    # echo "commit_hash: ${commit_hash}"
    # echo "commit_before: ${commit_before}"

    git checkout "${commit_before}"
}

rc_commit() {
    if [[ $# == 0 ]]; then
        git commit
    else
        git commit -m "${@}"
    fi
}

rc_no_verify() {
    if [[ $# == 0 ]]; then
        git commit --no-verify
    else
        git commit --no-verify -m "${@}"
    fi
}

rc_diff() {
    clear

    if is_git; then
        # No arguments passed to `git diff'.
        if [[ $# == 0 ]]; then

            # Prioritize displaying the diff of files listed under the "Unmerged
            # paths" section over the "Changes to be committed" section when
            # there is an interactive rebase in progress since the unmerged
            # files are what need attention for the rebase to continue.
            #
            # Check if currently in an interactive rebase. Following
            # wt_status_check_rebase() which sets
            # rebase_interactive_in_progress = 1 based on the presence a
            # directory "rebase-merge" and a file "rebase-merge/interactive"
            # within the .git directory.
            # https://github.com/git/git/blob/79bdd48716a4c455bdc8ffd91d57a18d5cd55baa/wt-status.c#L1713-L1715
            rebase_interactive_in_progress=false
            git_top_level="$(git rev-parse --show-toplevel)/.git"
            if [[ -d "${git_top_level}/rebase-merge" ]]; then
                if [[ -f "${git_top_level}/rebase-merge/interactive" ]]; then
                    rebase_interactive_in_progress=true
                fi
            fi

            # Display non-cached diff when there is an interactive rebase in
            # progress.
            if $rebase_interactive_in_progress; then
                echo "interactive rebase in progress. showing regular diff."

                # Display non-cached diff when available.
                if [[ ! -z "$(git diff)" ]]; then
                    echo "git diff"
                    git diff
                else
                    echo "git diff --cached"
                    git diff --cached
                fi

            else
                # Display staged diff (cached) when available.
                result="$(git diff --cached)"
                if [[ ! -z "${result}" ]] && [[ "${result}" != "* Unmerged path"* ]]; then
                    echo "git diff --cached"
                    git diff --cached

                # Display current directory diff.
                elif [[ ! -z "$(git diff .)" ]]; then
                    echo "git diff ."
                    git diff .

                # Display diff.
                else
                    echo "git diff"
                    git diff
                fi
            fi

        # Arguments passed to `git diff'.
        else
            # Display staged diff (cached) when available.
            result="$(git diff --cached $@)"
            if [[ ! -z "${result}" ]] && [[ "${result}" != "* Unmerged path"* ]]; then
                echo "git diff --cached $@"
                git diff --cached $@
            else
                echo "git diff $@"
                git diff $@
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

rc_checkout_default_branch() {
    branch_name_to_checkout_first="${1}"
    if [[ "${branch_name_to_checkout_first}" = "master" ]]; then
        branch_name_to_checkout_first="master"
        branch_name_to_checkout_next="main"
    elif [[ "${branch_name_to_checkout_first}" = "main" ]]; then
        branch_name_to_checkout_first="main"
        branch_name_to_checkout_next="master"
    elif [[ "${branch_name_to_checkout_first}" = "" ]]; then
        branch_name_to_checkout_first="master"
        branch_name_to_checkout_next="main"
    else
        echo "Error: Unexpected branch name \"${branch_name_to_checkout_first}\""
        return 1
    fi

    # Checkout the primary branch.
    git checkout "${branch_name_to_checkout_first}"
    exit_code="${?}"
    # echo "${branch_name_to_checkout_first} checkout exit_code: ${exit_code}"

    # Attempt to checkout the fallback branch if checking out the primary branch
    # fails.
    if [[ "${exit_code}" -ne 0 ]]; then
        git checkout "${branch_name_to_checkout_next}"
        exit_code="${?}"
        # echo "${branch_name_to_checkout_next} checkout exit_code: ${exit_code}"
    fi
}

rc_merge() {
    if is_git; then
        git merge $@
    else
        \merge $@
    fi
}

rc_pull() {
    if [[ "${#}" -eq 0 ]]; then
        refspec="$(git rev-parse --abbrev-ref HEAD)"
        git pull "origin" "${refspec}"
    else
        git pull $@
    fi

    if [[ $? -ne 0 ]]; then
        echo -e "\ngit pull options: $(git remote show)"
    fi
}

rc_pull_with_rebase() {
    git pull --rebase $@
}

rc_push() {
    git push $@
    if [[ $? -ne 0 ]]; then
        echo -e "\ngit push options: $(git remote show)"
    fi
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

diff_highlight() {
    if $DIFF_HIGHLIGHT_INSTALLED; then
        if [[ "${OSTYPE}" == "darwin"* ]]; then
            local homebrew_prefix="${HOMEBREW_PREFIX}"
            if [[ -z "${HOMEBREW_PREFIX}" ]]; then
                homebrew_prefix="/usr/local"
            fi

            "${homebrew_prefix}/Cellar/git/"*"/share/git-core/contrib/diff-highlight/diff-highlight" | less -m
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            diff-highlight
        fi
    fi
}

diff_strings_like_files() {
    string_1="${1}"
    string_2="${2}"
    (
        $DIFF_HIGHLIGHT_INSTALLED &&
        $COLORDIFF_INSTALLED &&
        diff --unified <(echo "${string_1}") <(echo "${string_2}") | diff_highlight | colordiff | tail -n +4
    ) || (
        $DIFF_SO_FANCY_INSTALLED &&
        diff --unified <(echo "${string_1}") <(echo "${string_2}") | diff-so-fancy | tail -n +5
    ) || (
        $COLORDIFF_INSTALLED &&
        diff --unified <(echo "${string_1}") <(echo "${string_2}") | colordiff | tail -n +4
    ) || (
        diff --unified <(echo "${string_1}") <(echo "${string_2}") | tail -n +4
    )
}
alias diff_like_files="diff_strings_like_files"

export P4DIFF="~/.dot-star/version_control/p4diff.sh"

main_and_pull() {
    rc_checkout_default_branch &&
    git pull
}

alias mp="main_and_pull"

commit_work_in_progress() {
    # $ wip
    # >> git commit -m "wip"
    # $ wip the thing
    # >> git commit -m "wip the thing"
    thing="${@}"

    if [[ -z "${thing}" ]]; then
        message="wip"
    else
        message="wip ${thing}"
    fi

    rc_commit "${message}"
}
alias nvwip="nv commit_work_in_progress"
alias nwip="nv commit_work_in_progress"
alias wi="commit_work_in_progress"
alias wip="commit_work_in_progress"

conditional_gh() {
    if [[ "${#}" -eq 0 ]]; then
        github_repositories
    else
        gh ${@}
    fi
}
alias gh="conditional_gh"
alias ghr="github_repositories"
alias gr="github_repositories"

git_swap_last_two_commits() {
    # Ensure working directory is clean.
    if ! git diff-index --quiet HEAD --; then
        echo "Error: There are unstaged changes. Commit or stash them first."
        return 1
    fi

    local current_branch="$(git rev-parse --abbrev-ref @{-2})"
    echo "current_branch: ${current_branch}"

    # Grab hashes of the last two commits.
    local commit_a="$(git rev-parse HEAD)"
    local commit_b="$(git rev-parse HEAD~1)"
    local commit_parent="$(git rev-parse HEAD~2)"

    echo "commit_a: ${commit_a}"
    echo "commit_b: ${commit_b}"
    echo "commit_parent: ${commit_parent}"

    # Move to the parent commit (detached HEAD).
    git checkout "${commit_parent}" ||
        return 1

    # Apply the first commit.
    if ! git cherry-pick "${commit_a}"; then
        git cherry-pick --abort &&
            git checkout -

        echo "Error: Conflict detected while applying ${commit_a}. Aborting."
        return 1
    fi

    # Apply the second commit.
    if ! git cherry-pick "${commit_b}"; then
        git cherry-pick --abort &&
            git checkout -

        echo "Error: Conflict detected while applying ${commit_b}. Aborting."
        return 1
    fi

    git branch -f "${current_branch}" HEAD &&
        git checkout "${current_branch}" &&
        echo "✅ Successfully swapped the last 2 commits: ${commit_b} and ${commit_a})"
}
alias swap="git_swap_last_two_commits"
