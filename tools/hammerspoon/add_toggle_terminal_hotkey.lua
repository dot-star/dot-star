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

function toggleGhostty()
    hs.osascript.applescript([[
    set targetApplication to application "Ghostty"
    if targetApplication is running then

        set ghosttyFrontMost to false
        tell application "System Events"
            if frontmost of process "Ghostty" then
                set ghosttyFrontMost to true
            end if
        end tell

        -- Count windows through System Events rather than Ghostty's own
        -- dictionary, which reports 0 however many are open.
        tell application "System Events" to set ghosttyWindowCount to (count of windows of process "Ghostty")

        if ghosttyFrontMost then
            if ghosttyWindowCount = 0 then
                tell application "System Events" to keystroke "t" using command down
            else
                tell application "System Events" to set visible of process "Ghostty" to false
            end if
        else
            tell targetApplication to reopen -- un-minimize
            tell targetApplication to activate
            if ghosttyWindowCount = 0 then
                tell application "System Events" to keystroke "t" using command down
            end if
        end if
    else
        tell targetApplication to activate
    end if
    ]])
end

-- Bind the terminal hotkeys to one of:
--   toggleGhostty
--   toggleTerminal
hs.hotkey.bind({'option'}, 'i', toggleGhostty)
hs.hotkey.bind({}, 'F18', toggleGhostty)
