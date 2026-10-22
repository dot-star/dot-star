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
local EDGE_BAR_WIDTH = 7
-- Back the strip with a wide glow that fades out toward the middle, so the edge reads from the corner of the eye.
local EDGE_GLOW_WIDTH = 64
local EDGE_BAR_CANVAS_WIDTH = math.max(EDGE_BAR_WIDTH, EDGE_GLOW_WIDTH)
-- Show a stop sign at the right edge's midpoint on the last Space, where there's no bar to say the swipe ends.
local STOP_SIGN_SIZE = 64
local STOP_SIGN_MARGIN = 8
local STOP_SIGN_BORDER = 3
local STOP_SIGN_FONT_SIZE = 16
local STOP_SIGN_RED = { red = 0.8, green = 0.05, blue = 0.05, alpha = 1 }
-- Paint each Space's pair the next color, so pairs are told apart and a recreated pair shows up as a color change.
local EDGE_BAR_COLORS = {
    { red = 1, green = 0.2, blue = 0.2, alpha = 0.9 },
    { red = 0.2, green = 0.8, blue = 0.2, alpha = 0.9 },
    { red = 0.2, green = 0.5, blue = 1, alpha = 0.9 },
    { red = 0.9, green = 0.2, blue = 0.9, alpha = 0.9 },
    { red = 0.1, green = 0.9, blue = 0.9, alpha = 0.9 },
    { red = 1, green = 0.9, blue = 0.1, alpha = 0.9 },
}
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
-- Stay on the Space the bar was shown on, so it slides in with that Space; macOS blanks an all-Spaces window mid-swipe.
local EDGE_BAR_BEHAVIOR = {
    'fullScreenAuxiliary',
    'stationary',
}

showSpacePosition = {}

-- Map each Space id to its own { left, right } pair of bars.
local edgeBarsBySpace = {}
local edgeBarPairsCreated = 0
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

local function newOverlay(frame, behavior)
    local overlay = hs.canvas.new(frame)
    overlay:level(hs.canvas.windowLevels.overlay)
    overlay:behavior(behavior)
    return overlay
end

local function deleteOverlay(overlay)
    if overlay then
        overlay:delete()
    end
    return nil
end

-- Return the focused Space's 1-based position, the Space count, the screen holding them and the focused Space's id.
local function focusedPosition()
    local focused = hs.spaces.focusedSpace()
    local screen = hs.screen.find(hs.spaces.spaceDisplay(focused)) or hs.screen.mainScreen()
    local spaces = hs.spaces.spacesForScreen(screen) or {}
    for index, space in ipairs(spaces) do
        if space == focused then
            return index, #spaces, screen, focused
        end
    end
    return nil, #spaces, screen, focused
end

local function edgeBarFrame(screenFrame, x)
    return { x = x, y = screenFrame.y, w = EDGE_BAR_CANVAS_WIDTH, h = screenFrame.h }
end

-- Fade the whole canvas rather than each fill, so the strip and glow overlap without a darker seam.
local function newEdgeBar(color)
    local bar = newOverlay({ x = 0, y = 0, w = EDGE_BAR_CANVAS_WIDTH, h = 1 }, EDGE_BAR_BEHAVIOR)
    bar:alpha(color.alpha)
    return bar
end

-- Draw the strip flush against the screen edge on `side` over a glow that starts as solid as the strip and fades out.
local function layoutEdgeBar(bar, side, color, height)
    local opaque = { red = color.red, green = color.green, blue = color.blue, alpha = 1 }
    local clear = { red = color.red, green = color.green, blue = color.blue, alpha = 0 }
    local stripX
    local glowX
    local glowColors
    if side == 'left' then
        stripX = 0
        glowX = 0
        glowColors = { opaque, clear }
    else
        stripX = EDGE_BAR_CANVAS_WIDTH - EDGE_BAR_WIDTH
        glowX = EDGE_BAR_CANVAS_WIDTH - EDGE_GLOW_WIDTH
        glowColors = { clear, opaque }
    end
    bar[1] = {
        type = 'rectangle',
        action = 'fill',
        fillGradient = 'linear',
        fillGradientColors = glowColors,
        fillGradientAngle = 0,
        frame = { x = glowX, y = 0, w = EDGE_GLOW_WIDTH, h = height },
    }
    bar[2] = {
        type = 'rectangle',
        action = 'fill',
        fillColor = opaque,
        frame = { x = stripX, y = 0, w = EDGE_BAR_WIDTH, h = height },
    }
end

-- Return the corners of an octagon with flat top and bottom sides, centered in a square of `STOP_SIGN_SIZE`.
local function octagonCoordinates(radius)
    local center = STOP_SIGN_SIZE / 2
    local coordinates = {}
    for corner = 0, 7 do
        local angle = math.rad(22.5 + 45 * corner)
        coordinates[#coordinates + 1] = { x = center + radius * math.cos(angle), y = center + radius * math.sin(angle) }
    end
    return coordinates
end

local function newStopSign()
    local sign = newOverlay({ x = 0, y = 0, w = STOP_SIGN_SIZE, h = STOP_SIGN_SIZE }, EDGE_BAR_BEHAVIOR)
    local radius = STOP_SIGN_SIZE / 2
    sign[1] = {
        type = 'segments',
        action = 'fill',
        fillColor = { white = 1, alpha = 1 },
        closed = true,
        coordinates = octagonCoordinates(radius),
    }
    sign[2] = {
        type = 'segments',
        action = 'fill',
        fillColor = STOP_SIGN_RED,
        closed = true,
        coordinates = octagonCoordinates(radius - STOP_SIGN_BORDER),
    }
    sign[3] = {
        type = 'text',
        text = hs.styledtext.new('STOP', {
            font = { name = 'Helvetica-Bold', size = STOP_SIGN_FONT_SIZE },
            color = { white = 1, alpha = 1 },
            paragraphStyle = { alignment = 'center' },
        }),
        frame = { x = 0, y = radius - STOP_SIGN_FONT_SIZE * 0.65, w = STOP_SIGN_SIZE, h = STOP_SIGN_FONT_SIZE * 1.4 },
    }
    return sign
end

local function setEdgeBarVisible(bar, visible)
    if visible and not bar:isShowing() then
        bar:show()
    elseif not visible and bar:isShowing() then
        bar:hide()
    end
end

local function deleteEdgeBarPair(pair)
    pair.left:delete()
    pair.right:delete()
    pair.stop:delete()
end

-- Drop the pairs of Spaces that no longer exist.
local function pruneEdgeBars()
    local live = {}
    for _, spaces in pairs(hs.spaces.allSpaces() or {}) do
        for _, space in ipairs(spaces) do
            live[space] = true
        end
    end
    for space, pair in pairs(edgeBarsBySpace) do
        if not live[space] then
            deleteEdgeBarPair(pair)
            edgeBarsBySpace[space] = nil
        end
    end
end

-- Give the focused Space its own pair on first visit; only a reorder of Spaces ever flips a pair's visibility.
local function renderEdgeBars(index, count, screen, focused)
    if not isEnabled('edge_bars') then
        for space, pair in pairs(edgeBarsBySpace) do
            deleteEdgeBarPair(pair)
            edgeBarsBySpace[space] = nil
        end
        return
    elseif index == nil then
        return
    end

    pruneEdgeBars()
    local pair = edgeBarsBySpace[focused]
    if pair == nil then
        edgeBarPairsCreated = edgeBarPairsCreated + 1
        local color = EDGE_BAR_COLORS[(edgeBarPairsCreated - 1) % #EDGE_BAR_COLORS + 1]
        pair = { left = newEdgeBar(color), right = newEdgeBar(color), stop = newStopSign(), color = color }
        edgeBarsBySpace[focused] = pair
    end

    local frame = screen:fullFrame()
    -- Redraw the elements only when the screen height changes, so a plain Space switch never repaints the bars.
    if pair.height ~= frame.h then
        layoutEdgeBar(pair.left, 'left', pair.color, frame.h)
        layoutEdgeBar(pair.right, 'right', pair.color, frame.h)
        pair.height = frame.h
    end
    pair.left:frame(edgeBarFrame(frame, frame.x))
    pair.right:frame(edgeBarFrame(frame, frame.x + frame.w - EDGE_BAR_CANVAS_WIDTH))
    pair.stop:frame({
        x = frame.x + frame.w - STOP_SIGN_SIZE - STOP_SIGN_MARGIN,
        y = frame.y + (frame.h - STOP_SIGN_SIZE) / 2,
        w = STOP_SIGN_SIZE,
        h = STOP_SIGN_SIZE,
    })
    setEdgeBarVisible(pair.left, index > 1)
    setEdgeBarVisible(pair.right, index < count)
    setEdgeBarVisible(pair.stop, index == count)
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
    }, OVERLAY_BEHAVIOR)
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
    local index, count, screen, focused = focusedPosition()
    renderEdgeBars(index, count, screen, focused)
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
