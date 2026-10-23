-- Follow a closing full-screen Space to the next full-screen app, rather than the desktop macOS falls back to.
-- Arm it from the shell just before the window closes, passing the terminal's bundle id:
--   hs -c "require('follow_closed_full_screen_space'); return followClosedFullScreenSpace.arm('com.mitchellh.ghostty')"

-- Give up on a Space still open this long after arming, so a window that never closed can't yank focus later.
local GIVE_UP_SECONDS = 60
-- Poll often enough that the hop follows the close before the desktop gets used.
local POLL_SECONDS = 0.2

followClosedFullScreenSpace = {}

local function spaceExists(space)
    for _, spaces in pairs(hs.spaces.allSpaces() or {}) do
        for _, candidate in ipairs(spaces) do
            if candidate == space then
                return true
            end
        end
    end
    return false
end

local function indexOf(spaces, space)
    for index, candidate in ipairs(spaces) do
        if candidate == space then
            return index
        end
    end
    return nil
end

-- Return the nearest full-screen Space to the right of `index`, else the nearest to its left.
local function neighborFullScreenSpace(spaces, index)
    for position = index + 1, #spaces do
        if hs.spaces.spaceType(spaces[position]) == 'fullscreen' then
            return spaces[position]
        end
    end
    for position = index - 1, 1, -1 do
        if hs.spaces.spaceType(spaces[position]) == 'fullscreen' then
            return spaces[position]
        end
    end
    return nil
end

local function disarm()
    if followClosedFullScreenSpace.timer then
        followClosedFullScreenSpace.timer:stop()
        followClosedFullScreenSpace.timer = nil
    end
end

-- Arm the hop for the focused Space when it holds a full-screen window of `bundleId`; return what happened for the log.
function followClosedFullScreenSpace.arm(bundleId)
    disarm()

    local window = hs.window.focusedWindow()
    local closing = hs.spaces.focusedSpace()
    if window == nil then
        return 'skipped: no focused window'
    elseif window:application():bundleID() ~= bundleId then
        return 'skipped: focused window belongs to another app'
    elseif hs.spaces.spaceType(closing) ~= 'fullscreen' then
        return 'skipped: focused Space is not full screen'
    end

    local screen = hs.screen.find(hs.spaces.spaceDisplay(closing)) or hs.screen.mainScreen()
    local spaces = hs.spaces.spacesForScreen(screen) or {}
    local index = indexOf(spaces, closing)
    if index == nil then
        return 'skipped: focused Space not found on its screen'
    end

    local target = neighborFullScreenSpace(spaces, index)
    if target == nil then
        return 'skipped: no other full-screen Space'
    end

    local deadline = hs.timer.secondsSinceEpoch() + GIVE_UP_SECONDS
    -- Hold the timer in the global table so garbage collection can't stop it.
    followClosedFullScreenSpace.timer = hs.timer.doEvery(POLL_SECONDS, function()
        if hs.timer.secondsSinceEpoch() > deadline then
            disarm()
        elseif spaceExists(closing) then
            return
        else
            disarm()
            if spaceExists(target) then
                hs.spaces.gotoSpace(target)
            end
        end
    end)
    return 'armed'
end
