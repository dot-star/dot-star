-- Share each Space's type, looked up once per Space since hs.spaces.spaceType copies every display's Space list on each call.
-- Remember a type for good: a Space keeps its type for life and macOS numbers each new Space past the last (observed, not documented).
local spaceTypes = {}

local typesBySpace = {}

-- Return 'user' for a desktop or 'fullscreen' for a full-screen Space, or nil and the lookup's error for a Space it can't find.
function spaceTypes.of(space)
    local known = typesBySpace[space]
    if known ~= nil then
        return known
    end
    local spaceType, err = hs.spaces.spaceType(space)
    if spaceType ~= nil then
        typesBySpace[space] = spaceType
    end
    return spaceType, err
end

return spaceTypes
