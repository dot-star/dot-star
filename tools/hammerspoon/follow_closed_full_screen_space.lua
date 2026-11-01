-- Follow a closing full-screen Space to the session showing the green check you were on last, else the next full-screen app, rather than the desktop macOS falls back to.
-- Arm it from the shell just before the window closes, passing the terminal's bundle id:
--   hs -c "require('follow_closed_full_screen_space'); return followClosedFullScreenSpace.arm('com.mitchellh.ghostty')"
-- Call `leave` instead to go right away, once the window is sure to close.

-- Give up on a Space still open this long after arming, so a window that never closed can't yank focus later.
local GIVE_UP_SECONDS = 60
-- Poll often enough that the hop follows the close before the desktop gets used.
local POLL_SECONDS = 0.2
-- Share the folder the claude hooks log to, so one `tail -f` covers every window step.
local LOG_DIR = '/tmp/claude-state-hook'
local LOG_FILE = LOG_DIR .. '/follow_closed_full_screen_space.log'

require('show_space_position')

followClosedFullScreenSpace = {}

-- Append a timestamped line to the log and echo it to the Hammerspoon console.
local function log(message)
    print('followClosedFullScreenSpace: ' .. message)
    hs.fs.mkdir(LOG_DIR)
    local handle = io.open(LOG_FILE, 'a')
    if handle == nil then
        return
    end
    handle:write(os.date('%Y-%m-%d %H:%M:%S') .. ' ' .. message .. '\n')
    handle:close()
end

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

-- Pick the green session you were on most recently, not the nearest one, so a switch lands where your context for its objective is freshest.
-- Rank by last seen rather than by turning green: a session started long ago that just finished is already stale in your head.
-- Return that Space on the closing Space's screen and its session's window, else nil.
local function mostRecentReadySpace(spaces, closing)
    for _, ready in ipairs(showSpacePosition.readySessionsByRecency()) do
        if ready.space == closing then
            -- Skip the session that's closing.
            goto continue
        elseif indexOf(spaces, ready.space) ~= nil then
            return ready.space, ready.windowId
        end
        ::continue::
    end
    return nil, nil
end

-- Switch to `target`, focusing its ready session's window when there is one so that session's tab lands in front.
local function goTo(target, windowId)
    local window = nil
    if windowId ~= nil then
        window = hs.window.get(windowId)
    end
    if window ~= nil then
        window:focus()
    else
        hs.spaces.gotoSpace(target)
    end
end

local function disarm()
    if followClosedFullScreenSpace.timer then
        followClosedFullScreenSpace.timer:stop()
        followClosedFullScreenSpace.timer = nil
    end
end

-- Return the focused Space, the Space to follow it to, the target's ready window (nil when it has none) and how the target was picked; a skip returns nil for each and why.
local function closingAndTarget(bundleId)
    local window = hs.window.focusedWindow()
    local closing = hs.spaces.focusedSpace()
    if window == nil then
        return nil, nil, nil, nil, 'skipped: no focused window'
    elseif window:application():bundleID() ~= bundleId then
        return nil, nil, nil, nil, 'skipped: focused window belongs to another app (' .. tostring(window:application():bundleID()) .. ')'
    elseif hs.spaces.spaceType(closing) ~= 'fullscreen' then
        return nil, nil, nil, nil, 'skipped: focused Space ' .. tostring(closing) .. ' is ' .. tostring(hs.spaces.spaceType(closing)) .. ', not full screen'
    end

    local screen = hs.screen.find(hs.spaces.spaceDisplay(closing)) or hs.screen.mainScreen()
    local spaces = hs.spaces.spacesForScreen(screen) or {}
    local index = indexOf(spaces, closing)
    if index == nil then
        return nil, nil, nil, nil, 'skipped: focused Space ' .. tostring(closing) .. ' not found on its screen'
    end

    local readyTarget, readyWindowId = mostRecentReadySpace(spaces, closing)
    if readyTarget ~= nil then
        return closing, readyTarget, readyWindowId, 'ready session', nil
    end

    local target = neighborFullScreenSpace(spaces, index)
    if target == nil then
        return nil, nil, nil, nil, 'skipped: no ready session and no other full-screen Space beside ' .. tostring(closing) .. ' (position ' .. index .. ' of ' .. #spaces .. ')'
    end
    return closing, target, nil, 'nearest full screen', nil
end

-- Arm the hop for the focused Space when it holds a full-screen window of `bundleId`; return what happened for the log.
function followClosedFullScreenSpace.arm(bundleId)
    disarm()

    local closing, target, windowId, pickedBy, skipped = closingAndTarget(bundleId)
    if skipped then
        log('arm ' .. bundleId .. ': ' .. skipped)
        return skipped
    end

    local deadline = hs.timer.secondsSinceEpoch() + GIVE_UP_SECONDS
    -- Hold the timer in the global table so garbage collection can't stop it.
    followClosedFullScreenSpace.timer = hs.timer.doEvery(POLL_SECONDS, function()
        if hs.timer.secondsSinceEpoch() > deadline then
            disarm()
            log('arm: gave up, Space ' .. closing .. ' still open after ' .. GIVE_UP_SECONDS .. 's')
        elseif spaceExists(closing) then
            return
        else
            disarm()
            if spaceExists(target) then
                log('arm: Space ' .. closing .. ' closed, following to ' .. target .. ' (' .. pickedBy .. ')')
                goTo(target, windowId)
            else
                log('arm: Space ' .. closing .. ' closed, but target ' .. target .. ' is gone too')
            end
        end
    end)
    log('arm ' .. bundleId .. ': armed, Space ' .. closing .. ' -> ' .. target .. ' (' .. pickedBy .. ')')
    return 'armed'
end

-- Go now to the Space `arm` would follow to, for a window known to be closing; return what happened for the log.
function followClosedFullScreenSpace.leave(bundleId)
    disarm()

    local closing, target, windowId, pickedBy, skipped = closingAndTarget(bundleId)
    if skipped then
        log('leave ' .. bundleId .. ': ' .. skipped)
        return skipped
    end

    log('leave ' .. bundleId .. ': Space ' .. closing .. ' -> ' .. target .. ' (' .. pickedBy .. ')')
    goTo(target, windowId)
    return 'left'
end
