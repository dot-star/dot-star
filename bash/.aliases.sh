# Shortcuts

colordiff="$(which colordiff)"
if [[ -z "${colordiff}" ]]; then
    COLORDIFF_INSTALLED=false
else
    COLORDIFF_INSTALLED=true
fi

diff_so_fancy="$(which diff-so-fancy)"
if [[ -z "${diff_so_fancy}" ]]; then
    DIFF_SO_FANCY_INSTALLED=false
else
    DIFF_SO_FANCY_INSTALLED=true
fi

is_interactive_shell() {
    [[ "$-" =~ "i" ]]
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

alias 600="chmod 600"
alias 644="chmod 644"
alias 700="chmod 700"
alias 750="chmod 750"
alias 755="chmod 755"
alias 777="chmod 777"

_ls(){
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
            directory="$(dirname $directory)"
        fi
        builtin cd "${directory}"
    fi
}
alias "cd"="better_cd"

edit() {
  editor="_vim"
  "${editor}" "${@}"
}
alias e="edit"

_grep() {
    grep \
        --binary-files="without-match" \
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
    grep --recursive "${keyword}" . "${@:2}"
  # Search by extension + keyword (e.g. `s ext keyword').
  elif [[ "${param_count}" -eq 2 ]]; then
    extension="${1}"
    keyword="${2}"
    grep --recursive --include="*.${extension}" "${keyword}" . "${@:3}"
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

    result_count=$(echo "${results}" | gwc --lines)
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
  if [[ "${param_count}" -eq 0 ]]; then
    # Show version control status when no parameters are passed.
    rc_status
  # Search by keyword (e.g. `s keyword').
  elif [[ "${param_count}" -eq 1 ]]; then
    keyword="${1}"
    grep --ignore-case --recursive "${keyword}" . "${@:2}"
  # Search by extension + keyword (e.g. `s ext keyword').
  elif [[ "${param_count}" -eq 2 ]]; then
    extension="${1}"
    keyword="${2}"
    grep --ignore-case --recursive --include="*.${extension}" "${keyword}" . "${@:3}"
  fi
}
alias si="case_insensitive_search"
alias s="case_insensitive_search"

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

    result_count=$(echo "${results}" | gwc --lines)
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
alias se="case_insensitive_search_edit"

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
alias tree="tree -a -F -I '__pycache__' -I '.git'"
alias t="tree"

_top() {
    top -o cpu
    if [[ $? -ne 0 ]]; then
        top
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
alias q="quit"

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
    stdin="${1}"
    if [[ -z "${1}" ]]; then
        read stdin
    fi
    script="
import re
import sys

input = sys.stdin.read().rstrip()
value = re.sub('[^\w\s\.-]', '', input).strip().lower()
print re.sub('[-\s]+', '-', value)
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

chmod() {
    if [ "$#" -eq 1 ]; then
        file_mode_bits=$(gstat --format "%a" "${1}")
        echo -e "${file_mode_bits}\t${1}"
    else
        command chmod "${@}"
    fi
}

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
        result_count=$(echo "${results}" | gwc --lines)
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
    print 'builtin type {0}'.format(pipes.quote(match.group(1)))
EOF
)
            cmd=$(echo "${response}" | python -c "${script}")
            if [ ! -z "${cmd}" ]; then
                ${cmd}
            else
                echo "${response}"
            fi
        else
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
        fi
    else
        file_bin="$(which file)"
        target_file="${@}"
        "${file_bin}" "${target_file}"
    fi
}
alias file="get_file_info"
alias ty="get_file_info"
# Temporarily disable alias "type" as it makes bash-completion slow.
# alias type="get_file_info"

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

watch_file() {
    # Watch a file for changes and run a command.
    # Usage:
    #   $ watch_file file_to_watch.log "bash file_changed.sh"
    #   >>> watchman-make -p "file_to_watch.log" --run "bash file_changed.sh"
    #
    #   $ watch_file script.sh
    #   >>> watchman-make -p "**" --run "bash script.sh"
    #
    #   $ watch_file script.go
    #   >>> watchman-make -p "**" --run "go run script.go"
    #
    #   $ watch_file script.js
    #   >>> watchman-make -p "**" --run "node script.js"
    #
    #   $ watch_file script.php
    #   >>> watchman-make -p "**" --run "php script.php"
    #
    #   $ watch_file script.py
    #   >>> watchman-make -p "**" --run "python script.py"

    # Watch current directory and run command when only one parameter is specified.
    if [[ $# -eq 1 ]]; then
        pattern_to_watch="**"
        file_name="${1}"

        # Add prefix to command based on file name extension.
        python_script=$(cat <<'EOF'
import os
import pipes
import sys

filename = sys.argv[1]
_, file_extension = os.path.splitext(filename)
filepath = os.path.abspath(filename)
cmd = ''
if file_extension == '.sh':
    cmd = 'bash {0}'.format(pipes.quote(filename))
elif file_extension == '.go':
    cmd = 'go run {0}'.format(pipes.quote(filename))
elif file_extension == '.js':
    cmd = 'node {0}'.format(pipes.quote(filename))
elif file_extension == '.php':
    cmd = 'php {0}'.format(pipes.quote(filename))
elif file_extension == '.py':
    cmd = 'python {0}'.format(pipes.quote(filename))
print(cmd)
EOF
)
        cmd_to_run=$(python -c "${python_script}" "${file_name}")
    elif [[ $# -eq 2 ]]; then
        pattern_to_watch="${1}"
        cmd_to_run="${2}"
    else
        echo "Error: 1 or 2 parameters required"
        return
    fi

    # Add line separator between each command.
    cols="$(tput cols)"
    cmd_to_run="printf -- '-=%.0s' {1..${cols}}; echo; ${cmd_to_run}"

    echo "pattern_to_watch: ${pattern_to_watch}"
    echo "cmd_to_run: ${cmd_to_run}"

    # Use watchman-make when available.
    which watchman-make &> /dev/null
    if [[ $? -eq 0 ]]; then
        watchman-make --pattern "${pattern_to_watch}" --run "${cmd_to_run}"
        return
    else
        echo -e '\x1b[0;93mWARNING\x1b[0m: watchman-make required'
    fi
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
        --TerminalInteractiveShell.confirm_exit=False \
        --TerminalInteractiveShell.editing_mode=vi \
        --TerminalInteractiveShell.editor=vi
}
alias ipy="ipython_wrapper"
alias py="python"

case_insensitive_search_edit() {
  if [[ -z "${1}" ]]; then
    return
  fi
  results=$(grep --dereference-recursive --files-with-matches --ignore-case "${1}" . "${@:2}")
  result_count=$(echo "${results}" | gwc --lines)
  if [[ $result_count -gt 10 ]]; then
    read -p "Are you sure you want to open ${result_count} files? [y/n] " -n 1 -r; echo
    if ! [[ $REPLY =~ ^[Yy]$ ]]; then
      return
    fi
  fi
  files=$(echo "${results}" | tr '\n' ' ')
  edit ${files}
}
alias se="case_insensitive_search_edit"

edit_extension_files() {
    files_to_edit=""

    # Open background.js.
    background_results=$(find . -iname "background.js" | head -1)
    if [[ ! -z "${background_results}" ]]; then
        echo "background_results: ${background_results}"
        files_to_edit+=" ${background_results}"
    fi

    # Open content_script.js.
    content_script_results=$(find . -iname "*content_script*.js")
    if [[ ! -z "${content_script_results}" ]]; then
        echo "content_script_results: ${content_script_results}"
        files_to_edit+=" ${content_script_results}"
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

    echo "${files_to_edit}"
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
        read -e -i "${file_name}" "new_file_name"
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
            (
                $DIFF_SO_FANCY_INSTALLED &&
                diff --unified <(echo "${file_name}") <(echo "${new_file_name}") | "diff-so-fancy" | tail -n +5
            ) || (
                $COLORDIFF_INSTALLED &&
                diff --unified <(echo "${file_name}") <(echo "${new_file_name}") | "colordiff" | tail -n +4
            ) || (
                diff --unified <(echo "${file_name}") <(echo "${new_file_name}") | tail -n +4
            )

    # Call original mv command when any other number of parameters have been specified.
    else
        command mv "${@}"
    fi
}

alias rp="realpath"
