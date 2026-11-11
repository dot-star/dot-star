-- Share which Space each Ctrl+N key reaches: Ctrl+0 the first desktop, Ctrl+1 to 9 the full-screen Spaces in swipe order.
local numberedSpaceKeys = {}

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

-- Return the Space among `spaces` that Ctrl+`digit` reaches, or nil when there's none.
function numberedSpaceKeys.targetFor(digit, spaces)
    if digit == 0 then
        return firstDesktop(spaces)
    end
    return fullScreenSpaces(spaces)[digit]
end

return numberedSpaceKeys
