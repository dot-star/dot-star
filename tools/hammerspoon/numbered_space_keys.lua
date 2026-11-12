-- Share which Space each Ctrl+N key reaches: Ctrl+0 the first desktop, Ctrl+1 to 9 the full-screen Spaces in swipe order.
-- Require nothing else here but space_types, which requires nothing, so both the hotkeys and the page dots can load it without a require loop.
local spaceTypes = require('space_types')

local numberedSpaceKeys = {}

local function fullScreenSpaces(spaces)
    local fullScreen = {}
    for _, space in ipairs(spaces) do
        if spaceTypes.of(space) == 'fullscreen' then
            table.insert(fullScreen, space)
        end
    end
    return fullScreen
end

local function firstDesktop(spaces)
    for _, space in ipairs(spaces) do
        if spaceTypes.of(space) == 'user' then
            return space
        end
    end
    return nil
end

-- Return the Space among `spaces` that Ctrl+`digit` reaches, or nil when there's none.
function numberedSpaceKeys.targetFor(digit, spaces)
    if digit == 0 then
        return firstDesktop(spaces)
    end
    return fullScreenSpaces(spaces)[digit]
end

-- Map each of `spaces` that has a Ctrl+N key to its digit, so the page dots label the Space the key would reach.
function numberedSpaceKeys.keysFor(spaces)
    local keys = {}
    for digit = 0, 9 do
        local space = numberedSpaceKeys.targetFor(digit, spaces)
        if space ~= nil then
            keys[space] = digit
        end
    end
    return keys
end

return numberedSpaceKeys
