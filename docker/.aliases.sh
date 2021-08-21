docker_psa() {
    clear

    ps_result=$(docker ps --all --format "table {{.Image}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}")
    ps_table_header=$(echo "${ps_result}" | head --lines=1)
    ps_table_rows_up=$(
        echo "${ps_result}" |
        tail --lines=+2 |
        \grep "Up" |
        # List running instances first.
        sort --ignore-leading-blanks --version-sort --key=4 --key=2 --key=1
    )
    ps_table_rows_exited=$(
        echo "${ps_result}" |
        tail --lines=+2 |
        \grep "Exited" |
        # List running instances first.
        sort --ignore-leading-blanks --version-sort --key=4 --key=2 --key=1
    )

    i=0
    echo "${ps_table_header}"
    echo "${ps_table_rows_up}" | while read row; do
        if [ $(( $i % 2 )) -eq 0 ]; then
            echo -e "\e[48;5;235m${row}\e[0m"
        else
            echo -e "\e[48;5;232m${row}\e[0m"
        fi
        ((i+=1))
    done
    echo "${ps_table_rows_exited}" | while read row; do
        echo -e "\e[2;40;97m${row}\e[0m"
        ((i+=1))
    done
    echo

    images_result="$(docker images)"
    images_table_header=$(echo "${images_result}" | head --lines=1)
    images_table_rows=$(
        echo "${images_result}" |
        tail --lines=+2
    )
    echo "${images_table_header}"
    echo "${images_table_rows}" | while read row; do
        if [ $(( $i % 2 )) -eq 0 ]; then
            echo -e "\e[48;5;235m${row}\e[0m"
        else
            echo -e "\e[48;5;232m${row}\e[0m"
        fi
        ((i+=1))
    done
}

docker_image_prune() {
    set -x
    docker image prune

    # Use `docker image prune --all' for removing dangling and ununsed images
    # (images not referenced by any container).
    until="$(date --rfc-3339="date" --date="3 months ago")"
    docker image prune --all --filter="until=${until}"
    set +x
}

_docker() {
    # Run docker only if is not already running.
    if (! docker stats --no-stream &> /dev/null); then
        if [[ "${OSTYPE}" == "darwin"* ]]; then
            open /Applications/Docker.app

            # Wait until docker daemon is running and has completed initialization.
            echo -n "Waiting for docker."
            while (! docker stats --no-stream &> /dev/null); do
                echo -n "."
                sleep 1
            done
            echo ""
        else
            echo "docker is not running"
            return
        fi
    fi

    docker "${@}"
}

alias attach="docker attach"
alias dc="_docker"
alias doc="_docker"
alias docker="_docker"
alias img="clear; docker images; echo; docker ps -a"
alias pause="docker pause"
alias prune="docker_image_prune"
alias psa="docker_psa"
alias rmi="clear; docker rmi"
alias stop="docker stop"
