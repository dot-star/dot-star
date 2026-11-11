-- Jump straight to the Nth full-screen Space on the focused screen with Ctrl+N, since macOS only numbers desktops and the full-screen apps are where the work is.
-- Jump to the first desktop with Ctrl+0, since Ctrl+1 no longer reaches it.
-- Leave a press for a Space that doesn't exist to the focused app.
require('follow_closed_full_screen_space')

local function digitOf(keyCode)
    for digit = 0, 9 do
        if keyCode == hs.keycodes.map[tostring(digit)] then
            return digit
        end
    end
    return nil
end

-- Match Ctrl alone, so Ctrl+Shift+N and other chords keep their app meaning.
local function isCtrlOnly(flags)
    if not flags.ctrl then
        return false
    elseif flags.alt or flags.cmd or flags.shift or flags.fn then
        return false
    end
    return true
end

local function fullScreenSpaces(spaces)
    local fullScreen = {}
    for _, space in ipairs(spaces) do
        if hs.spaces.spaceType(space) == 'fullscreen' then
            table.insert(fullScreen, space)
        end
    end
    return fullScreen
end

local function firstDesktop(spaces)
    for _, space in ipairs(spaces) do
        if hs.spaces.spaceType(space) == 'user' then
            return space
        end
    end
    return nil
end

local function targetFor(digit, spaces)
    if digit == 0 then
        return firstDesktop(spaces)
    end
    return fullScreenSpaces(spaces)[digit]
end

-- Return a window on the Space, since focusing it slides there faster than the Mission Control jump.
local function windowOn(space)
    for _, windowId in ipairs(hs.spaces.windowsForSpace(space) or {}) do
        if hs.window.get(windowId) ~= nil then
            return windowId
        end
    end
    return nil
end

-- Keep the tap global so garbage collection doesn't stop it.
numberedSpaceHotkeysTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local digit = digitOf(event:getKeyCode())
    if digit == nil then
        return false
    elseif not isCtrlOnly(event:getFlags()) then
        return false
    end
    local focused = hs.spaces.focusedSpace()
    local screen = hs.screen.find(hs.spaces.spaceDisplay(focused)) or hs.screen.mainScreen()
    local target = targetFor(digit, hs.spaces.spacesForScreen(screen) or {})
    if target == nil then
        return false
    elseif target == focused then
        return true
    end
    print('numberedSpaceHotkeys: Ctrl+' .. digit .. ' -> Space ' .. target)
    followClosedFullScreenSpace.goTo(target, windowOn(target))
    return true
end)
numberedSpaceHotkeysTap:start()
