# Hammerspoon Aliases

space_position_experiment() {
    # Usage:
    #   $ space_position_experiment                  # show every experiment's state
    #   $ space_position_experiment edge_bars off
    #   $ space_position_experiment page_dots on

    local name="${1}"
    local state="${2}"
    # Call the client by path; Hammerspoon ships it inside the app bundle rather than on PATH.
    local hammerspoon_cli="/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"

    if [[ -z "${name}" ]]; then
        "${hammerspoon_cli}" -c "return showSpacePosition.set()"
    elif [[ "${state}" == "on" ]]; then
        "${hammerspoon_cli}" -c "return showSpacePosition.set('${name}', true)"
    elif [[ "${state}" == "off" ]]; then
        "${hammerspoon_cli}" -c "return showSpacePosition.set('${name}', false)"
    else
        echo "Usage: space_position_experiment [<bottom_bar|cycle_colors|edge_bars|page_dots|page_dots_pill> <on|off>]"
        return 1
    fi
}
alias spx="space_position_experiment"
