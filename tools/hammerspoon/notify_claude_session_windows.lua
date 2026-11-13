-- Post the Claude window hook's notifications, one per terminal window, each raising its window when clicked.
-- Tag each notification with its window so a later post finds and replaces it, even after a config reload empties Lua state.
local claudeSessionNotifications = {}

local TAG_PREFIX = 'claude-session:'

-- Focus the window, falling back to activating its app when the window is gone or sits in a background tab.
function claudeSessionNotifications.raise(windowId, bundleId)
    local window = hs.window.get(windowId)
    if window ~= nil then
        window:focus()
        return 'raised window ' .. windowId
    end
    local app = hs.application.get(bundleId)
    if app == nil then
        return 'window ' .. windowId .. ' gone and app ' .. bundleId .. ' not running; nothing raised'
    end
    app:activate()
    return 'window ' .. windowId .. ' not visible (background tab?); activated ' .. bundleId .. ' instead'
end

-- Register the click handler a tag names; skip tags this module didn't make.
local function registerTag(tag)
    if tag:sub(1, #TAG_PREFIX) ~= TAG_PREFIX then
        return
    end
    local windowId, bundleId = tag:sub(#TAG_PREFIX + 1):match('^(%d+):(.*)$')
    if windowId == nil then
        return
    end
    hs.notify.register(tag, function()
        claudeSessionNotifications.raise(tonumber(windowId), bundleId)
    end)
end

-- Replace the window's notification with a new one that stays in Notification Center until clicked.
function claudeSessionNotifications.post(windowId, bundleId, title, message)
    local tag = TAG_PREFIX .. windowId .. ':' .. bundleId
    for _, delivered in ipairs(hs.notify.deliveredNotifications()) do
        if delivered:getFunctionTag() == tag then
            delivered:withdraw()
        end
    end
    registerTag(tag)
    hs.notify.new(tag, {
        title = title,
        informativeText = message,
        -- Keep it until clicked; hs.notify withdraws it after 5 seconds by default.
        withdrawAfter = 0,
    }):send()
    return 'notification dispatched for window ' .. windowId .. '; if invisible, allow Hammerspoon in System Settings > Notifications'
end

-- Register the handlers again for notifications posted before this load, since a reload drops every registered callback.
for _, delivered in ipairs(hs.notify.deliveredNotifications()) do
    local tag = delivered:getFunctionTag()
    if tag ~= nil then
        registerTag(tag)
    end
end

return claudeSessionNotifications
