-- Show where the focused Space sits in the swipe order, as experiments toggled independently:
--   Keep a strip on a full-screen Space's right edge while another Space lies beyond it, a bumper once none does (edge_bars).
--   Add a strip on the left edge of the first full-screen Space, where swiping left leaves the full-screen apps (edge_bars).
--   Add a thin band along the bottom edge of every full-screen Space in that Space's strip color (bottom_bar, needs edge_bars).
--   Paint each Space's bars the next color in a cycle rather than one shared color (cycle_colors, needs edge_bars).
--   Flash a row of dots after each switch, the focused Space filled (page_dots).
-- Toggle from the shell with `space_position_experiment`; each flag persists across reloads.

-- Apply each experiment's default until it's toggled; a saved setting wins after that.
local DEFAULT_ENABLED = {
    bottom_bar = true,
    cycle_colors = false,
    edge_bars = true,
    page_dots = false,
}
local SETTINGS_PREFIX = 'show_space_position.'
local COLOR = { red = 1, green = 0.6, blue = 0.1, alpha = 0.9 }
local EDGE_BAR_WIDTH = 7
-- Back the right strip with a wide glow that fades out toward the middle, so the edge reads from the corner of the eye.
local EDGE_GLOW_WIDTH = 64
local EDGE_BAR_CANVAS_WIDTH = math.max(EDGE_BAR_WIDTH, EDGE_GLOW_WIDTH)
-- Keep the bottom band thin with no glow, so it hints at the Space's color without eating into the terminal.
local BOTTOM_BAR_HEIGHT = 10
-- Bulge a soft bumper out of the right edge's midpoint on the last Space, where there's no bar to say the swipe goes on.
local BUMPER_DEPTH = 28
local BUMPER_HEIGHT = 140
-- Paint each Space's pair the next color, so pairs are told apart and a recreated pair shows up as a color change.
local EDGE_BAR_COLORS = {
    { red = 1, green = 0.2, blue = 0.2, alpha = 0.9 },
    { red = 0.2, green = 0.8, blue = 0.2, alpha = 0.9 },
    { red = 0.2, green = 0.5, blue = 1, alpha = 0.9 },
    { red = 0.9, green = 0.2, blue = 0.9, alpha = 0.9 },
    { red = 0.1, green = 0.9, blue = 0.9, alpha = 0.9 },
    { red = 1, green = 0.9, blue = 0.1, alpha = 0.9 },
}
-- Paint every Space's bars this one color while cycle_colors is off, so the bars read as a single landmark.
local UNIFORM_EDGE_BAR_COLOR = { red = 1, green = 0.9, blue = 0.1, alpha = 0.9 }
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

-- Map each Space id to its own { left, right, bottom, bumper } set of bars and bumper.
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

-- Fill the whole canvas, so resizing the band to a new screen width needs no redraw.
local function newBottomBar(color)
    local bar = newOverlay({ x = 0, y = 0, w = 1, h = BOTTOM_BAR_HEIGHT }, EDGE_BAR_BEHAVIOR)
    bar:alpha(color.alpha)
    bar[1] = {
        type = 'rectangle',
        action = 'fill',
        fillColor = { red = color.red, green = color.green, blue = color.blue, alpha = 1 },
    }
    return bar
end

-- Draw the strip flush against the screen edge on `side`, the right one over a glow that starts as solid as the strip and fades out.
local function layoutEdgeBar(bar, side, color, height)
    local opaque = { red = color.red, green = color.green, blue = color.blue, alpha = 1 }
    if side == 'left' then
        bar[1] = {
            type = 'rectangle',
            action = 'fill',
            fillColor = opaque,
            frame = { x = 0, y = 0, w = EDGE_BAR_WIDTH, h = height },
        }
        return
    end

    local clear = { red = color.red, green = color.green, blue = color.blue, alpha = 0 }
    bar[1] = {
        type = 'rectangle',
        action = 'fill',
        fillGradient = 'linear',
        fillGradientColors = { clear, opaque },
        fillGradientAngle = 0,
        frame = { x = EDGE_BAR_CANVAS_WIDTH - EDGE_GLOW_WIDTH, y = 0, w = EDGE_GLOW_WIDTH, h = height },
    }
    bar[2] = {
        type = 'rectangle',
        action = 'fill',
        fillColor = opaque,
        frame = { x = EDGE_BAR_CANVAS_WIDTH - EDGE_BAR_WIDTH, y = 0, w = EDGE_BAR_WIDTH, h = height },
    }
end

-- Draw a full oval twice the canvas width, so the canvas clips it to the half that bulges in from the edge.
local function newBumper(color)
    local bumper = newOverlay({ x = 0, y = 0, w = BUMPER_DEPTH, h = BUMPER_HEIGHT }, EDGE_BAR_BEHAVIOR)
    bumper:alpha(color.alpha)
    bumper[1] = {
        type = 'oval',
        action = 'fill',
        fillColor = { red = color.red, green = color.green, blue = color.blue, alpha = 1 },
        frame = { x = 0, y = 0, w = 2 * BUMPER_DEPTH, h = BUMPER_HEIGHT },
    }
    return bumper
end

local function setEdgeBarVisible(bar, visible)
    if visible and not bar:isShowing() then
        bar:show()
    elseif not visible and bar:isShowing() then
        bar:hide()
    end
end

-- Return whether the Space at `index` opens a run of full-screen Spaces, so swiping left from it leaves them.
local function startsFullScreenRun(spaces, index)
    if index == 1 then
        return false
    elseif hs.spaces.spaceType(spaces[index]) ~= 'fullscreen' then
        return false
    elseif hs.spaces.spaceType(spaces[index - 1]) == 'fullscreen' then
        return false
    end
    return true
end

-- Return whether the focused Space gets a right bar; desktops stay clear so bars mark only the full-screen apps.
local function showsRightBar(focused, index, count)
    if hs.spaces.spaceType(focused) ~= 'fullscreen' then
        return false
    elseif index == count then
        return false
    end
    return true
end

-- Return whether the focused Space gets a bottom band; desktops stay clear, the same as for the right bar.
local function showsBottomBar(focused)
    if not isEnabled('bottom_bar') then
        return false
    elseif hs.spaces.spaceType(focused) ~= 'fullscreen' then
        return false
    end
    return true
end

-- Return the color a pair paints: its own from the cycle, or the shared one while cycle_colors is off.
local function edgeBarColor(cycleColor)
    if isEnabled('cycle_colors') then
        return cycleColor
    end
    return UNIFORM_EDGE_BAR_COLOR
end

local function deleteEdgeBarPair(pair)
    pair.left:delete()
    pair.right:delete()
    pair.bottom:delete()
    pair.bumper:delete()
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
    local cycleColor
    if pair == nil then
        edgeBarPairsCreated = edgeBarPairsCreated + 1
        cycleColor = EDGE_BAR_COLORS[(edgeBarPairsCreated - 1) % #EDGE_BAR_COLORS + 1]
    else
        cycleColor = pair.cycleColor
    end
    local color = edgeBarColor(cycleColor)
    -- Rebuild the pair when a cycle_colors toggle changed its color, keeping its cycle color for when cycling returns.
    if pair ~= nil and pair.color ~= color then
        deleteEdgeBarPair(pair)
        pair = nil
    end

    if pair == nil then
        pair = {
            left = newEdgeBar(color),
            right = newEdgeBar(color),
            bottom = newBottomBar(color),
            bumper = newBumper(color),
            color = color,
            cycleColor = cycleColor,
        }
        edgeBarsBySpace[focused] = pair
    end

    local frame = screen:fullFrame()
    -- Start the first Space's bar below the menu bar, so it doesn't cover the clock; `frame()` drops the menu bar where this screen has one.
    local barTop
    if index == 1 then
        barTop = screen:frame().y
    else
        barTop = frame.y
    end
    local barFrame = { x = frame.x, y = barTop, w = frame.w, h = frame.y + frame.h - barTop }
    -- Redraw the elements only when the bar height changes, so a plain Space switch never repaints the bars.
    if pair.height ~= barFrame.h then
        layoutEdgeBar(pair.left, 'left', pair.color, barFrame.h)
        layoutEdgeBar(pair.right, 'right', pair.color, barFrame.h)
        pair.height = barFrame.h
    end
    pair.left:frame(edgeBarFrame(barFrame, barFrame.x))
    pair.right:frame(edgeBarFrame(barFrame, barFrame.x + barFrame.w - EDGE_BAR_CANVAS_WIDTH))
    pair.bottom:frame({ x = frame.x, y = frame.y + frame.h - BOTTOM_BAR_HEIGHT, w = frame.w, h = BOTTOM_BAR_HEIGHT })
    pair.bumper:frame({
        x = frame.x + frame.w - BUMPER_DEPTH,
        y = frame.y + (frame.h - BUMPER_HEIGHT) / 2,
        w = BUMPER_DEPTH,
        h = BUMPER_HEIGHT,
    })
    local rightVisible = showsRightBar(focused, index, count)
    setEdgeBarVisible(pair.left, startsFullScreenRun(hs.spaces.spacesForScreen(screen) or {}, index))
    setEdgeBarVisible(pair.right, rightVisible)
    setEdgeBarVisible(pair.bottom, showsBottomBar(focused))
    setEdgeBarVisible(pair.bumper, index == count)
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
