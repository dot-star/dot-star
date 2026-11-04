function toggleTerminal()
    hs.osascript.applescript([[
    set targetApplication to application "Terminal"
    if targetApplication is running then

        set terminalFrontMost to false
        tell application "System Events"
            if frontmost of process "Terminal" then
                set terminalFrontMost to true
            end if
        end tell

        tell targetApplication to set terminalTabCount to (count of windows)

        if terminalFrontMost then
            if terminalTabCount = 0 then
                tell application "System Events" to keystroke "t" using command down
            else
                tell application "System Events" to set visible of process "Terminal" to false
            end if
        else
            tell targetApplication to reopen -- un-minimize
            tell targetApplication to activate
            if terminalTabCount = 0 then
                tell application "System Events" to keystroke "t" using command down
            end if
        end if
    else
        tell targetApplication to activate
    end if
    ]])
end

-- Log each toggle to the Hammerspoon console under "toggleGhostty".
local ghosttyLog = hs.logger.new('toggleGhostty', 'info')

function toggleGhostty()
    -- Return the branch taken so the console shows what each press did.
    local ok, result, descriptor = hs.osascript.applescript([[
    set targetApplication to application "Ghostty"
    if targetApplication is running then

        set ghosttyFrontMost to false
        tell application "System Events"
            if frontmost of process "Ghostty" then
                set ghosttyFrontMost to true
            end if
            set ghosttyHidden to not (visible of process "Ghostty")
        end tell

        set ghosttyState to "frontmost=" & ghosttyFrontMost & " hidden=" & ghosttyHidden & ": "

        if ghosttyFrontMost then

            -- TODO: Open a window instead of hiding when frontmost Ghostty has none (hiding an empty
            -- Ghostty makes the first press look dead; needs a window check that sees other Spaces).

            tell application "System Events" to set visible of process "Ghostty" to false
            return ghosttyState & "hid frontmost Ghostty"
        else
            -- Leave opening a window to reopen rather than counting windows
            -- first: System Events sees none on other Spaces or when hidden.
            tell targetApplication to reopen -- un-minimize, or open a window if none
            tell targetApplication to activate
            return ghosttyState & "reopened and activated Ghostty"
        end if
    else
        tell targetApplication to activate
        return "not running: launched Ghostty"
    end if
    ]])
    if ok then
        ghosttyLog.i(result)
    else
        ghosttyLog.e('AppleScript failed: ' .. hs.inspect(descriptor))
    end
end

-- Bind the terminal hotkeys to one of:
--   toggleGhostty
--   toggleTerminal
hs.hotkey.bind({'option'}, 'i', toggleGhostty)
hs.hotkey.bind({}, 'F18', toggleGhostty)
