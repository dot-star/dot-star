# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards.
# Parse in-shell rather than `grep | grep | cut`, which forks three processes on every shell startup.
if [ -e "$HOME/.ssh/config" ]; then
    ssh_config_hosts=""
    while IFS= read -r ssh_config_line || [[ -n "${ssh_config_line}" ]]; do
        if [[ "${ssh_config_line}" != Host* ]] || [[ "${ssh_config_line}" == *[?*]* ]]; then
            continue
        fi

        # Take the second space-separated field, or the whole line when it has no space, like `cut -d " " -f2`.
        if [[ "${ssh_config_line}" == *" "* ]]; then
            ssh_config_line="${ssh_config_line#* }"
            ssh_config_line="${ssh_config_line%% *}"
        fi
        ssh_config_hosts+="${ssh_config_line}"$'\n'
    done <"$HOME/.ssh/config"
    complete -o "default" -o "nospace" -W "${ssh_config_hosts%$'\n'}" scp sftp ssh
    unset ssh_config_hosts ssh_config_line
fi
