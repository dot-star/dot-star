# Hammerspoon Aliases

space_position_experiment() {
    # Usage:
    #   $ space_position_experiment                  # show every experiment's state
    #   $ space_position_experiment edge_bars off
    #   $ space_position_experiment page_dots on
    #   $ space_position_experiment decision_style blink
    #   $ space_position_experiment follow_idle_seconds 60

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
    elif [[ "${name}" == "decision_style" && -n "${state}" ]]; then
        "${hammerspoon_cli}" -c "return showSpacePosition.set('${name}', '${state}')"
    elif [[ "${name}" == "focus_marker" && -n "${state}" ]]; then
        "${hammerspoon_cli}" -c "return showSpacePosition.set('${name}', '${state}')"
    elif [[ "${name}" == "pending_style" && -n "${state}" ]]; then
        "${hammerspoon_cli}" -c "return showSpacePosition.set('${name}', '${state}')"
    elif [[ "${name}" == "swipe_hint_style" && -n "${state}" ]]; then
        "${hammerspoon_cli}" -c "return showSpacePosition.set('${name}', '${state}')"
    elif [[ "${name}" == "follow_idle_seconds" && "${state}" =~ ^[0-9]+$ ]]; then
        "${hammerspoon_cli}" -c "return showSpacePosition.set('${name}', ${state})"
    else
        echo "Usage: space_position_experiment [<bottom_bar|cycle_colors|desktop_dots|edge_bars|follow_countdown|follow_order|follow_ready|page_dots|page_dots_pill|session_state|swipe_hint|top_bar|vertical_dots> <on|off>]"
        echo "       space_position_experiment decision_style <blink|flash|heartbeat|nudge>"
        echo "       space_position_experiment focus_marker <center|underline>"
        echo "       space_position_experiment pending_style <dashed|dot|pulse>"
        echo "       space_position_experiment swipe_hint_style <block|chevron|double|large|tab>"
        echo "       space_position_experiment follow_idle_seconds <seconds>"
        return 1
    fi
}
alias spx="space_position_experiment"

full_screen_follow_setting() {
    # Usage:
    #   $ full_screen_follow_setting                            # show every setting's value
    #   $ full_screen_follow_setting received_fade_seconds 0.6

    local name="${1}"
    local value="${2}"
    # Call the client by path; Hammerspoon ships it inside the app bundle rather than on PATH.
    local hammerspoon_cli="/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs"

    if [[ -z "${name}" ]]; then
        "${hammerspoon_cli}" -c "require('follow_closed_full_screen_space'); return followClosedFullScreenSpace.set()"
    elif [[ "${value}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        "${hammerspoon_cli}" -c "require('follow_closed_full_screen_space'); return followClosedFullScreenSpace.set('${name}', ${value})"
    else
        echo "Usage: full_screen_follow_setting [<received_seconds|received_fade_seconds> <seconds>]"
        return 1
    fi
}
alias fsf="full_screen_follow_setting"
