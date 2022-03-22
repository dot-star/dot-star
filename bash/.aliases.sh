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

count_lines() {
  if which "gwc" &> /dev/null; then
    gwc --lines
  else
    wc --lines
  fi
}

display_confirm_prompt() {
    text="${1}"
    if [ -n "${BASH_VERSION}" ]; then
        read -p "${text} " -n 1 -r
        echo "${REPLY}"
    elif [ -n "${ZSH_VERSION}" ]; then
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
    if [ $? -ne 0 ]; then
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
            --ignore=".sass-cache" \
            --ignore=".svn" \
            --ignore=".swp" \
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
    if [ -t 0 ]; then
        # Run `ls' when shell is interactive (e.g. "$ l").
        _ls "${@}"
    else
        # Run `less' when shell is non-interactive (e.g. "$ my_command | l").
        less
    fi

}
alias l="conditional_l"

bak() {
    source="${1}"
    timestamp=$(date +"%Y-%m-%d_%H%M%S")

    local cp_to_use
    if which "gcp" &> /dev/null; then
      cp_to_use="gcp"
    else
      cp_to_use="cp"
    fi

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
        echo "Error: source is not a file or directory."
        return 1
    fi
}
alias b="bak"

conditional_c() {
    # clear, cd $dir, $cat $filename [$filename ...], or clipboard
    if [ -t 0 ]; then
        # Keyboard input (interactive).
        param_count="${#}"
        # Call `clear' when no parameters are passed (e.g. c).
        if [[ "${param_count}" -eq 0 ]]; then
            clear
        # Call `cd $dir' when a single parameter is passed and it is a directory (e.g. c ~/dir).
        elif [ "${param_count}" -eq 1 ] && [ -d "${1}" ]; then
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

list_dirstack() {
    i=0
    for dir in $(\dirs -p | awk '!x[$0]++' | head -n 10); do
        echo " ${i}  ${dir}"
        ((i++))
    done
}
alias dirs="list_dirstack"

pushd() {
    if [ "${#}" -eq 0 ]; then
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
        builtin cd "${directory}"
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
    if [ -t 0 ]; then
        # Run cd alias when not piped.
        better_cd "${@}"

    # Pipe input (non-interactive).
    else
        # Run colordiff when alias cd is piped.
        colordiff
    fi
}
alias "cd"="conditional_cd"

_edit() {
    editor="_vim"

    # Display option for selecting which file to edit when no file has been
    # specified. Automatically select file when there's only one file.
    if [[ $# -eq 0 ]] && is_git; then
        root_dir="$(git rev-parse --show-toplevel)"

        # Look for staged files (added ^A or modified ^M).
        result=$(
            git status --porcelain |
                \grep --extended-regexp "^(A |M )" |
                awk '{print $2}'
        )

        # Fallback to looking for modified files.
        if [[ -z "${result}" ]]; then
            result=$(
                git status --porcelain |
                    \grep "^ M " |
                    awk '{print $2}'
            )
        fi

        # Fallback to looking for files with unmerged changes.
        if [[ -z "${result}" ]]; then
            result=$(
                git status --porcelain |
                    \grep "^UU " |
                    awk '{print $2}'
            )
        fi

        # Lastly, look for untracked files.
        if [[ -z "${result}" ]]; then
            result=$(
                git status --porcelain |
                    \grep "^?? " |
                    awk '{print $2}' |
                    fzf --select-1 --exit-0
            )
        fi

        result="$(echo "${result}" | fzf --select-1 --exit-0)"
        return_code="${?}"

        # Stop edit when canceled.
        # "130 Interrupted with CTRL-C or ESC"
        if [[ "${return_code}" -eq 130 ]]; then
            return
        fi

        # Show notice when no file was selected.
        if [[ -z "${result}" ]]; then
            echo "(no file selected)"
        fi

        # Prepend root directory to result when not empty. Prepend after instead
        # of with the fzf selector so that only paths relative from the git root
        # directory are shown in the fzf selector and not absolute paths.
        if [[ ! -z "${result}" ]]; then
            result="${root_dir}/${result}"
        fi

        args="${result}"
    else
        args="${@}"
    fi

    "${editor}" ${args}
}
alias e="_edit"
alias edit="_edit"

_grep() {
    if [ -t 0 ]; then
        # Run grep with line numbers when shell is interactive (e.g.
        # "$ grep ...").
        grep \
            --binary-files="without-match" \
            --color \
            --exclude-dir=".git" \
            --exclude-dir=".hg" \
            --exclude-dir=".svn" \
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
            --exclude-dir=".svn" \
            "$@"
    fi
}
alias grep="_grep"

alias h="history"
alias j="jobs"
alias o="_open"
alias oo="_open ."

fin() {
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        osascript -e 'display notification "" with title "Done"'
    else
        terminal-notifier -message "" -title "Done" 2> /dev/null
        if [ $? -eq 127 ]; then
            notify-send --expire-time=1000 "Done $(date)"
        fi
    fi
}

case_sensitive_search() {
  param_count="${#}"
  if [[ "${param_count}" -eq 0 ]]; then
    return
  # Search by keyword (e.g. `s keyword').
  elif [[ "${param_count}" -eq 1 ]]; then
    keyword="${1}"
    grep --exclude-dir="node_modules" --recursive "${keyword}" . "${@:2}"
  # Search by extension + keyword (e.g. `s ext keyword').
  elif [[ "${param_count}" -eq 2 ]]; then
    extension="${1}"
    keyword="${2}"
    grep --exclude-dir="node_modules" --recursive --include="*.${extension}" "${keyword}" . "${@:3}"
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
      results=$(grep --dereference-recursive --exclude-dir="node_modules" --files-with-matches "${keyword}" . "${@:2}")
    # Search by extension + keyword and edit (e.g. `sse ext keyword').
    elif [[ "${param_count}" -eq 2 ]]; then
      extension="${1}"
      keyword="${2}"
      results=$(grep --dereference-recursive --exclude-dir="node_modules" --files-with-matches --include="*.${extension}" "${keyword}" . "${@:3}")
    fi

    result_count=$(echo "${results}" | count_lines)
    if [[ $result_count -gt 10 ]]; then
      read -p "Are you sure you want to open ${result_count} files? [y/n] " -n 1 -r; echo
      if ! [[ $REPLY =~ ^[Yy]$ ]]; then
        return
      fi
    fi

    files=$(echo "${results}" | tr '\n' ' ')
    edit ${files}
  fi
}
alias sse="case_sensitive_search_edit"

case_insensitive_search() {
  param_count="${#}"

  # Search by keyword (e.g. `s keyword').
  if [[ "${param_count}" -eq 1 ]]; then
    keyword="${1}"
    grep --exclude="*~" --exclude-dir="node_modules" --ignore-case --recursive "${keyword}" . "${@:2}"

  # Search by extension + keyword (e.g. `s ext keyword').
  elif [[ "${param_count}" -eq 2 ]]; then
    extension="${1}"
    keyword="${2}"
    grep --exclude="*~" --exclude-dir="node_modules" --ignore-case --recursive --include="*.${extension}" "${keyword}" . "${@:3}"

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
      results=$(grep --dereference-recursive --exclude-dir="node_modules" --files-with-matches --ignore-case "${keyword}" . "${@:2}")
    # Search by extension + keyword and edit (e.g. `se ext keyword').
    elif [[ "${param_count}" -eq 2 ]]; then
      extension="${1}"
      keyword="${2}"
      results=$(grep --dereference-recursive --exclude-dir="node_modules" --files-with-matches --ignore-case --include="*.${extension}" "${keyword}" . "${@:3}")
    fi

    result_count=$(echo "${results}" | count_lines)
    if [[ $result_count -gt 10 ]]; then
      read -p "Are you sure you want to open ${result_count} files? [y/n] " -n 1 -r; echo
      if ! [[ $REPLY =~ ^[Yy]$ ]]; then
        return
      fi
    fi

    # TODO(zborboa): Only open if files are found.

    files=$(echo "${results}" | tr '\n' ' ')
    edit ${files}
  fi
}

conditional_se() {
    if [ "${#}" -eq 0 ]; then
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
_tree() {
  tree \
    -a \
    -F \
    -I ".git" \
    -I "__pycache__" \
    -I "node_modules" \
    $@
}
alias tree="_tree"
alias t="_tree"

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
alias x="quit"

_conditional_q() {
    if [ "${#}" -eq 0 ]; then
        quit
    else
        quilt "${@}"
    fi
}
alias q="_conditional_q"

_open() {
    args=("${@}")

    # Open current directory when no path is specified.
    if [ "$#" -eq 0 ]; then
        args[0]="."
    fi

    open "${args[@]}" &> /dev/null
    if [ ! $? -eq 0 ]; then
        nautilus "${args[@]}"
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

clipboard() {
    # Remove trailing newline from stdin and copy it to the clipboard.
    if which "xsel" &> /dev/null; then
        perl -p -e 'chomp if eof' | xsel --clipboard
    elif which "pbcopy" &> /dev/null; then
        perl -p -e 'chomp if eof' | pbcopy
    fi
}
alias clip="clipboard"
alias copy="clipboard"

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
    echo "${stdin}" | python -c "${script}"
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

difference() {
    if [ -t 1 ] && $COLORDIFF_INSTALLED; then
        command='diff --recursive --unified "'"${1}"'" "'"${2}"'" | colordiff | less -R'
    elif [ -t 1 ]; then
        command='diff --recursive --unified "'"${1}"'" "'"${2}"'" | less -R'
    else
        command='diff --recursive --unified "'"${1}"'" "'"${2}"'"'
    fi
    echo "${command}"
    eval $command
}
alias d="difference"

_chmod() {
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
alias chmod="_chmod"

conditional_f() {
    if [ -t 1 ]; then
        interactive=true
    else
        interactive=false
    fi

    # Run fg when no parameters are passed, otherwise find files with path containing the specified keyword.
    if [ $# == 0 ]; then
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
            find . -iname "*${keyword}*" | \grep --color --ignore-case "${keyword}"
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
        results=$(find . -iname "*${keyword}*" -type "f")
        result_count=$(echo "${results}" | count_lines)
        if [[ $result_count -gt 10 ]]; then
            read -p "Are you sure you want to open ${result_count} files? [y/n] " -n 1 -r; echo
            if ! [[ $REPLY =~ ^[Yy]$ ]]; then
                return
            fi
        fi
        files=$(echo "${results}" | tr '\n' ' ')
        edit ${files}
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
import pipes
import re
import sys

response = sys.stdin.read().rstrip()
match = re.match(r".* is aliased to \`([\w]+)'", response)
if match is not None:
    print('builtin type {0}'.format(pipes.quote(match.group(1))))
EOF
)
            cmd=$(echo "${response}" | python -c "${script}")
            if [ ! -z "${cmd}" ]; then
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
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
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
    pattern_to_watch="${1}"
    cmd_to_run="${2}"

    i=0
    while :; do
        set -x
        watchman-wait --max-events="1" --pattern "${pattern_to_watch}" -- .
        set +x
        watchman_exit_code="${?}"

        # "0 is returned after successfully waiting for event(s)".
        if [ "${watchman_exit_code}" -eq 0 ]; then
            cols="$(tput cols)"
            echo "$(bash -c "printf -- '=%.0s' {1..${cols}}")"
            clear

            bash -c "${cmd_to_run}"
            command_exit_code="${?}"

            # Calculate width of line separator between each command execution
            # and right before printing the separator to account for resizing.
            cols="$(tput cols)"

            if [ $((i%4)) -eq 0 ]; then
                sep="$(bash -c "printf -- '-%.0s' {1..${cols}}")"
            elif [ $((i%4)) -eq 1 ]; then
                sep="$(bash -c "printf -- '\%.0s' {1..${cols}}")"
            elif [ $((i%4)) -eq 2 ]; then
                sep="$(bash -c "printf -- '|%.0s' {1..${cols}}")"
            elif [ $((i%4)) -eq 3 ]; then
                sep="$(bash -c "printf -- '/%.0s' {1..${cols}}")"
            fi

            if [ "${command_exit_code}" -ne 0 ]; then
                error "${sep}"
                echo -e "\\033[4;31mError:\\033[0m exit code ${command_exit_code}"
                echo -e "\\033[34mCommand:\\033[0m \`${cmd_to_run}'"
            else
                success "${sep}"
            fi
        else
            break
        fi

        sleep 1

        (( i += 1 ))
    done
}

_get_command_for_file_type() {
    # Add prefix to command based on file name extension.
    python_script=$(cat <<'EOF'
import os
import pipes
import sys

command_or_file_name = sys.argv[1]
if os.path.isfile(command_or_file_name):
    file_name = command_or_file_name
    _, file_extension = os.path.splitext(file_name)
    filepath = os.path.abspath(file_name)
    cmd = ''
    if file_extension == '.sh':
        cmd = 'bash {0}'.format(pipes.quote(file_name))
    elif file_extension == '.go':
        cmd = 'go run {0}'.format(pipes.quote(file_name))
    elif file_extension == '.js':
        cmd = 'node {0}'.format(pipes.quote(file_name))
    elif file_extension == '.php':
        cmd = 'php {0}'.format(pipes.quote(file_name))
    elif file_extension == '.py':
        cmd = 'python3 {0}'.format(pipes.quote(file_name))
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
    _require_watchman

    # Watch the current directory and run the specified command (parameter 1)
    # when one parameter is specified.
    if [[ $# -eq 1 ]]; then
        # Use a glob pattern (not a regular expression) that excludes period-prefixed files which would otherwise cause
        # endless triggering. For example, using watchman-make with --pattern "**" and --run "phpunit [...]" causes a
        # cache file (".phpunit.result.cache") to be continually updated and a another execution.
        pattern_to_watch="**/[!\.]*.*"
        command_or_file_name="${1}"
        cmd_to_run="$(_get_command_for_file_type "${command_or_file_name}")"
    else
        echo "Error: 1 parameter required"
        return
    fi

    _run_watchman "${pattern_to_watch}" "${cmd_to_run}"
}
alias wd="watch_dir"

watch_file() {
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

    # Watch the specified file (parameter 1) for changes and run its related
    # command when only one parameter is specified.
    if [[ $# -eq 1 ]]; then
        pattern_to_watch="**"
        command_or_file_name="${1}"
        cmd_to_run="$(_get_command_for_file_type "${command_or_file_name}")"

    # Watch the specified pattern (parameter 1) for changes and run the
    # specified command (parameter 2) when two parameters are specified.
    elif [[ $# -eq 2 ]]; then
        pattern_to_watch="${1}"
        cmd_to_run="${2}"

    else
        echo "Error: 1 or 2 parameters required"
        return
    fi

    _run_watchman "${pattern_to_watch}" "${cmd_to_run}"
}
alias wf="watch_file"

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

ipython_wrapper() {
    ipython \
        --TerminalInteractiveShell.confirm_exit="False" \
        --TerminalInteractiveShell.editing_mode="vi" \
        --TerminalInteractiveShell.editor="vi"
}
alias ipy="ipython_wrapper"
alias py="python"

edit_extension_files() {
    files_to_edit=""

    # Open background.js.
    background_results=$(find . -iname "background.js" | head -1)
    if [[ ! -z "${background_results}" ]]; then
        echo "background_results: ${background_results}"
        files_to_edit+=" ${background_results}"
    fi

    # Open JavaScript files.
    javascript_results=$(find . -iname "*.js" ! -path "*/node_modules/*")
    if [[ ! -z "${javascript_results}" ]]; then
        echo -e "javascript_results:\n${javascript_results}"
        files_to_edit+=" ${javascript_results}"
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
        files_to_edit+=" ${style_results}"
    fi

    # Open style.scss or style.css in a child directory.
    manifest_results=$(find . -iname "manifest.json" | head -1)
    if [[ ! -z "${manifest_results}" ]]; then
        echo "manifest_results: ${manifest_results}"
        files_to_edit+=" ${manifest_results}"
    fi

    edit ${files_to_edit}

    if $scss_found; then
        echo "running sasswatch"
        dir="$(dirname "${style_results}")/"
        sasswatch "${dir}style.scss:${dir}style.css"
    fi
}
alias ext="edit_extension_files"

conditional_d() {
    # Diff when 2 parameters are specified and they both are either files or directories.
    if [ "${#}" -eq 2 ] && [ -e "${1}" ] && [ -e "${2}" ]; then
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
    # read -p "Are you sure you want to open ${result_count} files? [y/n] " -n 1 -r; echo
    # if ! [[ $REPLY =~ ^[Yy]$ ]]; then

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

cp() {
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
            (
                $DIFF_SO_FANCY_INSTALLED &&
                diff --unified <(echo "${file_name}") <(echo -e "${file_name}\n${new_file_name}") | "diff-so-fancy" | tail -n +5
            ) || (
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

mv() {
    file_name="${1}"

    # Display information when parameter is not a file.
    if [[ "${#}" -eq 1 ]] && [[ ! -f "${file_name}" ]]; then
        command file "${@}"

    # Call modified mv command to edit file name in place when only 1 parameter has been specified.
    elif [[ "${#}" -eq 1 ]] && [[ -f "${file_name}" ]]; then
        read -e -i "${file_name}" "new_file_name"
        command mv "${file_name}" "${new_file_name}" &&
            diff_strings_like_files "${file_name}" "${new_file_name}"

    # Call original mv command when any other number of parameters have been specified.
    else
        command mv "${@}"
    fi
}

alias rp="realpath"

# Wrap jq command to allow debugging a jq filter interactively.
# To use, run `jq $filename'. Press return when the desired filter has been
# entered. The entered filter will be displayed and put in the clipboard for
# immediate use.
_jq() {
    export JQ_COLORS="1;37:0;33:0;33:0;31:0;32:1;39:1;39"

    if [ $# -eq 1 ] && [ -f "${1}" ]; then
        file_path="${1}"

        # Open an interactive view for entering a jq filter and viewing the
        # result in the fzf preview window.
        jq_filter=$(echo "" |
            fzf \
                --info=hidden \
                --preview "cat \"${file_path}\" | jq --color-output {q}" \
                --preview-window=up:100 \
                --print-query
        )
        if [[ -z "${jq_filter}" ]]; then
            echo "(no filter submitted)"
            return
        fi

        # Display a preview of the file using the selected jq filter.
        echo "$ jq -C \"${jq_filter}\" \"${file_path}\" | head"
        "$(which jq)" -C "${jq_filter}" "${file_path}" | head

        # Put the selected jq filter in the clipboard.
        echo "${jq_filter}" | clip

        # Display the selected jq filter.
        echo ""
        echo "jq filter (also in clipboard):"
        echo "${jq_filter}"
    else
        "$(which jq)" "${@}"
    fi
}
alias jq="_jq"

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
        man_file_path="$(\man --path "${1}")"
        exit_code="${?}"
        if [[ "${exit_code}" -ne 0 ]]; then
            return
        fi

        mkdir -p "${HOME}/man_html/"

        man_file_name="$(basename "${man_file_path}")"
        echo "file name: ${man_file_name}"
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

if [[ ! -z "${BYOBU_WINDOW_NAME}" ]]; then
    alias detach="/usr/lib/byobu/include/tmux-detach-all-but-current-client"
fi

alias k="kill"
alias ka="killall"

detach() {
   /usr/lib/byobu/include/tmux-detach-all-but-current-client
}

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
        if [ -d ".git" ]; then
            l
            break
        elif [ "${PWD}" == "/" ]; then
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
    if [ "${#}" -eq 0 ]; then
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
