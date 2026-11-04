-- Wrap Ctrl+Left/Right around the ends of the Space list: past the last Space lands on the first full-screen Space, before the first lands on the last.
-- Leave every other press to macOS, which keeps its slide animation; only the edge presses go through the slower Mission Control jump.

local function indexOf(spaces, space)
    for index, candidate in ipairs(spaces) do
        if candidate == space then
            return index
        end
    end
    return nil
end

-- Skip past the desktop on a rightward wrap, since the full-screen apps are where the work is; fall back to the first Space when none is full screen.
local function firstFullScreenSpace(spaces)
    for _, space in ipairs(spaces) do
        if hs.spaces.spaceType(space) == 'fullscreen' then
            return space
        end
    end
    return spaces[1]
end

-- Return the Space to wrap to, or nil when macOS can move in `direction` on its own.
local function wrapTarget(direction)
    local focused = hs.spaces.focusedSpace()
    local screen = hs.screen.find(hs.spaces.spaceDisplay(focused)) or hs.screen.mainScreen()
    local spaces = hs.spaces.spacesForScreen(screen) or {}
    local index = indexOf(spaces, focused)
    if index == nil then
        return nil
    elseif #spaces < 2 then
        return nil
    elseif direction == 'right' and index == #spaces then
        local target = firstFullScreenSpace(spaces)
        if target == focused then
            return nil
        end
        return target
    elseif direction == 'left' and index == 1 then
        return spaces[#spaces]
    end
    return nil
end

local function directionOf(keyCode)
    if keyCode == hs.keycodes.map.left then
        return 'left'
    elseif keyCode == hs.keycodes.map.right then
        return 'right'
    end
    return nil
end

-- Match Ctrl alone; arrow keys also carry the fn flag, so ignore it rather than requiring an exact match.
local function isCtrlOnly(flags)
    if not flags.ctrl then
        return false
    elseif flags.alt or flags.cmd or flags.shift then
        return false
    end
    return true
end

-- Keep the tap global so garbage collection doesn't stop it.
wrappingSpaceHotkeysTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local direction = directionOf(event:getKeyCode())
    if direction == nil then
        return false
    elseif not isCtrlOnly(event:getFlags()) then
        return false
    end
    local target = wrapTarget(direction)
    if target == nil then
        return false
    end
    print('wrappingSpaceHotkeys: ' .. direction .. ' wraps to Space ' .. target)
    hs.spaces.gotoSpace(target)
    return true
end)
wrappingSpaceHotkeysTap:start()
