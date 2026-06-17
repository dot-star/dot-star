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

commit_clean_up() {
    # $ cu
    # >> git commit -m "Clean up"
    # $ cu the thing
    # >> git commit -m "Clean up the thing"
    thing="${@}"

    if [[ -z "${thing}" ]]; then
        message="Clean up"
    else
        message="Clean up ${thing}"
    fi

    rc_commit "${message}"
}
alias cu="commit_clean_up"

commit_no_verify_clean_up() {
    # $ nvcu
    # >> git commit --no-verify -m "Clean up"
    # $ nvcu the thing
    # >> git commit --no-verify -m "Clean up the thing"
    thing="${@}"

    if [[ -z "${thing}" ]]; then
        message="Clean up"
    else
        message="Clean up ${thing}"
    fi

    rc_commit_no_verify "${message}"
}
alias ncu="commit_no_verify_clean_up"
alias nvcu="commit_no_verify_clean_up"

# TODO: Implement `git cherry-pick' with selection using fzf.
alias cherry_pick="git cherry-pick"

alias ci="rc_commit"

git_clone() {
    # Clone the repository and change into the directory automatically.

    tmp_filename="/tmp/git_clone.txt"
    echo "" >"${tmp_filename}"

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
            \grep "Cloning into '" |
            perl -pe "s/Cloning into '(.*)'\.\.\.$/\1/"
    )"
    echo "humanish_dir: ${humanish_dir}"

    rm "${tmp_filename}" &&
        cd "${humanish_dir}" &&
        l
}

alias clone="git_clone"
alias cm="rc_commit"
alias co="rc_checkout"
alias cob="rc_checkout_before"
alias commit="rc_commit"

git_continue() {
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null)"
    if [[ -z "${git_dir}" ]]; then
        echo "Error: Not inside a git repository."
        return 1
    fi

    # Check for Rebase (both apply and merge variants)
    if [[ -d "${git_dir}/rebase-apply" || -d "${git_dir}/rebase-merge" ]]; then
        git rebase --continue
    # Check for Revert (sequencer handles revert and cherry-pick)
    elif [[ -f "${git_dir}/sequencer/todo" ]] && grep -q "revert" "${git_dir}/sequencer/todo"; then
        git revert --continue
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
alias default="rc_checkout_default_branch"
alias delete_branch="git_delete_branch"

delete_commit() {
    git reset --hard HEAD~1
}
alias delete_commit="delete_commit"

alias delete_tag="git tag -d"
alias df="rc_diff"
alias dfl.="git_diff_last ."
alias dfl="git_diff_last"
alias dflf="git_diff_last_files"
alias dfm="git_diff_master"
alias difflast="git_diff_last"
alias difftool="git difftool"
alias dlf="git_diff_last"
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
    # Strip geometry lines around each gitk run; the file is symlinked into the dot-star repo and gitk rewrites them on exit.
    local strip_geometry=(sed -i "" '/set geometry(/d' "${HOME}/.config/git/gitk")

    # Drop any geometry left by direct `gitk` invocations that bypassed this wrapper.
    "${strip_geometry[@]}"
    gitk "${@}"
    # Clear geometry lines gitk just wrote on exit so the symlinked dot-star file stays clean.
    "${strip_geometry[@]}"
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
alias li="git_stash_list"
alias lint='git commit -m "Lint"'
alias list="git_stash_list"
alias lo="rc_log"
alias log="rc_log"
alias main="rc_checkout_default_branch"
alias master="rc_checkout_default_branch"
alias merge="rc_merge"
alias n="rc_commit_no_verify"
alias nv="rc_commit_no_verify"
patch_changes() {
    file_name="patch_$(uuidgen).patch"
    git diff >"${file_name}"
    echo "Created patch file: ${file_name}"
}
alias patch_changes="patch_changes"
alias patch_last="git format-patch -n HEAD^"
alias pop="git_stash_pop"
alias pt="rc_fetch_tags"
alias pu="rc_pull"
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
    # Squash the last two commits into one and commit right away with the two
    # original subjects stacked, then draft fresh commit-message alternatives
    # for the combined diff in the background; amend to one if you like.
    if ! git rev-parse --verify --quiet HEAD~2 >/dev/null; then
        echo "Error: need at least two commits above the root to squash"
        return 1
    fi

    # Capture the two subjects before the reset wipes them.
    message_one="$(git log -1 --pretty=format:"%s" HEAD~1)"
    message_two="$(git log -1 --pretty=format:"%s" HEAD)"

    if ! git reset --soft HEAD~2; then
        return 1
    fi

    # Land the squash with the two subjects stacked (message_one, blank line,
    # message_two), so a commit exists even if you never pick an alternative.
    # Capture the diff first; the commit empties the index the draft reads from.
    combined_diff="$(git diff --cached)"
    git commit --message "${message_one}" --message "${message_two}"

    claude_display_commit_message_options "Update the commit message based on the combined diff now that two commits were squashed into one. Original commit message #1: ${message_one}. Original commit message #2: ${message_two}." "${combined_diff}" &
}
alias rbl2="git_rebase_last_two"
alias rbl="git_rebase_last_two"

git_rebase_master() {
    local_branches="refs/heads/"
    branches="$(
        git for-each-ref \
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
    echo "" >"${tmp_filename}"

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

view_diff() {
    commit="${1}"

    # View commit diff with headers.
    git log --max-count=1 --patch "${commit}~1" "${commit}"
}
alias view_diff="view_diff"

git_config() {
    filename=$(
        cat <<EOF | python -
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
    branches="$(
        git for-each-ref \
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

git_diff_last_files() {
    # List file paths changed in last commit, optionally scoped to a path.
    clear

    # List files changed in last commit of project when path is not specified.
    if [[ -z "${1}" ]]; then
        git log --max-count=1 --name-only --format=

    # List files changed in last commit under path when path is specified.
    else
        file_path="${1}"
        git log --max-count=1 --name-only --format= "${file_path}"
    fi
}

git_edit_last_files() {
    # Open files changed in the last commit in the editor, optionally scoped to
    # a path.
    local root_dir
    root_dir="$(git rev-parse --show-toplevel)"

    # Collect the changed paths, skipping the blank lines the empty --format
    # emits between commits.
    local paths=()
    while IFS= read -r file; do
        if [[ -n "${file}" ]]; then
            # Anchor each path to the repo root so the files open regardless of
            # the current directory.
            paths+=("${root_dir}/${file}")
        fi
    done < <(git log --max-count=1 --name-only --format= "${@}")

    if [[ ${#paths[@]} -eq 0 ]]; then
        echo "No files changed in last commit."
        return
    fi

    edit "${paths[@]}"
}
alias vdfl="git_edit_last_files"
alias vdflf="git_edit_last_files"

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
    #
    # $ rebase abc1234
    # edit-pause on abc1234 (delegates to git_rebase_edit)

    # Treat a bare 1-2 digit arg as a commit count; anything else is a
    # commit hash to edit-pause on (a real short hash is >= 4 hex chars).
    if [[ -n "${1}" ]] && [[ ! "${1}" =~ ^[0-9]{1,2}$ ]]; then
        git_rebase_edit "${1}"
        return
    fi

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

git_rebase_edit() {
    # Rebase so it pauses right after <commit> for a `git commit --amend`, then
    # finish with `cont`. Mark the commit's todo line `edit` automatically, so
    # no editor opens.
    #
    # $ rbe abc1234
    # ... edit files, git add, git commit --amend ...
    # $ cont

    if [[ -z "${1}" ]]; then
        echo "usage: rbe <commit>"
        return 1
    fi

    # Normalize to git's short hash so the pattern matches the todo's hashes.
    commit="$(git rev-parse --short "${1}")" || return 1

    set -x
    GIT_SEQUENCE_EDITOR="perl -i -pe 's/^pick (${commit}\\w*)/edit \$1/'" \
        git rebase --interactive "${commit}^"
    set +x
}
alias rbe="git_rebase_edit"

git_reset_author() {
    git commit --amend --reset-author
}
alias reset_author="git_reset_author"

git_stash() {
    if [[ "${#}" -eq 0 ]]; then
        message="$(display_input_prompt "Enter stash message:")"
    else
        message="${@}"
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
        response="$(display_confirm_prompt_destructive "Drop stash ${git_stash}?")"
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
        response="$(display_confirm_prompt_info "Pop stash ${git_stash}?")"
        if [[ "${response}" =~ ^[Yy]$ ]]; then
            echo
            local pop_output
            pop_output="$(git stash pop "${git_stash}" 2>&1)"
            local pop_exit_code="${?}"
            if [[ "${pop_exit_code}" -ne 0 ]]; then
                echo "${pop_output}" >&2
                echo
                echo -e "\033[38;5;160mWARNING: stash did not pop cleanly — ${git_stash} was kept.\033[39m" >&2
                return "${pop_exit_code}"
            fi

            # Prefix the "Dropped stash@..." line with a check mark so a clean pop is verifiable at a glance.
            echo "${pop_output}" |
                sed "s/^Dropped /✅ Dropped /"
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

git_with_warnings() {
    # Pass git's stderr through grep so WARNING-style lines stand out
    # (forced updates, GitHub security notices, bare WARNING markers).
    # Leave stdout and pagers untouched.
    command git "${@}" 2> >(
        GREP_COLORS="mt=01;38;5;208" \
            \grep --line-buffered --color=always --extended-regexp \
            'WARNING|warning|forced update|vulnerabilit(y|ies)|^remote: GitHub|$' >&2
    )
}
alias git="git_with_warnings"

is_g() {
    search=$(find . -mindepth 1 -maxdepth 1 -type f -print -quit | xargs g4 log -m 1 2>/dev/null)
    if [ ! -z "${search}" ]; then
        return 0
    fi

    return 1
}

is_git() {
    git log -1 &>/dev/null
    if [ $? -eq 0 ]; then
        return 0
    else
        # Check again in case this is a new repository that doesn't have
        # history.
        git status &>/dev/null
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
        # Attempt to checkout the branch by its exact name first, so a
        # branch with intentional uppercase resolves to its true name.
        if git checkout "${1}" 2>/dev/null; then
            return
        fi

        # Retry lowercased so keyword lookups stay case-forgiving.
        branch_name="$(echo "${1}" | lower)"
        if git checkout "${branch_name}" 2>/dev/null; then
            return
        fi

        # Switch to the worktree holding the branch when git refuses to check
        # it out here because the branch is already checked out in a worktree.
        worktree_path="$(
            git worktree list --porcelain |
                awk -v ref="branch refs/heads/${branch_name}" '
                    /^worktree / { sub(/^worktree /, ""); path = $0 }
                    $0 == ref { print path; exit }
                '
        )"
        if [[ ! -z "${worktree_path}" ]]; then
            cd "${worktree_path}"
            return
        fi

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

rc_commit_no_verify() {
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

rc_get_default_branch_name() {
    local ref="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
    echo "${ref#origin/}"
}

rc_checkout_default_branch() {
    branch_name_to_checkout="$(rc_get_default_branch_name)"
    git checkout "${branch_name_to_checkout}"
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
    local current_branch upstream
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)"

    # Route a worktree branch that has no upstream by the per-machine.
    # DOTSTAR_WORKTREE_PUSH setting.
    # DOTSTAR_WORKTREE_PUSH="default-branch":
    #    push the commits straight onto the repo's default branch, for personal
    #    repos where work lands on master and there are no pull requests.
    #    worktree-fix-login-redirect  ->  git push origin HEAD:master
    # DOTSTAR_WORKTREE_PUSH="pr-branch"
    #    push to a <slug> branch and track it, so a later bare push targets
    #    <slug> instead of the literal worktree-<...> name, for the work WIP
    #    pull request.
    #    worktree-asmith+add-login  ->  git push -u origin HEAD:asmith/add-login
    # pr-branch is the default so machines without an override keep the old
    # behavior.
    if [[ "${current_branch}" == worktree-* && -z "${upstream}" ]]; then
        local worktree_push="${DOTSTAR_WORKTREE_PUSH:-pr-branch}"
        if [[ "${worktree_push}" == "default-branch" ]]; then
            local main_checkout default_branch
            main_checkout="$(git worktree list | awk 'NR==1 {print $1}')"
            default_branch="$(git_default_branch "${main_checkout}")"
            if [[ -z "${default_branch}" ]]; then
                echo "could not determine the default branch to push to"
                return 1
            fi
            git push origin "HEAD:${default_branch}" "$@"
        else
            local remote_branch="${current_branch#worktree-}"
            remote_branch="${remote_branch/+//}"
            git push -u origin "HEAD:${remote_branch}" "$@"
        fi

        if [[ $? -ne 0 ]]; then
            echo -e "\ngit push options: $(git remote show)"
        fi

        return
    fi

    git push "$@"
    if [[ $? -ne 0 ]]; then
        echo -e "\ngit push options: $(git remote show)"
    fi
}

git_worktree_age() {
    # Print "<rel>\t<mtime>" for when the worktree's HEAD ref was last
    # updated, where <rel> is "X units ago" and <mtime> is Unix seconds.
    # Callers downstream rank by <mtime> to color rows relative to siblings.
    # HEAD's mtime captures creation, commits, and HEAD-moving checkouts; not
    # unstaged edits. The committer date of the HEAD sha is misleading for
    # worktrees parked at another branch's tip (e.g. a fresh worktree at
    # master's tip would show master's last-commit age instead of the
    # worktree's own age).
    # Usage:
    #   $ git_worktree_age <worktree_path> [git_bin]
    local worktree_path="${1}"
    local git_bin="${2:-git}"
    local gitdir head_file mtime now diff value unit rel

    gitdir="$("${git_bin}" -C "${worktree_path}" rev-parse --absolute-git-dir 2>/dev/null)"
    if [[ -z "${gitdir}" ]]; then
        return 1
    fi

    head_file="${gitdir}/HEAD"
    if [[ ! -e "${head_file}" ]]; then
        return 1
    fi

    # On macOS, call /usr/bin/stat directly: homebrew's GNU stat may shadow
    # BSD stat on PATH and `stat -f` means "filesystem info" there, not mtime.
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        mtime="$(/usr/bin/stat -f %m "${head_file}" 2>/dev/null)"
    else
        mtime="$(stat -c %Y "${head_file}" 2>/dev/null)"
    fi

    if [[ -z "${mtime}" ]]; then
        return 1
    fi

    # Absolute path: zsh's PATH lookup gets confused inside the nested
    # $(...) under a `while read` pipeline once dot-star aliases load.
    now="$(/bin/date +%s)"
    diff=$((now - mtime))
    if ((diff < 60)); then
        value="${diff}"
        unit="second"
    elif ((diff < 3600)); then
        value=$((diff / 60))
        unit="minute"
    elif ((diff < 86400)); then
        value=$((diff / 3600))
        unit="hour"
    elif ((diff < 604800)); then
        value=$((diff / 86400))
        unit="day"
    elif ((diff < 2592000)); then
        value=$((diff / 604800))
        unit="week"
    elif ((diff < 31536000)); then
        value=$((diff / 2592000))
        unit="month"
    else
        value=$((diff / 31536000))
        unit="year"
    fi

    if ((value == 1)); then
        rel="${value} ${unit} ago"
    else
        rel="${value} ${unit}s ago"
    fi
    printf '%s\t%s\n' "${rel}" "${mtime}"
}

git_worktree_list_sorted() {
    # Emit linked worktrees as TSV, sorted by HEAD mtime descending. Columns:
    #   mtime \t entry \t sha \t branch_kept \t name \t rel
    # Excludes the main checkout. branch_kept is empty when the branch matches
    # the auto-generated `worktree-<name>` convention.
    # Used by rc_status's `s` summary and git_worktree_cd's `wt` picker so
    # their row order and numbering line up.
    # Usage:
    #   $ git_worktree_list_sorted

    # Cache git's absolute path: zsh fails to find it inside the nested
    # $(...) under a `while read` pipeline once dot-star aliases load.
    # Drop the `git` alias inside the subshell first; otherwise `command -v`
    # reports the alias definition instead of the binary path.
    local git_bin
    git_bin="$(
        unalias git 2>/dev/null
        \command -v git
    )"
    git worktree list |
        awk 'NR>1' |
        while read -r entry sha branch; do
            name="${entry##*/}"
            IFS=$'\t' read -r rel mtime <<<"$(git_worktree_age "${entry}" "${git_bin}")"
            branch_kept=""
            if [[ "${branch}" != "[worktree-${name}]" ]]; then
                branch_kept="${branch}"
            fi
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${mtime}" "${entry}" "${sha}" "${branch_kept}" "${name}" "${rel}"
        done |
        sort -t $'\t' -k1,1 -rn
}

stack_renamed_paths() {
    # Stack each `git status` rename onto three lines: a bare "renamed:" label,
    # then the old path (suffixed " ->") and the new path indented beneath it, so
    # the two near-identical paths sit one above the other and the diverging
    # segment is easy to spot top-to-bottom. Every other line passes through
    # untouched; the original color codes wrap each emitted line.
    awk '
        {
            raw = $0

            # Match against a color-stripped copy so embedded color codes do not
            # break the pattern.
            bare = raw
            gsub(/\033\[[0-9;]*m/, "", bare)
            if (bare !~ /^[[:space:]]*renamed:[[:space:]]+.+ -> .+$/) {
                print raw
                next
            }

            # Split the line into its leading whitespace (kept as the base
            # indent), the opening color code, and the bare "old -> new" with its
            # trailing reset peeled off.
            match(raw, /^[[:space:]]*/)
            indent = substr(raw, 1, RLENGTH)
            rest = substr(raw, RLENGTH + 1)

            pos = index(rest, "renamed:")
            color = substr(rest, 1, pos - 1)
            body = substr(rest, pos + length("renamed:"))
            sub(/^ +/, "", body)

            reset = ""
            if (match(body, /\033\[[0-9;]*m[[:space:]]*$/)) {
                reset = substr(body, RSTART)
                body = substr(body, 1, RSTART - 1)
            }

            sep = index(body, " -> ")
            old = substr(body, 1, sep - 1)
            new = substr(body, sep + 4)

            print indent color "renamed:" reset
            print indent "    " color old " →" reset
            print indent "    " color new reset
        }
    '
}

rc_status() {
    clear

    if is_git; then
        echo "git status"
        # Show untracked files individually instead of letting git collapse them under a parent dir.
        # Pass before "$@" so an explicit `--untracked-files=...` from the caller still wins.
        # Force color so the rename stacker's pipe keeps git's status coloring.
        git -c color.status=always status --untracked-files=all "$@" |
            stack_renamed_paths

        # Run extra checks only when called with no args, to avoid noise on `s -s` etc.
        if [[ "${#}" -eq 0 ]]; then
            local i

            # Reset `d1`..`d9` to their static cumulative defaults so a prior unpushed-commits override doesn't linger after pushing. The unpushed block below may then re-override the first N.
            for i in 1 2 3 4 5 6 7 8 9; do
                alias "d${i}=git diff HEAD~${i}"
            done

            # Warn when no remote is configured.
            if [[ -z "$(git remote)" ]]; then
                echo -e "\033[30;48;5;214m Warning \033[0m\033[38;5;214m:\033[0m no remote configured; commits cannot be pushed"
            else
                # Warn about commits in HEAD that aren't on any remote-tracking ref.
                # Also exclude local master unless HEAD is master, so unpushed master
                # commits don't inflate the count in a worktree or feature branch.
                local exclude_refs=(--remotes)
                local head_branch
                head_branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
                if [[ "${head_branch}" != "master" ]] && git show-ref --verify --quiet refs/heads/master; then
                    exclude_refs+=(master)
                fi
                unpushed=$(git rev-list --count HEAD --not "${exclude_refs[@]}" 2>/dev/null)
                if [[ "${unpushed}" -gt 0 ]]; then
                    echo -e "\n\033[30;48;5;214m Warning \033[0m\033[38;5;214m:\033[0m There are unpushed commits: \033[1;36m${unpushed}\033[0m"
                    # Cap matches the highest `dN` diff alias (`d9` = `git diff HEAD~9`).
                    local listing_cap=9
                    # Prefix each line with `[dN]` so the user knows which diff alias shows that commit (d1=HEAD~1, d2=HEAD~2, ...).
                    # `--color=always` keeps `%C(auto)`/`%C(dim)` codes when piping into awk (git drops them when stdout isn't a TTY).
                    git log --color=always -n "${listing_cap}" --pretty=tformat:"%C(auto)%h%C(reset) %s %C(dim)(%cr)%C(reset)" HEAD --not "${exclude_refs[@]}" |
                        awk '{printf "    \033[2m[d%d]\033[0m %s\n", NR, $0}'
                    if [[ "${unpushed}" -gt "${listing_cap}" ]]; then
                        echo -e "    \033[2m... and \033[0m\033[1;36m$((unpushed - listing_cap))\033[0m\033[2m more\033[0m"
                    fi

                    # Override `d1`..`d_min` so each maps to `git show <hash>` of its listed commit, matching the `[dN]` prefix. The static cumulative defaults (restored above) stay for `d(min+1)`..`d9`.
                    local hash
                    i=1
                    while IFS= read -r hash; do
                        alias "d${i}=git show ${hash}"
                        i=$((i + 1))
                    done < <(git log -n "${listing_cap}" --format="%h" HEAD --not "${exclude_refs[@]}")
                fi
            fi

            # Notice uncleaned linked worktrees, only from the main checkout.
            local main_toplevel current_toplevel
            main_toplevel="$(git worktree list | awk 'NR==1 {print $1}')"
            current_toplevel="$(git rev-parse --show-toplevel)"
            if [[ "${main_toplevel}" == "${current_toplevel}" ]]; then
                local worktree_count
                worktree_count="$(git worktree list | awk 'NR>1' | wc -l | tr -d ' ')"
                if [[ "${worktree_count}" -gt 0 ]]; then
                    local worktree_label
                    if [[ "${worktree_count}" -gt 1 ]]; then
                        worktree_label="worktrees"
                    else
                        worktree_label="worktree"
                    fi

                    echo -e "\n\033[1;36m${worktree_count}\033[0m \033[2m${worktree_label}:\033[0m"

                    local sorted_worktrees
                    sorted_worktrees="$(git_worktree_list_sorted)"

                    # Bind digit aliases `1`..`N` (capped at the 10 visible rows)
                    # to `cd <worktree-path>` so the user can jump to the Nth
                    # worktree by typing its index after running `s`.
                    local idx=1 entry
                    while read -r entry; do
                        if [[ "${idx}" -gt 10 ]]; then
                            break
                        fi
                        alias -- "${idx}"="cd ${entry}"
                        idx=$((idx + 1))
                    done < <(echo "${sorted_worktrees}" | awk -F'\t' '{print $2}')

                    # Show basenames only and drop the branch column when it matches
                    # the auto-generated `worktree-<name>` convention. The leading
                    # index column matches the row number `wt N` accepts. Rows print
                    # oldest-first so [1] (newest) lands closest to the prompt, the
                    # same orientation `wt`'s fzf picker uses.
                    # Example output:
                    #     [2]  custom-checkout   abc1234 (2 days ago)  [feature/foo]
                    #     [1]  pretty-tail-glow  e762c60 (1 day ago)
                    # awk fades the parenthetical from 256-color 255 (white) at
                    # newest down to 239 (gray) at oldest, linearly by rank,
                    # right-pads the 1-based index for two-digit alignment, and
                    # right-pads the parenthetical so the branch column lines up.
                    if [[ "${worktree_count}" -gt 10 ]]; then
                        echo -e "    \033[2m... and \033[0m\033[1;36m$((worktree_count - 10))\033[0m\033[2m more\033[0m"
                    fi
                    echo "${sorted_worktrees}" |
                        awk -F'\t' '
                            {
                                lines[NR] = $0
                                if (length($5) > max_name) {
                                    max_name = length($5)
                                }
                                if (length($6) > max_rel) {
                                    max_rel = length($6)
                                }
                            }
                            END {
                                total = NR
                                digits = length(total "")
                                visible = (total > 10) ? 10 : total
                                # Iterate oldest-of-visible down to newest so [1]
                                # ends up at the bottom, next to the prompt.
                                for (i = visible; i >= 1; i--) {
                                    split(lines[i], f, "\t")
                                    sha = f[3]; branch_kept = f[4]; name = f[5]; rel = f[6]
                                    if (total <= 1) {
                                        code = 255
                                    } else {
                                        code = 255 - int((i - 1) * 16 / (total - 1))
                                    }

                                    # Brackets hint that the number is a live
                                    # `cd` alias bound by `s` for this row.
                                    idx_str = sprintf("[%*d]", digits, i)
                                    if (branch_kept == "") {
                                        printf "\033[2m%s\033[0m  \033[38;5;80m%-*s\033[0m  \033[33m%s\033[0m \033[38;5;%dm(%s)\033[0m\n", idx_str, max_name, name, sha, code, rel
                                    } else {
                                        # Right-pad the parenthetical to its widest so
                                        # the branch column lines up across rows.
                                        rel_pad = sprintf("%*s", max_rel - length(rel), "")
                                        printf "\033[2m%s\033[0m  \033[38;5;80m%-*s\033[0m  \033[33m%s\033[0m \033[38;5;%dm(%s)\033[0m%s  \033[38;5;177m%s\033[0m\n", idx_str, max_name, name, sha, code, rel, rel_pad, branch_kept
                                    }
                                }
                            }
                        ' |
                        sed 's/^/    /'
                fi
            fi
        fi
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
        response="$(display_confirm_prompt_info "Checkout ${colorful_branch}?")"
        echo # Move to a new line.
        if [[ $response =~ ^[Yy]$ ]]; then
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
        response="$(display_confirm_prompt_caution "Merge ${colorful_branch}?")"
        echo # Move to a new line.
        if [[ $response =~ ^[Yy]$ ]]; then
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

export P4DIFF="~/.dot-star/tools/version_control/p4diff.sh"

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
alias wi="commit_work_in_progress"
alias wip="commit_work_in_progress"

commit_work_in_progress_no_verify() {
    # $ nwip
    # >> git commit -m "wip" --no-verify
    # $ nwip the thing
    # >> git commit -m "wip the thing" --no-verify
    thing="${@}"

    if [[ -z "${thing}" ]]; then
        message="wip"
    else
        message="wip ${thing}"
    fi

    rc_commit_no_verify "${message}"
}
alias nvwip="commit_work_in_progress_no_verify"
alias nwip="commit_work_in_progress_no_verify"

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

open_pull_request() {
    gh pr view --web
}

alias pr="open_pull_request"

git_pr_authors() {
    # List the top authors of files in the current PR, excluding yourself, to
    # surface who knows the code (likely reviewers).
    if ! is_git; then
        echo "Not a git repository."
        return 1
    fi

    local me="$(git config user.name)"
    local files
    files="$(gh pr view --json files --jq '.files[].path')"
    if [[ -z "${files}" ]]; then
        echo "No pull request found for the current branch."
        return 1
    fi

    git log --format='%an' -- ${files} |
        \grep --invert-match --fixed-strings "${me}" |
        sort |
        uniq -c |
        sort --reverse --numeric-sort |
        head --lines=10
}
alias prr="git_pr_authors"
alias reviewers="git_pr_authors"
alias whoknows="git_pr_authors"

conditional_gh() {
    # Open the current repository or list repositories; passthrough to gh
    # otherwise.
    # (in a git repo, no args)
    # $ gh
    # >> gh browse
    # (not in a git repo, no args)
    # $ gh
    # >> github_repositories
    # (with args, passthrough)
    # $ gh pr list
    # >> gh pr list
    if [[ "${#}" -eq 0 ]]; then
        if is_git; then
            open_repository
        else
            github_repositories
        fi
    else
        gh ${@}
    fi
}
alias gh="conditional_gh"
alias ghr="github_repositories"
alias gr="github_repositories"

open_repository() {
    # Open the current repository on GitHub or a specific file on GitHub.
    # $ repo
    # >> gh browse
    # $ repo src/main.py
    # >> gh browse src/main.py
    # $ repo src/main.py:100
    # >> gh browse src/main.py:100
    command gh browse ${@}
}
alias repo="open_repository"
