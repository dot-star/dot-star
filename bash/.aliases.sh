# Shortcuts

alias 600="chmod 600"
alias 644="chmod 644"
alias 700="chmod 700"
alias 750="chmod 750"
alias 755="chmod 755"
alias 777="chmod 777"

_ls(){
    clear
    if ls --color > /dev/null 2>&1; then
        # GNU `ls`. Available with `brew install coreutils'.
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

bak() {
    filename="${1}"
    extension=$(basename "${filename##*.}")
    base_filename="${filename%.*}"
    timestamp=$(date +"%Y-%m-%d_%H%I%S")
    new_filename="${base_filename}_${timestamp}.${extension}"
    if [[ ! -f "${new_filename}" ]]; then
        cp -v "${filename}" "${new_filename}"
    else
        echo "destination \"${new_filename}\" exists"
        file "${new_filename}"
    fi
}

c() {
    # clear, cd $dir, or $cat $filename [$filename ...]
    param_count="${#}"
    # Call `clear' when no parameters are passed.
    if [[ "${param_count}" -eq 0 ]]; then
        clear
    # Call `cd $dir' when a single parameter is passed and it is a directory.
    elif [ "${param_count}" -eq 1 ] && [ -d "${1}" ]; then
        cd "${1}"
    # Call `cat $filename [$filename ...]' when one or more parameters are passed.
    else
        cat "${@}"
    fi
}

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

edit() {
  editor="${EDITOR}"
  if is_ssh; then
    editor="vim"
  fi
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
    terminal-notifier -message "" -title "Done" 2> /dev/null
    if [ $? -eq 127 ]; then
        notify-send --expire-time=1000 "Done $(date)"
    fi
}

case_sensitive_search() {
  if [[ -z "${1}" ]]; then
    return
  fi
  set -x
  grep -R "${1}" . "${@:2}"
  set +x
}
alias ss="case_sensitive_search"

case_insensitive_search() {
  if [[ -z "${1}" ]]; then
    return
  fi
  set -x
  grep -Ri "${1}" . "${@:2}"
  set +x
}
alias si="case_insensitive_search"
alias s="case_insensitive_search"

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
alias t="tree -a -I '__pycache__'"

_top() {
    if top -o cpu &> /dev/null; then
        top -o cpu
    else
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
    if [ "$TERM_PROGRAM" == "Apple_Terminal" ]; then
        quit_terminal_when_no_terminals_remain() {
            osascript -e 'tell application "Terminal" to if running and (count every tab of every window whose tty is not "'"$(tty)"'") is 0 then quit'
        }
        trap quit_terminal_when_no_terminals_remain EXIT
    fi
    exit
}
alias x="quit"
alias q="quit"

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
alias .*="dotstar"
alias extra="vim ${HOME}/.dot-star/bash/extra.sh"
alias hosts="sudo vim /etc/hosts"
alias known_hosts="vim ${HOME}/.ssh/known_hosts"
alias sshconfig="vim ${HOME}/.ssh/config"

alias aliases="vim ${HOME}/.dot-star/bash/.aliases.sh"
alias bashprofile="vim ${HOME}/.bash_profile"
alias bashrc="vim ${HOME}/.bashrc"
alias inputrc="vim ${HOME}/.inputrc"
alias +x="chmod +x"

large_files() {
    du -hs * | sort -h
}
alias large="large_files"

slugify() {
    cat <<EOF | python -
import re
value = re.sub('[^\w\s\.-]', '', '${1}').strip().lower()
print re.sub('[-\s]+', '-', value)
EOF
}
alias slug="slugify"

slugify_mv() {
    for filename in "${@}"; do
        new_filename=$(slugify "${filename}")
        if [[ "${new_filename}" != "${filename}" ]]; then
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
    read password
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
    command='diff -u "'"${1}"'" "'"${2}"'" | colordiff | less -R'
    echo "${command}"
    eval $command
}
alias d="difference"

chmod() {
    if [ "$#" -eq 1 ]; then
        file_mode_bits=$(stat --format "%a" "${1}")
        echo -e "${file_mode_bits}\t${1}"
    else
        command chmod "${@}"
    fi
}

f() {
    # Run fg when no parameters are passed, otherwise find files with path containing the specified keyword.
    if [ $# == 0 ]; then
        fg
    else
        keyword="${1}"
        if [[ -z "${keyword}" ]] ; then
            echo "Search is empty"
        else
            echo "Searching paths and filenames containing \"*${keyword}*\":" | \grep --color --ignore-case "${keyword}"
            find . -iname "*${keyword}*" | \grep --color --ignore-case "${keyword}"
        fi
    fi
}


un() {
    command=$(cat <<EOF | python -
import os

filename = '${1}'
command = ''
if filename.endswith('.zip'):
    command = 'unzip'
elif filename.endswith(('.tar.bz2', '.tar.gz',)):
    command = 'tar xvf'
elif filename.endswith('.gz'):
    command = 'gunzip'
if command:
    print command
EOF
)
    if [ ! -z "${command}" ]; then
        echo "command: ${command}"
        ${command} ${1}
    fi
}

type() {
    if [ ! -z "${1}" ]; then
        response=$(command type "${1}")
        echo "${response}"
        command=$(cat <<EOF | python -
import re

match = re.match(r".* is aliased to \`([\w]+)'", """${response}""")
if match is not None:
    print 'type {0}'.format(match.group(1))
EOF
)
        if [ ! -z "${command}" ]; then
            ${command}
        fi
    fi
}
alias ty="type"

is_ssh() {
    if [ -z "${SSH_CLIENT}" ]; then
        return 1
    fi
    return 0
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

file() {
    if [[ "${#}" -eq 1 ]]; then
        file_size=$(stat --printf="%s" "${1}")
        echo "$($(which file) "${@}") (${file_size} bytes)"
    else
        echo "$($(which file) "${@}")"
    fi
}

watch_file() {
    # Watch a file for changes and run a command.
    # Usage: watch_file file_to_watch.log "bash file_changed.sh"
    filename="${1}"
    cmd="${2}"
    if [[ "${OSTYPE}" == "linux-gnu" ]]; then # Linux
        while inotifywait --event modify --quiet "${filename}"; do
            if [ ! -z "${cmd}" ]; then
                $cmd
            fi
        done
    elif [[ "${OSTYPE}" == "darwin"* ]]; then # OS X
        echo -e '\x1b[0;93mWARNING\x1b[0m: watch using polling'
python_script=$(cat <<'EOF'
import os
import shlex
import subprocess
import sys
import time

filename = sys.argv[1]
filepath = os.path.abspath(filename)
cmd = sys.argv[2]
cmd_parts = shlex.split(cmd)

last = cur = os.path.getmtime(filepath)
while True:
    time.sleep(1)
    try:
        cur = os.path.getmtime(filepath)
        if cur != last:
            subprocess.Popen(cmd_parts)
            last = cur
    except OSError:
        pass
EOF
)
        python -c "${python_script}" "${filename}" "${cmd}"
    fi
}

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
