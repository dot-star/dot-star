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

-- Remember the Ghostty window focused last, on any Space, so a press returns to it.
-- Skip plain activation: it lands on Ghostty's main window, which can sit on another Space.
-- Hold the window object, not its id: hs.window.get only finds windows on the Space in view.
lastGhosttyWindow = nil

-- Describe a window for the log: id, Spaces and title.
local function describeWindow(window)
    if window == nil then
        return 'nil'
    end
    return tostring(window:id()) .. ' spaces=' .. hs.inspect(hs.spaces.windowSpaces(window)) .. ' "' .. tostring(window:title()) .. '"'
end

-- Record the window Ghostty had focused at the moment it loses focus, which is the one you left.
-- Skip hs.window.filter's focus events: they miss switches between full-screen Spaces.
-- Keep the watcher global so garbage collection doesn't stop it.
ghosttyDeactivationWatcher = hs.application.watcher.new(function(name, event, app)
    if event ~= hs.application.watcher.deactivated then
        return
    elseif app:bundleID() ~= 'com.mitchellh.ghostty' then
        return
    end
    local window = app:focusedWindow()
    if window == nil then
        ghosttyLog.i('Ghostty lost focus with no focused window; kept ' .. describeWindow(lastGhosttyWindow))
        return
    end
    lastGhosttyWindow = window
    ghosttyLog.i('Ghostty lost focus, remembered window ' .. describeWindow(window))
end)
ghosttyDeactivationWatcher:start()

-- Log where focus ended up once the Space switch has had time to settle.
-- Hold the timer globally: garbage collection drops an unreferenced timer before it fires.
local function logLanding(label)
    ghosttyLandingTimer = hs.timer.doAfter(1.5, function()
        ghosttyLog.i(label .. ': landed on Space ' .. tostring(hs.spaces.focusedSpace()) .. ', focused window ' .. describeWindow(hs.window.focusedWindow()))
    end)
end

-- Give up waiting on a modifier still held this long, and switch anyway.
local MODIFIER_WAIT_SECONDS = 1
local MODIFIER_POLL_SECONDS = 0.02

local function anyModifierDown()
    local modifiers = hs.eventtap.checkKeyboardModifiers()
    for _, name in ipairs({'alt', 'cmd', 'ctrl', 'fn', 'shift'}) do
        if modifiers[name] then
            return true
        end
    end
    return false
end

-- Switch to `space` once every modifier is up: gotoSpace drives Mission Control, which stalls open while the hotkey's Option is still held.
function goToSpaceOnceModifiersUp(space)
    if ghosttyModifierTimer then
        ghosttyModifierTimer:stop()
    end
    local deadline = hs.timer.secondsSinceEpoch() + MODIFIER_WAIT_SECONDS
    -- Hold the timer globally: garbage collection drops an unreferenced timer before it fires.
    ghosttyModifierTimer = hs.timer.doEvery(MODIFIER_POLL_SECONDS, function()
        local timedOut = hs.timer.secondsSinceEpoch() > deadline
        if anyModifierDown() and not timedOut then
            return
        end
        ghosttyModifierTimer:stop()
        ghosttyModifierTimer = nil
        ghosttyLog.i('going to Space ' .. space .. (timedOut and ' (modifier still held)' or ''))
        hs.spaces.gotoSpace(space)
    end)
end

-- Focus the remembered Ghostty window when Ghostty isn't frontmost, returning whether it did.
local function focusLastGhosttyWindow()
    local app = hs.application.get('com.mitchellh.ghostty')
    ghosttyLog.i('press on Space ' .. tostring(hs.spaces.focusedSpace()) .. ', remembered window ' .. describeWindow(lastGhosttyWindow))
    if app == nil then
        ghosttyLog.i('fallback: Ghostty not running')
        return false
    elseif app:isFrontmost() then
        ghosttyLog.i('fallback: Ghostty frontmost')
        return false
    elseif lastGhosttyWindow == nil then
        ghosttyLog.i('fallback: no remembered window')
        return false
    -- Fall back when the window has closed since it last had focus.
    elseif lastGhosttyWindow:application() == nil then
        ghosttyLog.i('fallback: remembered window closed')
        return false
    end
    app:unhide()
    -- Switch to the window's Space rather than focusing it: focus activates the app, which jumps to its main window's Space.
    -- Skip focus after the switch too, since it interrupts the Mission Control animation gotoSpace runs.
    local space = (hs.spaces.windowSpaces(lastGhosttyWindow) or {})[1]
    if space == nil then
        ghosttyLog.i('no Space for window, focusing it')
        lastGhosttyWindow:focus()
    else
        goToSpaceOnceModifiersUp(space)
    end
    logLanding('remembered window')
    return true
end

function toggleGhostty()
    if focusLastGhosttyWindow() then
        return
    end
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
        logLanding('AppleScript')
    else
        ghosttyLog.e('AppleScript failed: ' .. hs.inspect(descriptor))
    end
end

-- Bind the terminal hotkeys to one of:
--   toggleGhostty
--   toggleTerminal
hs.hotkey.bind({'option'}, 'i', toggleGhostty)
hs.hotkey.bind({}, 'F18', toggleGhostty)
