-- Log every window focus and Space change, so a switch nobody asked for leaves a trace whatever caused it.
-- Read it beside the other logs in the same folder, matching timestamps to find which step moved focus:
--   tail -f /tmp/claude-state-hook/window_focus_changes.log

-- Share the folder the claude hooks log to, so one `tail -f` covers every window step.
local LOG_DIR = '/tmp/claude-state-hook'
local LOG_FILE = LOG_DIR .. '/window_focus_changes.log'
-- Poll instead of subscribing: hs.window.filter delivered focus events late and in batches, and dropped some.
-- Check often enough that a switch's timestamp still lines up with the log line of whatever caused it.
local POLL_SECONDS = 0.5

-- Append a timestamped line to the log.
local function log(message)
    hs.fs.mkdir(LOG_DIR)
    local handle = io.open(LOG_FILE, 'a')
    if handle == nil then
        return
    end
    handle:write(os.date('%Y-%m-%d %H:%M:%S') .. ' ' .. message .. '\n')
    handle:close()
end

-- Name a window by app, id and title, the same handles the other logs use.
local function describeWindow(window)
    if window == nil then
        return 'no focused window'
    end
    local app = window:application()
    local appName = 'unknown app'
    if app ~= nil then
        appName = app:name() .. ' (' .. tostring(app:bundleID()) .. ')'
    end
    return appName .. ' window ' .. tostring(window:id()) .. ' titled ' .. window:title()
end

local lastWindowId = nil
local lastSpace = nil

-- Log the focused window and Space whenever either differs from the last poll.
local function pollFocus()
    local window = hs.window.focusedWindow()
    local windowId = nil
    if window ~= nil then
        windowId = window:id()
    end
    local space = hs.spaces.focusedSpace()
    if windowId == lastWindowId and space == lastSpace then
        return
    end
    lastWindowId = windowId
    lastSpace = space
    log('focus: ' .. describeWindow(window) .. ' on Space ' .. tostring(space))
end

-- Keep the timer in a global so garbage collection can't stop it.
windowFocusChangesTimer = hs.timer.doEvery(POLL_SECONDS, pollFocus)
