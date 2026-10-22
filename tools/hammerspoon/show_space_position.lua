-- Show where the focused Space sits in the swipe order, as experiments toggled independently:
--   Keep a strip on each edge that has another Space beyond it, none on an edge with nothing past it (edge_bars).
--   Flash a row of dots after each switch, the focused Space filled (page_dots).
-- Toggle from the shell with `space_position_experiment`; each flag persists across reloads.

-- Apply each experiment's default until it's toggled; a saved setting wins after that.
local DEFAULT_ENABLED = {
    edge_bars = true,
    page_dots = false,
}
local SETTINGS_PREFIX = 'show_space_position.'
local COLOR = { red = 1, green = 0.6, blue = 0.1, alpha = 0.9 }
local EDGE_BAR_WIDTH = 4
local DOT_SIZE = 10
local DOT_GAP = 10
-- Clear the terminal's prompt and status lines at the bottom of the screen.
local DOTS_BOTTOM_MARGIN = 160
-- Keep the dots up long enough to read after a swipe settles, short enough to be gone before typing resumes.
local DOTS_VISIBLE_SECONDS = 1
local DOTS_FADE_SECONDS = 0.3

-- Join every Space, full-screen ones included, so one overlay serves whichever Space is focused.
local OVERLAY_BEHAVIOR = {
    'canJoinAllSpaces',
    'fullScreenAuxiliary',
    'stationary',
}

showSpacePosition = {}

local leftBar = nil
local rightBar = nil
local dots = nil
local dotsTimer = nil

local function isEnabled(name)
    local value = hs.settings.get(SETTINGS_PREFIX .. name)
    if value == nil then
        return DEFAULT_ENABLED[name]
    end
    return value
end

local function experimentNames()
    local names = {}
    for name in pairs(DEFAULT_ENABLED) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function newOverlay(frame)
    local overlay = hs.canvas.new(frame)
    overlay:level(hs.canvas.windowLevels.overlay)
    overlay:behavior(OVERLAY_BEHAVIOR)
    return overlay
end

local function deleteOverlay(overlay)
    if overlay then
        overlay:delete()
    end
    return nil
end

-- Return the focused Space's 1-based position, the Space count and the screen holding them.
local function focusedPosition()
    local focused = hs.spaces.focusedSpace()
    local screen = hs.screen.find(hs.spaces.spaceDisplay(focused)) or hs.screen.mainScreen()
    local spaces = hs.spaces.spacesForScreen(screen) or {}
    for index, space in ipairs(spaces) do
        if space == focused then
            return index, #spaces, screen
        end
    end
    return nil, #spaces, screen
end

local function newEdgeBar(screenFrame, x)
    local bar = newOverlay({ x = x, y = screenFrame.y, w = EDGE_BAR_WIDTH, h = screenFrame.h })
    bar[1] = { type = 'rectangle', action = 'fill', fillColor = COLOR }
    return bar
end

local function renderEdgeBars(index, count, screen)
    leftBar = deleteOverlay(leftBar)
    rightBar = deleteOverlay(rightBar)

    if not isEnabled('edge_bars') or index == nil then
        return
    end

    local frame = screen:fullFrame()
    if index > 1 then
        leftBar = newEdgeBar(frame, frame.x)
        leftBar:show()
    end
    if index < count then
        rightBar = newEdgeBar(frame, frame.x + frame.w - EDGE_BAR_WIDTH)
        rightBar:show()
    end
end

local function renderPageDots(index, count, screen)
    if dotsTimer then
        dotsTimer:stop()
        dotsTimer = nil
    end
    dots = deleteOverlay(dots)

    if not isEnabled('page_dots') or index == nil then
        return
    end

    local frame = screen:fullFrame()
    local padding = DOT_GAP
    local width = count * DOT_SIZE + (count - 1) * DOT_GAP + 2 * padding
    local height = DOT_SIZE + 2 * padding
    dots = newOverlay({
        x = frame.x + (frame.w - width) / 2,
        y = frame.y + frame.h - height - DOTS_BOTTOM_MARGIN,
        w = width,
        h = height,
    })
    dots[1] = {
        type = 'rectangle',
        action = 'fill',
        fillColor = { white = 0, alpha = 0.6 },
        roundedRectRadii = { xRadius = height / 2, yRadius = height / 2 },
    }
    for position = 1, count do
        local dot = {
            type = 'circle',
            center = { x = padding + (position - 1) * (DOT_SIZE + DOT_GAP) + DOT_SIZE / 2, y = height / 2 },
            radius = DOT_SIZE / 2,
            strokeColor = COLOR,
            strokeWidth = 1.5,
        }
        if position == index then
            dot.action = 'strokeAndFill'
            dot.fillColor = COLOR
        else
            dot.action = 'stroke'
        end
        dots[#dots + 1] = dot
    end
    dots:show()
    dotsTimer = hs.timer.doAfter(DOTS_VISIBLE_SECONDS, function()
        dots:hide(DOTS_FADE_SECONDS)
    end)
end

-- Redraw both edge bars and flash the dots; `flashDots` false redraws the bars alone.
local function render(flashDots)
    local index, count, screen = focusedPosition()
    renderEdgeBars(index, count, screen)
    if flashDots then
        renderPageDots(index, count, screen)
    end
end

-- Turn an experiment on or off, or report every experiment's state when called with no name.
function showSpacePosition.set(name, enabled)
    if name == nil then
        local lines = {}
        for _, experiment in ipairs(experimentNames()) do
            lines[#lines + 1] = experiment .. ' ' .. (isEnabled(experiment) and 'on' or 'off')
        end
        return table.concat(lines, '\n')
    elseif DEFAULT_ENABLED[name] == nil then
        return 'unknown experiment: ' .. name .. ' (expected one of: ' .. table.concat(experimentNames(), ', ') .. ')'
    end

    hs.settings.set(SETTINGS_PREFIX .. name, enabled)
    render(name == 'page_dots')
    return name .. ' ' .. (enabled and 'on' or 'off')
end

-- Hold the watcher in the global table so garbage collection can't stop it.
showSpacePosition.watcher = hs.spaces.watcher.new(function()
    render(true)
end)
showSpacePosition.watcher:start()
render(false)
