-- Keep one set of canvases per Space, so each set slides in with its own Space instead of blinking in after a swipe.
local pinCanvasesToSpaces = {}

-- Stay on the Space the canvas was shown on, so it slides in with that Space; macOS blanks an all-Spaces window mid-swipe.
pinCanvasesToSpaces.BEHAVIOR = {
    'fullScreenAuxiliary',
    'stationary',
}

-- Drop the sets in `setsBySpace` of Spaces that no longer exist, handing each to `deleteSet`.
function pinCanvasesToSpaces.pruneClosedSpaces(setsBySpace, deleteSet)
    local live = {}
    for _, spaces in pairs(hs.spaces.allSpaces() or {}) do
        for _, space in ipairs(spaces) do
            live[space] = true
        end
    end
    for space, set in pairs(setsBySpace) do
        if not live[space] then
            deleteSet(set)
            setsBySpace[space] = nil
        end
    end
end

return pinCanvasesToSpaces
