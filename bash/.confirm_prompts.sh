_display_confirm_prompt() {
    # Internal helper: display a colored 1-char prompt and echo reply.
    # Prefer the named wrappers below.
    local color="${1}"
    local message="${2}"
    local text
    text="$(echo -e "\x1b[${color}m${message}\x1b[0m")"

    if [[ -n "${BASH_VERSION}" ]]; then
        read -p "${text} " -n 1 -r
        echo "${REPLY}"
    elif [[ -n "${ZSH_VERSION}" ]]; then
        read -k 1 "REPLY?${text} "
        echo "${REPLY}"
    fi
}

display_confirm_prompt_destructive() {
    # Bold red. Use for irreversible actions (drop, delete, force-push, rm).
    # Usage:
    #   response="$(display_confirm_prompt_destructive "Drop stash X?")"
    _display_confirm_prompt "1;91" "${1}"
}

display_confirm_prompt_caution() {
    # Yellow. Use for reversible but disruptive actions (overwrite, replace).
    # Usage:
    #   response="$(display_confirm_prompt_caution "Overwrite file?")"
    _display_confirm_prompt "0;93" "${1}"
}

display_confirm_prompt_info() {
    # Cyan. Use for neutral confirmations (create, pop stash).
    # Usage:
    #   response="$(display_confirm_prompt_info "Create file?")"
    _display_confirm_prompt "0;96" "${1}"
}

display_confirm_prompt() {
    # Back-compat alias for display_confirm_prompt_caution.
    display_confirm_prompt_caution "${1}"
}
