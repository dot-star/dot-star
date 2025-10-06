# Shortcuts

success() {
    printf '%s%s%s' \
        "$(echo -e "\x1b[32m")" \
        "${*}" \
        "$(echo -e "\x1b[39m")"
}

error() {
    printf '%s%s%s' \
        "$(echo -e "\x1b[31m")" \
        "${*}" \
        "$(echo -e "\x1b[39m")"
}

is_interactive_shell() {
    [[ "$-" =~ "i" ]]
}

display_confirm_prompt() {
    # Display prompt that accepts 1 character as input and echo reply.
    # Usage:
    #   response="$(display_confirm_prompt "Do thing?")"
    #   if [[ "${response}" =~ ^[Yy]$ ]]; then
    #       echo
    #       # Do thing.
    #   fi
    text="${1}"
    if [[ -n "${BASH_VERSION}" ]]; then
        read -p "${text} " -n 1 -r
        echo "${REPLY}"
    elif [[ -n "${ZSH_VERSION}" ]]; then
        read -k 1 "REPLY?${text} "
        echo "${REPLY}"
    fi
}

display_input_prompt() {
    # Display prompt that accepts input and echo reply.
    # Usage:
    #   message="$(display_input_prompt "Enter a message:")"
    text="${1}"
    if [[ -n "${BASH_VERSION}" ]]; then
        read -p "${text} " -r
        echo "${REPLY}"
    elif [[ -n "${ZSH_VERSION}" ]]; then
        read "REPLY?${text} "
        echo "${REPLY}"
    fi
}

alias 600="\chmod 600"
alias 644="\chmod 644"
alias 700="\chmod 700"
alias 750="\chmod 750"
alias 755="\chmod 755"
alias 777="\chmod 777"
alias xsh="chmod +x *.sh"

_require_watchman() {
    which watchman-make &> /dev/null
    if [[ $? -ne 0 ]]; then
        echo -e '\x1b[0;93mWARNING\x1b[0m: watchman-make required'

        if [[ "${OSTYPE}" == "darwin"* ]]; then
            set -x
            brew install watchman
            set +x
        else
            set -x
            sudo apt-get install -y watchman
            set +x
        fi
    fi
}

_ls() {
    extra_args="${@}"
    clear

    local ls_to_use
    if [[ "${OSTYPE}" == "darwin"* ]]; then
      # GNU `ls`. Available with `brew install coreutils'.
      ls_to_use="gls"
    else
      ls_to_use="ls"
    fi

    if which "$ls_to_use" &> /dev/null; then
        "$ls_to_use" \
            --almost-all \
            --classify \
            --color=always \
            --group-directories-first \
            --hide-control-chars \
            --human-readable \
            --ignore="*.pyc" \
            --ignore=".*.swp" \
            --ignore=".DS_Store" \
            --ignore=".git" \
            --ignore=".hg" \
            --ignore=".pytest_cache" \
            --ignore=".ruff_cache" \
            --ignore=".sass-cache" \
            --ignore=".svn" \
            --ignore=".swp" \
            --ignore="__pycache__" \
            --literal \
            --time-style=local \
            -X \
            -l \
            -v \
            ${extra_args}
    else
        # OS X `ls`
        ls -a -l -F -G ${extra_args}
    fi
}

conditional_l() {
    if [[ -t 0 ]]; then
        # Run `ls' when shell is interactive (e.g. "$ l").
        _ls "${@}"
    else
        # Run `less' when shell is non-interactive (e.g. "$ my_command | l").
        less
    fi

}
alias l="conditional_l"

alias_bak() {
    timestamp=$(date +"%Y-%m-%d_%H%M%S")

    local cp_to_use
    if which "gcp" &> /dev/null; then
      cp_to_use="gcp"
    else
      cp_to_use="cp"
    fi

    for source in "${@}"; do
        echo "source: ${source}"

        if [[ -f "${source}" ]]; then
            # Source is a file.
            filename="${source}"
            extension=$(basename "${filename##*.}")
            base_filename="${filename%.*}"
            new_filename="${base_filename}_${timestamp}.${extension}"
            if [[ ! -f "${new_filename}" ]]; then
                "$cp_to_use" --interactive --verbose "${filename}" "${new_filename}"
            else
                echo "destination \"${new_filename}\" exists"
                file "${new_filename}"
            fi
        elif [[ -d "${source}" ]]; then
            # Source is a directory.
            folder_name="${source%/}"
            new_folder_name="${folder_name}_${timestamp}"
            if [[ ! -d "${new_folder_name}" ]]; then
                "$cp_to_use" --interactive --recursive --verbose "${folder_name}" "${new_folder_name}"
            else
                echo "destination \"${new_folder_name}\" exists"
                file "${new_folder_name}"
            fi
        else
            echo "Error: source \"${source}\" is not a file or directory."
            return 1
        fi
    done
}
alias bak="alias_bak"

conditional_c() {
    # clear, cd $dir, $cat $filename [$filename ...], or clipboard
    if [[ -t 0 ]]; then
        # Keyboard input (interactive).
        param_count="${#}"
        # Call `clear' when no parameters are passed (e.g. c).
        if [[ "${param_count}" -eq 0 ]]; then
            clear
        # Call `cd $dir' when a single parameter is passed and it is a directory (e.g. c ~/dir).
        elif [[ "${param_count}" -eq 1 ]] && [[ -d "${1}" ]]; then
            cd "${1}"
        # Call `cat $filename [$filename ...]' when one or more parameters are passed (e.g. c file1.log file2.log).
        else
            cat "${@}"
        fi
    else
        # Pipe input (non-interactive).
        # Run clipboard when alias c is piped.
        clipboard
    fi
}
alias c="conditional_c"

alias ct="clear && alias_tree"

list_dirstack() {
    i=0
    for dir in $(\dirs -p | awk '!x[$0]++' | head -n 10); do
        echo " ${i}  ${dir}"
        ((i++))
    done
}
alias dirs="list_dirstack"

pushd() {
    if [[ "${#}" -eq 0 ]]; then
        DIR="${HOME}"
    else
        DIR="${1}"
    fi

    builtin pushd "${DIR}" > /dev/null

    i=0
    for dir in $(\dirs -p | awk '!x[$0]++' | head -n 10); do
        alias -- "${i}"="cd ${dir}"
        ((i++))
    done
}
#alias "cd"="pushd"

better_cd() {
    # Allow cd-ing to a file's directory when a file path has been specified as the argument to cd.
    if [[ "${#}" -eq 0 ]]; then
        builtin cd
    elif [[ "${#}" -eq 1 ]]; then
        directory="${1}"
        if [[ -f "${directory}" ]]; then
            directory="$(dirname "${directory}")"
        fi

        builtin cd "${directory}" 2> /dev/null
        exit_code="${?}"

        # Display list of directories to choose from when `cd' command fails.
        # Reduces errors caused by autocomplete not completing when there are
        # multiple matches like the following:
        #   $ cd folder_2022-
        #   -bash: cd: folder_2022-: No such file or directory

        if [[ "${exit_code}" -ne 0 ]]; then
            # Check for directory starting with the specified directory name.
            actual_directory="$(find . -iname "${directory}*" -type d -maxdepth 1 | fzf --exit-0)"
            starts_with_exit_code="${?}"

            # On no match, check for directory containing the specified directory name.
            if [[ "${starts_with_exit_code}" -eq 1 ]]; then
                actual_directory="$(find . -iname "*${directory}*" -type d -maxdepth 1 | fzf --exit-0)"
                contains_exit_code="${?}"
            fi

            better_cd "${actual_directory}"
        fi
    fi
}

conditional_cd() {
    # Allow changing directory when "cd" is called for changing the directory,
    # but also allow piping to colordiff using the "cd" alias.
    #
    # Examples:
    #   $ cd path/to/dir
    #   (Calls regular cd to change into the directory.)
    #
    #   $ wdiff original.txt changed.txt | cd
    #   (pipes wdiff result to colordiff)

    # Keyboard input (interactive).
    if [[ -t 0 ]]; then
        # Run cd alias when not piped.
        better_cd "${@}"

    # Pipe input (non-interactive).
    else
        # Run colordiff when alias cd is piped.
        colordiff
    fi
}
alias "cd"="conditional_cd"

ask_to_create_files() {
    # FIXME: Only proceed to open files that exist or were created. (e.g. $ v foo File "foo.txt" doesn't exist. Create
    # file? n The file /path/to/foo.txt does not exist.)

    create_all_subsequent_files=false
    for filename in "${@}"; do
        # Skip parameter specified for setting cursor line position.
        if [[ "${filename}" == "+"* ]]; then
            continue
        fi

        # Not (exists and is a directory).
        if [[ ! -d "${filename}" ]]; then
            # Not (file exists).
            if [[ ! -e "${filename}" ]]; then

                if $create_all_subsequent_files; then
                    response="y"
                else
                    response="$(display_confirm_prompt "File \"${filename}\" doesn't exist. Create file? [y/n/a]")"
                    if [[ "${response}" =~ ^[Aa]$ ]]; then
                        create_all_subsequent_files=true
                        response="y"
                    fi
                fi
                # echo "response: ${response}"

                if [[ "${response}" =~ ^[Yy]$ ]]; then
                    # echo "creating file: ${filename}"
                    touch "${filename}"
                else
                    echo "not creating file: ${filename}"
                fi
            fi
        fi
    done
}

edit() {
    editor="alias_vim"

    # Display option for selecting which file to edit when no file has been
    # specified. Automatically select file when there's only one file.
    if [[ $# -eq 0 ]] && is_git; then
        root_dir="$(git rev-parse --show-toplevel)"
        files_to_edit=()

        # Look for staged files.
        #  Added - "^A "
        #  Modified - "^M "
        #  Staged and modified - "^MM ".
        staged_files_result=$(
            git status --porcelain |
                \grep --extended-regexp "^(A |M |MM )" |
                awk '{print $2}'
        )

        if [[ ! -z "${staged_files_result}" ]]; then
            files_to_edit+=("${staged_files_result}")
        fi

        # Look for renamed files.
        #  Renamed - "^R ".
        renamed_files_result=$(
            git status --porcelain |
                \grep --extended-regexp "^(R )" |
                awk '{print $4}'
        )
        if [[ ! -z "${renamed_files_result}" ]]; then
            files_to_edit+=("${renamed_files_result}")
        fi

        # Fallback to looking for modified files.
        if [[ "${#files_to_edit[*]}" -eq 0 ]]; then
            modified_files_result=$(
                git status --porcelain |
                    \grep "^ M " |
                    awk '{print $2}'
            )

            if [[ ! -z "${modified_files_result}" ]]; then
                files_to_edit+=("${modified_files_result}")
            fi
        fi

        # Fallback to looking for files with unmerged changes.
        if [[ "${#files_to_edit[*]}" -eq 0 ]]; then
            unmerged_files_result=$(
                git status --porcelain |
                    \grep "^UU " |
                    awk '{print $2}'
            )

            if [[ ! -z "${unmerged_files_result}" ]]; then
                files_to_edit+=("${unmerged_files_result}")
            fi
        fi

        # Lastly, look for untracked files.
        if [[ "${#files_to_edit[*]}" -eq 0 ]]; then
            untracked_files_result=$(
                git status --porcelain |
                    \grep "^?? " |
                    awk '{print $2}'
            )

            if [[ ! -z "${untracked_files_result}" ]]; then
                files_to_edit+=("${untracked_files_result}")
            fi
        fi

        fzf_preview='
            file_path="'"${root_dir}"'/"{}
            file_diff="$(git diff --color=always "${file_path}")"
            if [[ -z "${file_diff}" ]]; then
                git diff --color=always --cached "${file_path}"
            else
                git diff --color=always "${file_path}"
            fi
        '

        files_to_edit_lines="$(echo "${files_to_edit[*]}")"
        files_to_edit_lines="$(echo "${files_to_edit_lines}" | sort | uniq)"

        result="$(echo "${files_to_edit_lines}" |
            fzf \
                --exit-0 \
                --info="hidden" \
                --multi \
                --preview-window="up:100" \
                --preview="${fzf_preview}" \
                --select-1 \
        )"

        return_code="${?}"

        # Stop edit when canceled.
        # "130 Interrupted with CTRL-C or ESC"
        if [[ "${return_code}" -eq 130 ]]; then
            echo "(canceled)"
            return
        fi

        # Show notice when no file was selected.
        if [[ -z "${result}" ]]; then
            echo "(no file selected)"
        fi

        # Open files from the git root directory since the paths returned will
        # be relative to the git root diretory.
        pushed_dir=false
        if [[ ! -z "${result}" ]] && [[ "${PWD}" != "${root_dir}" ]]; then
            pushd "${root_dir}"
            pushed_dir=true
        fi

        editor_args="$(echo "${result}" | tr '\n' ' ')"
        # "${editor}" $(echo "${editor_args}")
        open -a "Visual Studio Code.app" $(echo "${editor_args}")

        if $pushed_dir; then
            popd
        fi
    else
        # Ask to create the file if it doesn't exist.
        ask_to_create_files "${@}"

        # "${editor}" ${@}
        open -a "Visual Studio Code.app" "${@}"
    fi
}
alias e="edit"

alias_grep() {
    if [[ -t 0 ]]; then
        # Run grep with line numbers when shell is interactive (e.g.
        # "$ grep ...").
        grep \
            --binary-files="without-match" \
            --color \
            --exclude-dir=".git" \
            --exclude-dir=".hg" \
            --exclude-dir=".pytest_cache" \
            --exclude-dir=".svn" \
            --exclude-dir="chunks" \
            --exclude-dir="node_modules" \
            --exclude-dir="vendor" \
            --exclude=".phpunit.result.cache" \
            --line-number \
            "$@"
    else
        # Run grep without line numbers when shell is non-interactive (e.g.
        # "$ my_command | grep ...").
        grep \
            --binary-files="without-match" \
            --color \
            --exclude-dir=".git" \
            --exclude-dir=".hg" \
            --exclude-dir=".pytest_cache" \
            --exclude-dir=".svn" \
            --exclude-dir="chunks" \
            --exclude-dir="node_modules" \
            --exclude-dir="vendor" \
            --exclude=".phpunit.result.cache" \
            --line-number \
            "$@"
    fi
}
alias grep="alias_grep"

alias h="history"

conditional_j() {
    if [[ -t 0 ]]; then
        # Run `jobs' when shell is interactive (e.g. "$ jobs").
        jobs "${@}"
    else
        # Run `jq' when shell is non-interactive (e.g. "$ cat response.json | jq").
        alias_jq
    fi
}
alias j="conditional_j"

alias o="alias_open"
alias oo="alias_open ."

fin() {
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        osascript -e 'display notification "" with title "Done"'
    else
        terminal-notifier -message "" -title "Done" 2> /dev/null
        if [[ $? -eq 127 ]]; then
            notify-send --expire-time=1000 "Done $(date)"
        fi
    fi
}

case_sensitive_search() {
    param_count="${#}"

    # Search by keyword (e.g. `s keyword').
    if [[ "${param_count}" -eq 1 ]]; then
        keyword="${1}"

        set -x
        grep \
            --dereference-recursive \
            "${keyword}" . "${@:2}"
        set +x

    # Search by extension + keyword (e.g. `s ext keyword').
    elif [[ "${param_count}" -eq 2 ]]; then
        extension="${1}"
        keyword="${2}"

        set -x
        grep \
            --include="*.${extension}" \
            --dereference-recursive \
            "${keyword}" . "${@:3}"
        set +x

    fi
}
alias ss="case_sensitive_search"

case_sensitive_search_edit() {
  param_count="${#}"
  if [[ "${param_count}" -eq 0 ]]; then
    return
  else
    # Search by keyword and edit (e.g. `sse keyword').
    if [[ "${param_count}" -eq 1 ]]; then
      keyword="${1}"
      results=$(grep --dereference-recursive --files-with-matches "${keyword}" . "${@:2}")
    # Search by extension + keyword and edit (e.g. `sse ext keyword').
    elif [[ "${param_count}" -eq 2 ]]; then
      extension="${1}"
      keyword="${2}"
      results=$(grep --dereference-recursive --files-with-matches --include="*.${extension}" "${keyword}" . "${@:3}")
    fi

    _open_files "${results}"
  fi
}
alias sse="case_sensitive_search_edit"

case_insensitive_search() {
    param_count="${#}"

    # Search by keyword (e.g. `s keyword').
    if [[ "${param_count}" -eq 1 ]]; then
        keyword="${1}"

        set -x
        grep \
            --ignore-case \
            --dereference-recursive \
            "${keyword}" . "${@:2}"
        set +x

    # Search by extension + keyword (e.g. `s ext keyword').
    elif [[ "${param_count}" -eq 2 ]]; then
        extension="${1}"
        keyword="${2}"

        set -x
        grep \
            --ignore-case \
            --include="*.${extension}" \
            --dereference-recursive \
            "${keyword}" . "${@:3}"
        set +x

    fi
}
alias si="case_insensitive_search"

conditional_s() {
  param_count="${#}"
  if [[ "${param_count}" -eq 0 ]]; then
    # Show version control status when no parameters are passed.
    rc_status

  else
    case_insensitive_search "${@}"
  fi
}
alias s="conditional_s"

case_insensitive_search_edit() {
  param_count="${#}"
  if [[ "${param_count}" -eq 0 ]]; then
    return
  else
    # Search by keyword and edit (e.g. `se keyword').
    if [[ "${param_count}" -eq 1 ]]; then
      keyword="${1}"
      results=$(grep --dereference-recursive --files-with-matches --ignore-case "${keyword}" . "${@:2}")
    # Search by extension + keyword and edit (e.g. `se ext keyword').
    elif [[ "${param_count}" -eq 2 ]]; then
      extension="${1}"
      keyword="${2}"
      results=$(grep --dereference-recursive --files-with-matches --ignore-case --include="*.${extension}" "${keyword}" . "${@:3}")
    fi

    _open_files "${results}"
  fi
}

conditional_se() {
    if [[ "${#}" -eq 0 ]]; then
        quilt series "${@}"
    else
        case_insensitive_search_edit "${@}"
    fi
}
alias se="conditional_se"

case_sensitive_search_python() {
  if [[ -z "${1}" ]]; then
    return
  fi
  set -x
  grep -R --include="*.py" "${1}" . "${@:2}"
  set +x
}
alias spy="case_sensitive_search_python"

case_insensitive_search_python() {
  if [[ -z "${1}" ]]; then
    return
  fi
  set -x
  grep -Ri --include="*.py" "${1}" . "${@:2}"
  set +x
}
alias sipy="case_insensitive_search_python"

# Print hidden files.
alias_tree() {
  tree \
    -a \
    -F \
    -I ".git" \
    -I "__pycache__" \
    -I "node_modules" \
    $@
}
alias tree="alias_tree"
alias t="alias_tree"

_top() {
    if ! which htop &> /dev/null; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            set -x
            sudo apt-get install -y htop
            set +x
        fi
    fi

    if which htop &> /dev/null; then
        htop --sort-key=PERCENT_MEM
    else
        top -o cpu
        if [[ $? -ne 0 ]]; then
            top
        fi
    fi
}
alias top="_top"

alias addrepo="sudo add-apt-repository"
alias autoclean="sudo apt-get autoclean"
alias autoremove="sudo apt-get autoremove"
alias clean="sudo apt-get clean"
alias distupgrade="sudo apt-get dist-upgrade"
alias upgrade="sudo apt-get upgrade"
alias reboot="sudo shutdown -r now"

quit() {
    # Quit Terminal when the last tab is closed.
    if [[ "${TERM_PROGRAM}" == "Apple_Terminal" ]]; then
        quit_terminal_when_no_terminals_remain() {
            osascript -e 'tell application "Terminal" to if running and (count every tab of every window whose tty is not "'"$(tty)"'") is 0 then quit' &
        }
        trap quit_terminal_when_no_terminals_remain EXIT
    fi
    exit
}

conditional_x() {
    if [[ "${#}" -eq 0 ]]; then
        # Quit as no parameters were passed.
        quit
    else
        # Make files executable when all parameters passed are files.
        all_are_files=true
        for filename in "${@}"; do
            if [[ ! -f "${filename}" ]]; then
                echo "Warning: \"${filename}\" is not a file."
                all_are_files=false
            fi
        done

        if ! $all_are_files; then
            echo "Error: Not all specified parameters are files. Stopping."
            return 1
        else
            for filename in "${@}"; do
                echo "+x ${filename}"
                chmod +x "${filename}"
            done
        fi
    fi
}
alias x="conditional_x"

_conditional_q() {
    if [[ "${#}" -eq 0 ]]; then
        quit
    else
        quilt "${@}"
    fi
}
alias q="_conditional_q"

alias_open() {
    args=("${@}")

    # Open current directory when no path is specified.
    if [[ "$#" -eq 0 ]]; then
        args[0]="."
    fi

    open "${args[@]}" &> /dev/null
    if [[ ! $? -eq 0 ]]; then
        nautilus "${args[@]}"
    fi
}

_ip() {
    if [[ -x /sbin/ifconfig ]]; then
        /sbin/ifconfig
    else
        ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //' | sort | sed 's/\('$(ipconfig getifaddr en1)'\)/\1 [LOCAL]/'
    fi
}
alias ip="_ip"

alias dotfiles="dotstar"
alias dotstar="cd ${HOME}/.dot-star && l"
alias ".*"="dotstar"
alias extra="vim ${HOME}/.dot-star/bash/extra.sh"
alias hosts="sudo vim /etc/hosts"
alias known_hosts="vim ${HOME}/.ssh/known_hosts"
alias sshconfig="vim ${HOME}/.ssh/config"

alias aliases="vim ${HOME}/.dot-star/bash/.aliases.sh"
alias bashprofile="vim ${HOME}/.bash_profile"
alias bashrc="vim ${HOME}/.bashrc"
alias inputrc="vim ${HOME}/.inputrc"
alias screenrc="vim ${HOME}/.screenrc"

if [[ "${SHELL}" == *"/bash" ]]; then
    alias +w="chmod +w"
    alias +x="chmod +x"
fi

large_files() {
    du --human-readable --summarize --total .[!.]* * | sort --human-numeric-sort
}
alias large="large_files"

slugify() {
    if [[ "${#}" -eq 0 ]]; then
        read stdin
    else
        stdin="${*}"
    fi

    script="
import re
import sys

value = sys.stdin.read().rstrip()
value = re.sub(r'[/]', '-', value)
value = re.sub(r'[^\w\s\.-]', '', value.lower())
print(re.sub(r'[-\s]+', '-', value).strip('-_'))
"
    echo "${stdin}" | python3 -c "${script}"
}
alias slug="slugify"

slugify_mv() {
    for filename in "${@}"; do
        new_filename=$(slugify "${filename}")
        if [[ "${new_filename}" != "${filename}" ]]; then
            # TODO: Ensure destination doesn't exist. Append the first available number to file name if needed.
            # TODO: Display result file rename without asking for confirmation.
            message='Rename "'${filename}'" to "'${new_filename}'"?'
            read -p "${message} [y/n] " -n 1 -r; echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mv "${filename}" "${new_filename}"
            fi
        else
            echo "${filename} OK"
        fi
    done
}
alias smv="slugify_mv"

pdf_remove_password() {
    # Remove password from one or more pdf files.
    # @usage: pdf_remove_password file.pdf
    # @usage: echo "thepassword" | pdf_remove_password file.pdf

    if ! which "qpdf" &> /dev/null; then
        set -x
        brew install qpdf
        set +x
    fi

    green=$(tput setaf 64)
    red=$(tput setaf 124)

    read -r -s -p "enter pdf password: " "password"; echo
    for filename in "$@"; do
        in="${filename}"
        out=$(echo "${in}" | perl -pe 's/^(.*)(\.pdf)$/\1_passwordless.pdf/')
        qpdf --decrypt --password="${password}" "${in}" "${out}"
        if [[ $? -eq 0 ]]; then
            echo -e "${red}- ${in}"
            echo -e "${green}+ ${out}"
            # rm -v "${in}"
        fi
    done
}
alias remove_pdf_password="pdf_remove_password"

change_mac_address() {
    current_mac_address=$(ifconfig en0 | \grep ether | perl -pe 's/^\s+ether (.*) /\1/')
    echo -e "\033[31m-${current_mac_address}\033[0m"

    new_mac_address=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')
    echo -e "\033[32m+${new_mac_address}\033[0m"

    sudo ifconfig en0 ether "${new_mac_address}"

    current_mac_address=$(ifconfig en0 | \grep ether | perl -pe 's/^\s+ether (.*) /\1/')
    if ! [[ $new_mac_address == $current_mac_address ]]; then
        echo "DIFFERENCE FOUND"
        echo "expected ${new_mac_address}"
        echo "got      ${current_mac_address}"
    fi

    sudo ifconfig en0 down
    sudo ifconfig en0 up
}

alias_chmod() {
    option_found=false
    for param in "${@}"; do
        if [[ "${param}" == "-"* ]] || [[ "${param}" == "+"* ]]; then
            option_found=true
            break
        fi
    done

    # Run chmod when any option is specified.
    if $option_found; then
        command chmod "${@}"

    # Display file mode bits for all files specified.
    else
        for filename in "${@}"; do
            file_mode_bits="$(gstat --format "%a" "${filename}")"
            echo -e "${file_mode_bits}\t${filename}"
        done
    fi
}
alias chmod="alias_chmod"

conditional_f() {
    if [[ -t 1 ]]; then
        interactive=true
    else
        interactive=false
    fi

    # Run fg when no parameters are passed, otherwise find files with path containing the specified keyword.
    if [[ $# == 0 ]]; then
        fg
    else
        # Find files by keyword.
        keyword="${1}"
        if [[ -z "${keyword}" ]] ; then
            if $interactive; then
                echo "Search is empty"
            fi
        else
            if $interactive; then
                echo "Searching paths and filenames containing \"*${keyword}*\":" | \grep --color --ignore-case "${keyword}"
            fi

            set -x
            find . \
                -type "f" \
                -iname "*${keyword}*" \( \
                    -path "*/__pycache__/*" -prune \
                    -o -iname "*.pyc" -prune \
                \) -o -print |
                \grep --color --ignore-case "${keyword}"
            set +x
        fi
    fi
}
alias f="conditional_f"

find_and_edit() {
    param_count="${#}"
    if [[ "${param_count}" -eq 0 ]]; then
        return
    else
        # Find files by keyword and edit (e.g. `fe keyword').
        keyword="${1}"
        set -x
        results=$(
            find . \
                -type "f" \
                -iname "*${keyword}*" \( \
                    -path "*/__pycache__/*" -prune \
                    -o -iname "*.pyc" -prune \
                \) -o -print |
                \grep --color --ignore-case "${keyword}"
        )
        set +x
        _open_files "${results}"
    fi
}
alias fe="find_and_edit"

un() {
    filename="${1}"
    script="
import os
import sys


filename = sys.stdin.read().rstrip()
command = ''
if filename.endswith('.zip'):
    command = 'unzip'
elif filename.endswith(('.tar.bz2', '.tar.gz', '.tar.xz',)):
    command = 'tar xvf'
elif filename.endswith('.gz'):
    command = 'gunzip'
if command:
    print(command)
else:
    sys.exit(1)
"
    command=$(echo "${filename}" | python -c "${script}")
    if [[ "${?}" -ne 0 ]]; then
        echo "Error: unknown extension (filename=${filename})"
    else
        echo "command: ${command}"
        ${command} "${1}"
    fi
}

get_file_info() {
    if [[ "${#}" -eq 1 ]]; then
        response=$(command type "${1}" 2> /dev/null)
        if [[ $? -eq 0 ]]; then
            script=$(cat <<"EOF"
try:
    from shlex import quote
except ImportError:
    from pipes import quote
import re
import sys

response = sys.stdin.read().rstrip()
match = re.match(r".* is aliased to \`([\w]+)'", response)
if match is not None:
    print('builtin type {0}'.format(quote(match.group(1))))
EOF
)
            cmd=$(echo "${response}" | python -c "${script}")
            if [[ ! -z "${cmd}" ]]; then
                ${cmd}
                return
            fi
        fi

        file_size=$(printf "%'d" $(gstat --printf="%s" "${1}"))
        echo "$($(which file) "${1}") (${file_size} bytes)"
        if [[ "${1}" == *.mp3 ]]; then
            # command -v ffmpeg >/dev/null 2>&1 && ffmpeg -i "${1}" 2>&1 | \grep "Duration: "

            info=$(afinfo "${1}" | grep "estimated duration: ")
            python - << EOF
import datetime
import re
info = """${info}"""
seconds = float(re.match('.*?(\d+\.\d+).*?', info).group(1))
print(str(datetime.timedelta(seconds=round(seconds))))
EOF
        fi
    else
        file_bin="$(which file)"
        target_file="${@}"
        "${file_bin}" "${target_file}"
    fi
}
alias file="get_file_info"

# Comment to because it's messing up code completion.
# Temporarily disable alias "type" as it makes bash-completion slow.
# alias type="get_file_info"
alias ty="get_file_info"

is_ssh() {
    if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        # Using ssh.
        return 0
    fi
    # Not using ssh.
    return 1
}

serve_dir() {
    port="8080"
    read -p "Are you sure you want to serve the current directory over port ${port}? [y/n] " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "http://localhost:${port}/"
        set -x
        python -m SimpleHTTPServer "${port}"
        set +x
    fi
}

_run_watchman() {
    loop="${1}"
    pattern_to_watch="${2}"
    cmd_to_run="${3}"

    # echo "_run_watchman"
    # echo "  loop: ${loop}"
    # echo "  pattern_to_watch: ${pattern_to_watch}"
    # echo "  cmd_to_run: ${cmd_to_run}"

    i=0
    watchman_exit_code="0"
    while :; do
        # set -x
        response="$(
            watchman-wait \
                --max-events="1" \
                --pattern "${pattern_to_watch}" \
                -- \
                . \
                2>&1
        )"
        watchman_exit_code="${?}"
        # set +x

        # Detect when permission is denied even though exit code is unexpectedly 0.
        # Error message: "watchman: watchman command error:
        # std::__1::system_error: open: /path/to/dir: Operation not permitted".
        if [[ "${response}" == *"Operation not permitted" ]]; then
            echo "Error running watchman."
            echo

            echo "Response:"
            echo "${response}"
            echo ""

            echo "exit code: ${watchman_exit_code}"
            echo

            echo "Maybe try the following to fix the \"Operation not permitted\" error:"
            echo "  brew uninstall watchman"
            echo "  brew install watchman"
            echo "  watchman shutdown-server"
            echo "  watchman watch-del-all"
            echo

            break
        fi

        if [[ "${watchman_exit_code}" -ne 0 ]]; then
            echo "Error running watchman."
            echo

            echo "${response}"
            echo "exit code: ${watchman_exit_code}"
            echo

            break
        fi

        file_changed="${response}"

        # Ignore changes to files starting with periods (e.g. cache files like ".phpunit.result.cache" that could cause
        # an endless loop).
        if [[ "${file_changed}" == "."* ]]; then
            continue
        fi

        # "0 is returned after successfully waiting for event(s)".
        if [[ "${watchman_exit_code}" -eq 0 ]]; then
            cols="$(tput cols)"
            echo "$(bash -c "printf -- '=%.0s' {1..${cols}}")"
            clear

            bash -c "${cmd_to_run}"
            command_exit_code="${?}"

            # Calculate width of line separator between each command execution
            # and right before printing the separator to account for resizing.
            cols="$(tput cols)"

            if [[ $((i%4)) -eq 0 ]]; then
                sep="$(bash -c "printf -- '-%.0s' {1..${cols}}")"
            elif [[ $((i%4)) -eq 1 ]]; then
                sep="$(bash -c "printf -- '\%.0s' {1..${cols}}")"
            elif [[ $((i%4)) -eq 2 ]]; then
                sep="$(bash -c "printf -- '|%.0s' {1..${cols}}")"
            elif [[ $((i%4)) -eq 3 ]]; then
                sep="$(bash -c "printf -- '/%.0s' {1..${cols}}")"
            fi

            if [[ "${command_exit_code}" -ne 0 ]]; then
                error "${sep}"
                echo -e "\\033[4;31mError:\\033[0m exit code ${command_exit_code}"
                echo -e "\\033[34mCommand:\\033[0m \`${cmd_to_run}'"
            else
                success "${sep}"
            fi
        fi

        if ! $loop; then
            # echo "not a loop; breaking"
            break
        fi

        # echo "sleeping"
        sleep 1
        # echo "done sleeping"

        (( i += 1 ))
    done

    # echo "done running watchman"
    return "${watchman_exit_code}"
}

_get_command_for_file_type() {
    # Add prefix to command based on file name extension.
    python_script=$(cat <<'EOF'
import os
try:
    from shlex import quote
except ImportError:
    from pipes import quote
import sys

command_or_file_name = sys.argv[1]
if os.path.isfile(command_or_file_name):
    file_name = command_or_file_name
    _, file_extension = os.path.splitext(file_name)
    filepath = os.path.abspath(file_name)
    cmd = ''
    if file_extension == '.sh':
        cmd = 'bash {0}'.format(quote(file_name))
    elif file_extension == '.go':
        cmd = 'go run {0}'.format(quote(file_name))
    elif file_extension == '.js':
        cmd = 'node {0}'.format(quote(file_name))
    elif file_extension == '.php':
        cmd = 'php {0}'.format(quote(file_name))
    elif file_extension == '.py':
        cmd = 'python3 {0}'.format(quote(file_name))
else:
    cmd = command_or_file_name
print(cmd)
EOF
)
    cmd_to_run=$(python -c "${python_script}" "${command_or_file_name}")
    echo "${cmd_to_run}"
}

watch_dir() {
    # Watch the current directory for changes and run a command.
    # Usage:
    #   $ watch_dir "bash file_changed.sh"
    #   $ watch_dir script.sh
    #   $ watch_dir script.go
    #   $ watch_dir script.js
    #   $ watch_dir script.php
    #   $ watch_dir script.py
    #   $ while :; do watch_dir; my_alias; done
    #   $ while :; f5_pos="482,425"; do wd; cur_pos="$(cliclick p)"; cliclick "dc:${f5_pos}"; cliclick "c:${cur_pos}"; sleep 1; done
    _require_watchman

    # Watch the current directory and return on change when no parameters are
    # specified.
    if [[ $# -eq 0 ]]; then
        loop=false
        pattern_to_watch='**'
        cmd_to_run=""

    # Watch the current directory and run the specified command (parameter 1)
    # when one parameter is specified.
    elif [[ $# -eq 1 ]]; then
        loop=true
        # Use a glob pattern (not a regular expression) that excludes period-prefixed files which would otherwise cause
        # endless triggering. For example, using watchman-make with --pattern "**" and --run "phpunit [...]" causes a
        # cache file (".phpunit.result.cache") to be continually updated and a another execution.
        #
        # Update: Use the "**" pattern so that recursive matching works. Even though changes to files like
        # .phpunit.result.cache will be detected, an additional check has been added to ignore changes to files starting
        # with a period. Using the '[!\.]*' pattern correctly ignores changes to files starting with periods, but
        # doesn't correct detect changes to files within directories.
        pattern_to_watch='**'
        command_or_file_name="${1}"
        cmd_to_run="$(_get_command_for_file_type "${command_or_file_name}")"
    else
        echo "Error: 1 parameter required"
        return
    fi

    _run_watchman "${loop}" "${pattern_to_watch}" "${cmd_to_run}"
}
alias wd="watch_dir"

alias_watch_file() {
    # Watch a file for changes and run a command.
    # Usage:
    #   $ watch_file file_to_watch.log "bash file_changed.sh"
    #   $ watch_file "bash file_changed.sh"
    #   $ watch_file script.sh
    #   $ watch_file script.go
    #   $ watch_file script.js
    #   $ watch_file script.php
    #   $ watch_file script.py
    _require_watchman

    # Watch the specified file (parameter 1) only for changes and run its
    # related command when only one parameter is specified.
    if [[ $# -eq 1 ]]; then
        loop=true
        pattern_to_watch="${1}"
        command_or_file_name="${1}"
        cmd_to_run="$(_get_command_for_file_type "${command_or_file_name}")"

    # Watch the specified pattern (parameter 1) for changes and run the
    # specified command (parameter 2) when two parameters are specified.
    elif [[ $# -eq 2 ]]; then
        loop=true
        pattern_to_watch="${1}"
        cmd_to_run="${2}"

    else
        echo "Error: 1 or 2 parameters required"
        return
    fi

    # Ensure pattern uses a relative path. Without this, specifying an absolute file path as the pattern to watch won't
    # trigger changes.
    #
    # From `watchman-wait --help':
    #   "Patterns are applied by the watchman server and are matched against the root-relative paths"
    #
    # For example:
    #   Doesn't work:
    #   $ cd ~/Projects
    #   $ watchman-wait --max-events=1 --pattern /Users/user/Projects/project/src/parse.php -- .
    #
    #   Works:
    #   $ cd ~/Projects
    #   $ watchman-wait --max-events=1 --pattern project/src/parse.php -- .
    if [[ "${pattern_to_watch}" == "/"* ]]; then
        # echo "pattern is root"
        # echo "current directory is ${PWD}"
        # echo "          pattern is ${pattern_to_watch}"
        pattern_to_watch_before="${pattern_to_watch}"
        pattern_to_watch_after="${pattern_to_watch/$PWD\//}"
        # diff_strings_like_files "${pattern_to_watch_before}" "${pattern_to_watch_after}"

        pattern_to_watch="${pattern_to_watch_after}"
    else
        echo "pattern is not root"
    fi

    _run_watchman "${loop}" "${pattern_to_watch}" "${cmd_to_run}"
}
alias watch_file="alias_watch_file"
alias wf="alias_watch_file"

alias watch_del_all="watchman watch-del-all"
alias wda="watchman watch-del-all"

alias watch_list="watchman watch-list"
alias wl="watchman watch-list"

checksum() {
    filename="${1}"
    echo -e "\nmd5sum:"
    md5sum "${filename}"

    echo -e "\nsha1sum:"
    sha1sum "${filename}"

    echo -e "\nsha224sum:"
    sha224sum "${filename}"

    echo -e "\nsha256sum:"
    sha256sum "${filename}"

    echo -e "\nsha384sum:"
    sha384sum "${filename}"

    echo -e "\nsha512sum:"
    sha512sum "${filename}"
}

alias m="md5sum"

ipython_wrapper() {
    ipython \
        --TerminalInteractiveShell.confirm_exit="False" \
        --TerminalInteractiveShell.editing_mode="vi" \
        --TerminalInteractiveShell.editor="vi"
}
alias ipy="ipython_wrapper"
alias py="python"

edit_extension_files() {
    files_to_edit=()

    # Open background.js.
    background_results=$(find . -iname "background.js" | head -1)
    if [[ ! -z "${background_results}" ]]; then
        echo "background_results: ${background_results}"
        files_to_edit+=("${background_results}")
    fi

    # Open JavaScript files.
    javascript_results=$(find . -iname "*.js" ! -path "*/node_modules/*")
    if [[ ! -z "${javascript_results}" ]]; then
        echo -e "javascript_results:\n${javascript_results}"
        files_to_edit+=("${javascript_results}")
    fi

    # Open style.scss or style.css in a child directory.
    style_results=$(find . -iname "style.scss" | head -1)
    scss_found=false
    if [[ -z "${style_results}" ]]; then
        style_results=$(find . -iname "style.css" | head -1)
    else
        scss_found=true
    fi
    if [[ ! -z "${style_results}" ]]; then
        echo "style_results: ${style_results}"
        files_to_edit+=("${style_results}")
    fi

    # Open style.scss or style.css in a child directory.
    manifest_results=$(find . -iname "manifest.json" | head -1)
    if [[ ! -z "${manifest_results}" ]]; then
        echo "manifest_results: ${manifest_results}"
        files_to_edit+=("${manifest_results}")
    fi

    if [[ -z "${files_to_edit}" ]]; then
        echo "no extension files to edit"
    else
        edit "${=files_to_edit}"

        if $scss_found; then
            echo "running sasswatch"
            dir="$(dirname "${style_results}")/"
            _sasswatch "${dir}style.scss"
        fi
    fi
}
alias ext="edit_extension_files"

conditional_d() {
    # Diff when 2 parameters are specified and they both are either files or directories.
    if [[ "${#}" -eq 2 ]] && [[ -e "${1}" ]] && [[ -e "${2}" ]]; then
        difference "${1}" "${2}"

    # Run version control diff when no parameters are specified.
    elif is_git; then
        rc_diff $@

    # Otherwise, run Docker.
    else
        docker "${@}"
    fi
}
alias d="conditional_d"

generate_key() {
    read -p "authority (e.g. github, etc.)? " -r
    authority="${REPLY}"

    read -p "account (e.g. \"${USER}\", etc.)? " -r
    account="${REPLY}"

    keyfile="${HOME}/.ssh/id_rsa_${authority}_${account}"
    echo "authority: ${authority}"
    echo "account: ${account}"
    echo "keyfile: ${keyfile}"

    if [[ -f "${keyfile}" ]]; then
        echo "file exists: ${keyfile}"
        return 1
    fi

    read -p "Look good? [y/n] " -n 1 -r; echo
    if ! [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "exiting"
        return
    fi

    set -x
    ssh-keygen -t "rsa" -b "4096" -f "${keyfile}" -C ""
    set +x
}

unlink() {
    for filename in "${@}"; do
        command unlink "${filename}"
    done
}

alias_cp() {
    file_name="${1}"

    # Call modified cp command to edit file name in place when only 1 parameter has been specified.
    if [[ "${#}" -eq 1 ]] && [[ -f "${file_name}" ]]; then
        # Usage:
        #   $ cp myfile.txt
        #   myfile (displayed)
        #   myfile2 (edited and return pressed)
        #   >>> cp myfile.txt myfile2.txt

        file_name_extension="$(basename "${file_name##*.}")"
        file_name_no_extension="${file_name%.*}"

        read -e -i "${file_name_no_extension}" "entered_file_name"

        # Attempt to copy the specified file to a unique name (race condition
        # possible, but not yet worth addressing).
        new_file_name="${entered_file_name}.${file_name_extension}"
        if [[ -f "${new_file_name}" ]]; then
            i=0
            while :; do
                ((i++))
                new_file_name="${entered_file_name}_${i}.${file_name_extension}"
                if ! [[ -f "${new_file_name}" ]]; then
                    echo "${new_file_name} (available)"
                    break
                else
                    echo "${new_file_name} (exists)"
                    sleep .1
                fi
            done
        fi

        command cp "${file_name}" "${new_file_name}" &&
            #(
            #    $DIFF_SO_FANCY_INSTALLED &&
            #    diff --unified <(echo "${file_name}") <(echo -e "${file_name}\n${new_file_name}") | "diff-so-fancy" | tail -n +5
            #) ||
            (
                $COLORDIFF_INSTALLED &&
                diff --unified <(echo "${file_name}") <(echo -e "${file_name}\n${new_file_name}") | "colordiff" | tail -n +4
            ) || (
                diff --unified <(echo "${file_name}") <(echo -e "${file_name}\n${new_file_name}") | tail -n +4
            )

    # Call original cp command when any other number of parameters have been specified.
    else
        command cp "${@}"
    fi
}
alias cp="alias_cp"

response=""
read_with_initial_editable_input() {
    if [[ -n "${ZSH_VERSION}" ]]; then
        response="${1}"
        local prompt="${2}"
        vared -p "${prompt}" response
    elif [[ -n "${BASH_VERSION}" ]]; then
        inital_input="${1}"
        read -i "${inital_input}" -e "new_value"
        response="${new_value}"
    fi
}

alias_mv() {
    file_or_folder_name="${1}"

    file_is_git_tracked=false
    if [[ -f "${file_or_folder_name}" ]]; then
        git ls-files --error-unmatch "${file_or_folder_name}" &> /dev/null
        exit_code="${?}"
        if [[ "${exit_code}" -eq 1 ]]; then :
        elif [[ "${exit_code}" -eq 128 ]]; then :
        else
            file_is_git_tracked=true
        fi
    fi

    # Handle renaming git-tracked files.
    if $file_is_git_tracked; then

        read_with_initial_editable_input "${file_or_folder_name}" "Rename git file: "
        new_file_name="${response}"
        git mv "${file_or_folder_name}" "${new_file_name}" &&
            diff_strings_like_files "${file_or_folder_name}" "${new_file_name}"

    else

        # Call modified mv command to edit folder in place when only 1 parameter has
        # been specified and it's a folder.
        if [[ "${#}" -eq 1 ]] && [[ -d "${file_or_folder_name}" ]]; then
            read_with_initial_editable_input "${file_or_folder_name}" "Edit folder name: "
            new_folder_name="${response}"
            command mv "${file_or_folder_name}" "${new_folder_name}" &&
                diff_strings_like_files "${file_or_folder_name}" "${new_folder_name}"

        # Call modified mv command to edit file name in place when only 1 parameter
        # has been specified and it's a file.
        elif [[ "${#}" -eq 1 ]] && [[ -f "${file_or_folder_name}" ]]; then
            read_with_initial_editable_input "${file_or_folder_name}" "Edit file name: "
            new_file_name="${response}"
            command mv "${file_or_folder_name}" "${new_file_name}" &&
                diff_strings_like_files "${file_or_folder_name}" "${new_file_name}"

        # Display information when parameter is a file.
        elif [[ "${#}" -eq 1 ]] && [[ -f "${file_or_folder_name}" ]]; then
            command file "${@}"

        # Call original mv command when any other number of parameters have been specified.
        else
            command mv "${@}"
        fi

    fi
}
alias mv="alias_mv"

real_path() {
    # Display real path of the current directory when no parameters have been
    # specified.
    if [[ "${#}" -eq 0 ]]; then
        realpath .
    else
        realpath "${@}"
    fi
}
alias rp="real_path"

realpath_copy_to_clipboard() {
    real_path "${@}" | c
}
alias rpc="realpath_copy_to_clipboard"

_man() {
    # Open man pages as html when on a Mac.
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        # Open man pages as html.
        # Previously man pages were opened as pdfs in the Preview application
        # using the following command:
        #   man -t "${@}" | open -f -a Preview
        # However, the minus signs in the resulting pdf were rendered using
        # U+2212 (e2 88 92) instead of the desired U+002d (2d). This causes the
        # program options to not be searchable (e.g. a text search for
        # "--verbose" returns no results). Render to html so that text searches
        # for program options using dashes works as expected. So open the
        # resulting html file in a web browser so that program options are
        # searchable using dashes. While this allows for successful text
        # searching, any selected option still copies the incorrect characters
        # to the clipboard so use `sed' to replace instaces of "&minus;" with
        # dashes.
        man_file_path="$(\man --path "${1}" 2> /dev/null)"
        exit_code="${?}"
        if [[ "${exit_code}" -ne 0 ]]; then
            man_file_path="$(\man -w "${1}" 2> /dev/null)"
            exit_code="${?}"
            if [[ "${exit_code}" -ne 0 ]]; then
                echo "error. exit_code: ${exit_code}"
                return
            fi
        fi

        mkdir -p "${HOME}/man_html/"

        man_file_name="$(basename "${man_file_path}")"
        echo "file name: ${man_file_name}"

        if ! which groff &> /dev/null; then
            set -x
            brew install groff
            set +x
        fi

        if [[ "${man_file_name}" == *".gz" ]]; then
            gunzip --to-stdout "${man_file_path}" |
                groff -mandoc -T html > "${HOME}/man_html/${1}.html"
        else
            groff -mandoc -T html "${man_file_path}" > "${HOME}/man_html/${1}.html"
        fi

        sed -i "" $'s/&minus;/-/g' "${HOME}/man_html/${1}.html"

        open "${HOME}/man_html/${1}.html"

    # Open man pages regularly on all others.
    else
        man "${@}"

        # TODO: Support opening man pages in pdf viewer on other systems.
        # Hint: f=$(mktemp); man -t "$@" > "$f" && ( {some-pdf-viewer} "$f" ; rm "$f" )
    fi
}
alias man="_man"

_byobu_detach() {
    /usr/lib/byobu/include/tmux-detach-all-but-current-client
}
if [[ ! -z "${BYOBU_WINDOW_NAME}" ]]; then
    alias detach="_byobu_detach"
fi

alias by="byobu"

alias k="kill"
alias ka="killall"

alias pc="pre-commit"
alias pca="pre-commit run --all-files"

_type() {
    # Display a list of the currently defined bash functions when the `type'
    # command is run without any parameters.
    if [[ "${#}" -eq 0 ]]; then
        result=$(
            set |
            \grep -E "^_?[a-z][a-z_]+ \()" |
            awk '{ print $1 }' |
            fzf \
                --exit-0 \
                --info="hidden" \
                --preview-window="right:70%" \
                --preview='source ~/.dot-star/bash/.bash_profile; type {}' \
                --select-1
        )
        return_code="${?}"

        # Stop edit when canceled.
        # "130 Interrupted with CTRL-C or ESC"
        if [[ "${return_code}" -eq 130 ]]; then
            return
        fi

        builtin type "${result}"

    # Run regular `type' command.
    else
        builtin type $@
    fi
}
alias type="_type"

go_to_root() {
    # Go to project root.
    while :; do
        if [[ -d ".git" ]]; then
            l
            break
        elif [[ "${PWD}" == "/" ]]; then
            break
        else
            cd ..
        fi
    done
}
alias r="go_to_root"

wget() {
    set -x
    curl --remote-name --user-agent "" "${@}"
    set +x
}

alias wget="wget"
alias wg="wget"

_conditional_w() {
    if [[ "${#}" -eq 0 ]]; then
        w
    else
        wget "${@}"
    fi
}
alias w="_conditional_w"

_outdated() {
    # TODO: Run both `npm outdated' and `brew outdated'.
    npm outdated
}
alias outdated="_outdated"

_repeat() {
  command_with_args_to_repeatedly_do="${@}"

  sequence=0
  while :; do
    # Recalculate cols each iteration as screen may have been resized.
    cols="$(tput cols)"
    echo
    printf -- '#%.0s' $(seq 1 $cols)
    echo
    echo "seq ${sequence} running \`$command_with_args_to_repeatedly_do'"
    $command_with_args_to_repeatedly_do

    (( sequence += 1 ))
    sleep 1
  done
}
alias repeat="_repeat"

_repeat_wd() {
  # Watch directory, run command (or alias!), repeat.
  #
  # $ wdrepeat yarn lint
  # >> while :; do watch_dir; yarn lint; done
  #
  # $ repeatwd 'clear; pyenv activate myenv; python -m pytest -rP some_test.py -k "somekeyword"'
  # >> while :; do watch_dir; clear; pyenv activate myenv; python -m pytest -rP some_test.py -k "somekeyword"; done

  command_with_args_to_repeatedly_do="${@}"
  # echo "command_with_args_to_repeatedly_do: \"${command_with_args_to_repeatedly_do}\""

  screen_name="repeat_command_${RANDOM}"

  # Start screen in "detached" mode with a session name.
  screen -S "${screen_name}" -t "master" -d -m

  # Wait for screen to be ready before opening new sessions.
  sleep 1

  # Create a new tab and send a command to it.
  # TODO: Display command being run and horizontal rule between each execution as in _repeat().
  screen -S "${screen_name}" -X "screen" -t "my_screen_1"
  screen -S "${screen_name}" -p "my_screen_1" -X stuff "while :; do watch_dir; ${command_with_args_to_repeatedly_do}; done"$'\n'

  # Exit the first screen.
  screen -S "${screen_name}" -p "0" -X stuff $'exit\n'

  # Attach.
  screen -r "${screen_name}"
}
alias repeatwd="_repeat_wd"
alias wdrepeat="_repeat_wd"

alias md="mkdir"

alias dsstore="find . -name \".DS_Store\" -type f -print -delete"

_zip_clean() {
    archive_path="${1}"

    before="$(unzip -l "${archive_path}")"

    zip --delete "${archive_path}" "__MACOSX/*" "*/.DS_Store"

    after="$(unzip -l "${archive_path}")"

    diff_strings_like_files "${before}" "${after}"
}
alias zip_clean="_zip_clean"

_python_check_syntax() {
    filename="${1}"
    python3 -m py_compile "${filename}"
}
alias python_check_syntax="_python_check_syntax"

alias bu="brew update; brew upgrade"

curl_example() {
    set -x
    curl -i "http://www.example.com/" |
        head --lines=20
    set +x
}
alias ce="curl_example"

curl_neverssl() {
    set -x
    curl -i "http://www.neverssl.com/" |
        head --lines=20
    set +x
}
alias cn="curl_neverssl"

alias alive="while :; do ping google.com; date; sleep 1; echo; done"
alias al="alive"

conditional_a() {
    # Handle a -> `alive'.
    if [[ $# -eq 0 ]]; then
        alive

    # Handle a -> `git add'.
    else
        git add $@
    fi
}

alias a="conditional_a"

# Attempt to install pipdeptree as pip-sync or similar may have uninstalled it.
alias pipdeptree="pip install pipdeptree; pipdeptree"

_conditional_hs() {
    if [[ ${#} -eq 0 ]]; then
        cd ~/.hammerspoon/ && l
    else
        "$(which hs)" $@
    fi
}
alias .hs="_conditional_hs"
alias hs="_conditional_hs"

remove_empty_directories() {
    # Remove pycache directories that can cause rmdir command to fail.
    find . -type d -name "__pycache__" |
        xargs -L 1 rm -rf

    # Attempt to remove empty directories. Using rmdir which errors when the
    # directory is not empty as we only want to remove empty directories.
    find . \
        -type d \
        -empty \
        \(  \
            -path "*/.*" -prune -o \
            -path "*/.git" -prune -o \
            -print \
        \) |
        xargs -L 1 -I {} sh -c 'echo "Removing directory: {}"; rmdir "{}"'
}

alias rm_empty_dir="remove_empty_directories"
alias rmdir_empty="remove_empty_directories"

_calendar() {
    # Allow passing arbitrary dates to calendar.
    #
    # before:
    #   $ calendar jul2025
    #   usage: calendar [-A days] [-a] [-B days] [-D sun|moon] [-d]
    #                   [-F friday] [-f calendarfile] [-l longitude]
    #                   [-t dd[.mm[.year]]] [-U utcoffset] [-W days]
    #
    # after:
    #   $ cal jul2025
    #        July 2025
    #   Su Mo Tu We Th Fr Sa
    #          1  2  3  4  5
    #    6  7  8  9 10 11 12
    #   13 14 15 16 17 18 19
    #   20 21 22 23 24 25 26
    #   27 28 29 30 31

    _require_jq

    user_date="${@}"
    # echo "user date: ${user_date}"

    if [[ -z "${user_date}" ]]; then
        user_date="$(date +"%Y-%m-%d")"
        # echo "user date: ${user_date}"
    fi

    # echo "user date: ${user_date}"
    # echo

    code="$(cat <<\EOF
$user_input_arg_1 = 'first day of ' . $argv['1'];

$timezone = 'America/Los_Angeles';
$timezone = 'America/New_York';
date_default_timezone_set($timezone);

$datetime = new DateTime($user_input_arg_1);
echo json_encode(array(
    'month' => $datetime->format('m'),
    'year' => $datetime->format('Y'),
));
EOF
)"
    result="$(php -r "${code}" "${user_date}")"
    # echo "result: ${result}"

    month="$(echo "${result}" | \jq --raw-output ".month")"
    # echo "month: ${month}"

    year="$(echo "${result}" | \jq --raw-output ".year")"
    # echo "year: ${year}"

    /usr/bin/cal -m "${month}" "${year}"
}
alias cal="_calendar"

_open_files() {
    # TODO(zborboa): Only open if files are found.
    results="${1}"
    result_count=$(echo "${results}" | count_lines)
    if [[ $result_count -gt 10 ]]; then
        if [[ -n "$ZSH_VERSION" ]]; then
            echo -n "Are you sure you want to open ${result_count} files? [y/n] "
            read -k 1 REPLY; echo
            if ! [[ $REPLY =~ ^[Yy]$ ]]; then
                return
            fi
        elif [[ -n "$BASH_VERSION" ]]; then
            read -p "Are you sure you want to open ${result_count} files? [y/n] " -n 1 -r; echo
            if ! [[ $REPLY =~ ^[Yy]$ ]]; then
                return
            fi
        else
            echo "TODO: Handle other case."
            return
        fi
    fi

    # Convert result lines to array.
    files_array=()
    while IFS= read -r line; do
        files_array+=("${line}")
    done <<< "${results}"

    # Open results as a list of file path arguments.
    # Pass an expanded array containing the list of file paths to the edit
    # command using the at sign:
    #   $ edit "${files_array[@]}"
    # instead of just using:
    #   $ edit "${files_array}"
    edit "${files_array[@]}"
}
