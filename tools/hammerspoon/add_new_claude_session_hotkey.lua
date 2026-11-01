-- Open a new Ghostty window and type a command into its shell, so quitting Claude
-- leaves a prompt behind rather than closing the window.
-- Set new_claude_session_input in init.lua above the dot-star bootstrap block to type a different command.
new_claude_session_input = new_claude_session_input or 'claude'

-- Return the ids of Ghostty's current windows, so the new window can be told apart from them.
local function ghosttyWindowIds()
    local ids = {}
    local app = hs.application.get('Ghostty')
    if app == nil then
        return ids
    end
    for _, window in ipairs(app:allWindows()) do
        ids[window:id()] = true
    end
    return ids
end

-- Return the first Ghostty window missing from existingIds, or nil until one appears.
local function newGhosttyWindow(existingIds)
    local app = hs.application.get('Ghostty')
    if app == nil then
        return nil
    end
    for _, window in ipairs(app:allWindows()) do
        if not existingIds[window:id()] then
            return window
        end
    end
    return nil
end

-- Put the new window in full screen once it exists. Ghostty's AppleScript has no full-screen setting, and its config one would cover every window.
local function makeNewGhosttyWindowFullScreen(existingIds)
    -- Give up after a few seconds so a failed launch doesn't leave the timer polling forever.
    local deadline = hs.timer.secondsSinceEpoch() + 5
    local newWindow = nil
    hs.timer.waitUntil(
        function()
            newWindow = newGhosttyWindow(existingIds)
            if newWindow ~= nil then
                return true
            elseif hs.timer.secondsSinceEpoch() > deadline then
                return true
            else
                return false
            end
        end,
        function()
            if newWindow == nil then
                print('newClaudeSession: no new Ghostty window appeared')
            else
                newWindow:setFullScreen(true)
            end
        end,
        0.05
    )
end

function newClaudeSession()
    return function()
        print('newClaudeSession')
        local existingIds = ghosttyWindowIds()
        hs.osascript.applescript([[
        tell application "Ghostty"
            set surfaceConfiguration to new surface configuration
            set initial input of surfaceConfiguration to "]] .. new_claude_session_input .. [[" & linefeed
            -- Clear the child-session marker so the window starts a top-level Claude session
            -- even when Ghostty itself was launched from inside one.
            set environment variables of surfaceConfiguration to {"CLAUDE_CODE_CHILD_SESSION="}
            new window with configuration surfaceConfiguration
            activate
        end tell
        ]])
        makeNewGhosttyWindowFullScreen(existingIds)
    end
end
hs.hotkey.bind({'option'}, 'd', newClaudeSession())
