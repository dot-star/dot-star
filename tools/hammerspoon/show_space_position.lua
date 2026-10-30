-- Show where the focused Space sits in the swipe order, as experiments toggled independently:
--   Keep a strip on a full-screen Space's right edge while another Space lies beyond it, a bumper once none does (edge_bars).
--   Add a strip on the left edge of the first full-screen Space, where swiping left leaves the full-screen apps (edge_bars).
--   Add a thin band along the bottom edge of every full-screen Space in that Space's strip color (bottom_bar, needs edge_bars).
--   Paint each Space's bars the next color in a cycle rather than one shared color (cycle_colors, needs edge_bars).
--   Add a row of dots in the title bar's upper-right corner of every full-screen Space, the focused Space filled (page_dots, needs edge_bars).
--   Show the dark pill behind the dots, to check where their canvas sits (page_dots_pill, needs page_dots).
-- Toggle from the shell with `space_position_experiment`; each flag persists across reloads.
-- Re-place the bars after a display change or a wake, which move the screens without switching Spaces.
-- Redraw a beat after each Space change too, so bars of a full-screen Space that just closed get deleted.

-- Apply each experiment's default until it's toggled; a saved setting wins after that.
local DEFAULT_ENABLED = {
    bottom_bar = true,
    cycle_colors = false,
    edge_bars = true,
    page_dots = true,
    page_dots_pill = false,
}
local SETTINGS_PREFIX = 'show_space_position.'
local EDGE_BAR_WIDTH = 7
-- Back the right strip with a wide glow that fades out toward the middle, so the edge reads from the corner of the eye.
local EDGE_GLOW_WIDTH = 64
local EDGE_BAR_CANVAS_WIDTH = math.max(EDGE_BAR_WIDTH, EDGE_GLOW_WIDTH)
-- Keep the bottom band as thin as the edge strips with no glow, so it hints at the Space's color without eating into the terminal.
local BOTTOM_BAR_HEIGHT = EDGE_BAR_WIDTH
-- Block the right edge's midpoint with a bumper on the last Space, where there's no bar to say the swipe goes on.
local BUMPER_DEPTH = 28
local BUMPER_HEIGHT = 140
-- Draw the bumper more opaque than the bars, so its hard edge holds up against glare outdoors.
local BUMPER_ALPHA = 1
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
local DOT_SIZE = 20
local DOT_GAP = 14
-- Fill the native title bar Ghostty keeps for its tabs with the dots' pill.
local TITLE_BAR_HEIGHT = require('ghostty_title_bar').HEIGHT
-- Pad the pill's ends as much as its top and bottom, so the rounded ends hug the first and last dots evenly.
local DOTS_PADDING = (TITLE_BAR_HEIGHT - DOT_SIZE) / 2
-- Wait out macOS rearranging Spaces after a display change, a wake or a Space closing, which often runs on past the event reporting it.
local SETTLE_SECONDS = 1

local pinCanvasesToSpaces = require('pin_canvases_to_spaces')

local EDGE_BAR_BEHAVIOR = pinCanvasesToSpaces.BEHAVIOR

showSpacePosition = {}

-- Map each Space id to its own { left, right, bottom, bumper, dots } set of bars, bumper and dots.
local edgeBarsBySpace = {}
local edgeBarPairsCreated = 0
local settleTimer = nil

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

-- Fill the whole canvas with a solid block flush against the edge.
local function newBumper(color)
    local bumper = newOverlay({ x = 0, y = 0, w = BUMPER_DEPTH, h = BUMPER_HEIGHT }, EDGE_BAR_BEHAVIOR)
    bumper:alpha(BUMPER_ALPHA)
    bumper[1] = {
        type = 'rectangle',
        action = 'fill',
        fillColor = { red = color.red, green = color.green, blue = color.blue, alpha = 1 },
    }
    return bumper
end

local function newPageDots()
    return newOverlay({ x = 0, y = 0, w = 1, h = TITLE_BAR_HEIGHT }, EDGE_BAR_BEHAVIOR)
end

local function pageDotsWidth(count)
    return count * DOT_SIZE + (count - 1) * DOT_GAP + 2 * DOTS_PADDING
end

-- Draw one dot per Space in `color` on a pill, filling the dot at `index`; keep the pill clear unless `pillVisible`, which shows where the canvas sits.
local function layoutPageDots(dots, index, count, color, pillVisible)
    local height = TITLE_BAR_HEIGHT
    local pillAlpha
    if pillVisible then
        pillAlpha = 0.6
    else
        pillAlpha = 0
    end
    local elements = {
        {
            type = 'rectangle',
            action = 'fill',
            fillColor = { white = 0, alpha = pillAlpha },
            roundedRectRadii = { xRadius = height / 2, yRadius = height / 2 },
        },
    }
    for position = 1, count do
        local dot = {
            type = 'circle',
            center = { x = DOTS_PADDING + (position - 1) * (DOT_SIZE + DOT_GAP) + DOT_SIZE / 2, y = height / 2 },
            radius = DOT_SIZE / 2,
            strokeColor = color,
            strokeWidth = 1.5,
        }
        if position == index then
            dot.action = 'strokeAndFill'
            dot.fillColor = color
        else
            dot.action = 'stroke'
        end
        elements[#elements + 1] = dot
    end
    dots:replaceElements(elements)
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

-- Return whether the focused Space gets the bumper; desktops stay clear, the same as for the right bar.
local function showsBumper(focused, index, count)
    if hs.spaces.spaceType(focused) ~= 'fullscreen' then
        return false
    elseif index ~= count then
        return false
    end
    return true
end

-- Return whether the focused Space gets the dots; desktops stay clear, the same as for the right bar.
local function showsPageDots(focused)
    if not isEnabled('page_dots') then
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
    pair.dots:delete()
end

-- Drop the pairs of Spaces that no longer exist.
local function pruneEdgeBars()
    pinCanvasesToSpaces.pruneClosedSpaces(edgeBarsBySpace, deleteEdgeBarPair)
end

-- Fit a pair's bars, bumper and dots flush to the edges of `screen`, for the Space at `index` of `count` on it.
local function placeEdgeBars(pair, index, count, screen)
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
    -- Redraw the dots only when the Space moved, the count changed or the pill was toggled, the same as the bars' height check.
    local pillVisible = isEnabled('page_dots_pill')
    if pair.dotsIndex ~= index or pair.dotsCount ~= count or pair.dotsPill ~= pillVisible then
        layoutPageDots(pair.dots, index, count, pair.color, pillVisible)
        pair.dotsIndex = index
        pair.dotsCount = count
        pair.dotsPill = pillVisible
    end
    local dotsWidth = pageDotsWidth(count)
    -- Sit the dots just inside the right glow, so the strip doesn't wash them out.
    pair.dots:frame({
        x = frame.x + frame.w - EDGE_BAR_CANVAS_WIDTH - dotsWidth,
        y = frame.y,
        w = dotsWidth,
        h = TITLE_BAR_HEIGHT,
    })
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
            dots = newPageDots(),
            color = color,
            cycleColor = cycleColor,
        }
        edgeBarsBySpace[focused] = pair
    end

    placeEdgeBars(pair, index, count, screen)
    local rightVisible = showsRightBar(focused, index, count)
    setEdgeBarVisible(pair.left, startsFullScreenRun(hs.spaces.spacesForScreen(screen) or {}, index))
    setEdgeBarVisible(pair.right, rightVisible)
    setEdgeBarVisible(pair.bottom, showsBottomBar(focused))
    setEdgeBarVisible(pair.bumper, showsBumper(focused, index, count))
    setEdgeBarVisible(pair.dots, showsPageDots(focused))
end

local function render()
    local index, count, screen, focused = focusedPosition()
    renderEdgeBars(index, count, screen, focused)
end

-- Move every Space's pair onto its screen's current edges; leave visibility to the next visit, since showing an off-Space canvas can pull it onto this one.
local function placeEveryEdgeBarSet()
    for screenId, spaces in pairs(hs.spaces.allSpaces() or {}) do
        local screen = hs.screen.find(screenId)
        if screen then
            for index, space in ipairs(spaces) do
                local pair = edgeBarsBySpace[space]
                if pair then
                    placeEdgeBars(pair, index, #spaces, screen)
                end
            end
        end
    end
end

-- Redraw the bars once macOS settles; restart the wait on each event, so a burst of them redraws once.
local function renderAfterSettle()
    if settleTimer then
        settleTimer:stop()
    end
    settleTimer = hs.timer.doAfter(SETTLE_SECONDS, function()
        settleTimer = nil
        render()
        placeEveryEdgeBarSet()
    end)
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
    render()
    return name .. ' ' .. (enabled and 'on' or 'off')
end

-- Hold each watcher in the global table so garbage collection can't stop it.
showSpacePosition.watcher = hs.spaces.watcher.new(function()
    render()
    -- Redraw again once a closed full-screen Space is gone for good, so its bars don't linger on the desktop it fell back to.
    renderAfterSettle()
end)
showSpacePosition.watcher:start()
showSpacePosition.screenWatcher = hs.screen.watcher.new(function()
    renderAfterSettle()
end)
showSpacePosition.screenWatcher:start()
showSpacePosition.wakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        renderAfterSettle()
    elseif event == hs.caffeinate.watcher.screensDidWake then
        renderAfterSettle()
    end
end)
showSpacePosition.wakeWatcher:start()
render()
