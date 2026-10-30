-- Demo candidate treatments for Claude session-state page dots, drawn at the real dot size on the real title bar height.
-- Show or hide the panel, reloading this file first:
--   hs -c "package.loaded['show_space_position_demo'] = nil; require('show_space_position_demo'); return showSpacePositionDemo.toggle()"
-- Close it with a click on the panel or Escape.

local DOT_SIZE = 20
local DOT_GAP = 14
local TITLE_BAR_HEIGHT = require('ghostty_title_bar').HEIGHT
local DOTS_PADDING = (TITLE_BAR_HEIGHT - DOT_SIZE) / 2
-- Thicken the ring past the page dots' hairline stroke, so its color reads at a glance.
local RING_WIDTH = 3.5
local RING_RADIUS = DOT_SIZE / 2 - RING_WIDTH / 2
-- Keep the orbit slow, so a long run of tool calls doesn't tug at the eye.
local ORBIT_SECONDS = 2
local FRAMES_PER_SECOND = 30

local ROW_HEIGHT = TITLE_BAR_HEIGHT + 8
local HEADING_HEIGHT = 32
local PANEL_PADDING = 24
local LABEL_WIDTH = 130
local DESCRIPTION_WIDTH = 250
local COLUMN_GAP = 40
local DOT_COUNT = 5
local PILL_WIDTH = DOT_COUNT * DOT_SIZE + (DOT_COUNT - 1) * DOT_GAP + 2 * DOTS_PADDING
local COLUMN_WIDTH = LABEL_WIDTH + PILL_WIDTH + 20 + DESCRIPTION_WIDTH

local FOCUS_MARK_COLOR = { white = 1, alpha = 1 }

-- Color each state like a traffic light: amber busy, red decision, green ready.
local STATE_COLORS = {
    busy = { red = 1, green = 0.69, blue = 0, alpha = 1 },
    decision = { red = 1, green = 0.23, blue = 0.19, alpha = 1 },
    ready = { red = 0.2, green = 0.78, blue = 0.35, alpha = 1 },
    none = { white = 0.55, alpha = 1 },
}

-- Draw every row with these treatments, except the one each row is there to vary.
local BASE_VARIANT = {
    decision = 'heartbeat',
    focus = 'underline',
    focusOn = 1,
    none = 'thin',
    ready = 'check_ping',
}

local COLUMNS = {
    {
        { heading = 'Default set, by the Space you\'re on' },
        { label = 'Busy', description = 'orbit with a white underline', focusOn = 1 },
        { label = 'Decision', description = 'heartbeat with a white underline', focusOn = 3 },
        { label = 'Ready', description = 'underlined check; pings on arrival', focusOn = 4 },
        { label = 'No session', description = 'gray ring with a white underline', focusOn = 5 },
    },
    {
        { heading = 'Alternative settings' },
        { label = 'Blink', description = 'decision ring blinks off and on', decision = 'blink' },
        { label = 'Nudge', description = 'decision dot hops three times, then rests', decision = 'nudge' },
        { label = 'Flash', description = 'decision center floods with color and drains', decision = 'flash' },
        { label = 'Center', description = 'white center dot; a ready check turns white', focus = 'center' },
    },
}

showSpacePositionDemo = {}

local panel = nil
local frameTimer = nil
local escapeHotkey = nil

local function withAlpha(color, alpha)
    local copy = {}
    for key, value in pairs(color) do
        copy[key] = value
    end
    copy.alpha = alpha
    return copy
end

-- Return how far through a cycle of `period` seconds the clock is, from 0 to 1.
local function phaseOf(seconds, period)
    return (seconds % period) / period
end

-- Rise from 0 to 1 and back once per cycle, easing at both ends.
local function wave(phase)
    return (1 - math.cos(2 * math.pi * phase)) / 2
end

-- Spike twice early in the cycle and rest for the remainder, like a heartbeat.
local function heartbeat(phase)
    local beatLength = 0.12
    if phase < beatLength then
        return math.sin(math.pi * phase / beatLength)
    elseif phase < 0.2 then
        return 0
    elseif phase < 0.2 + beatLength then
        return math.sin(math.pi * (phase - 0.2) / beatLength)
    end
    return 0
end

-- Hop three times early in the cycle and rest for the remainder, from 0 (resting) to 1 (top of a hop).
local function nudge(phase)
    if phase < 0.45 then
        return math.abs(math.sin(3 * math.pi * phase / 0.45))
    end
    return 0
end

local function ring(center, radius, color, strokeWidth, filled)
    local element = {
        type = 'circle',
        center = center,
        radius = radius,
        strokeColor = color,
        strokeWidth = strokeWidth,
    }
    if filled then
        element.action = 'strokeAndFill'
        element.fillColor = color
    else
        element.action = 'stroke'
    end
    return element
end

local function disc(center, radius, color)
    return { type = 'circle', action = 'fill', center = center, radius = radius, fillColor = color }
end

local function line(points, color, width)
    return {
        type = 'segments',
        action = 'stroke',
        closed = false,
        coordinates = points,
        strokeColor = color,
        strokeWidth = width,
        strokeCapStyle = 'round',
        strokeJoinStyle = 'round',
    }
end

local function arc(center, radius, color, startAngle, endAngle)
    return {
        type = 'arc',
        action = 'stroke',
        center = center,
        radius = radius,
        startAngle = startAngle,
        endAngle = endAngle,
        arcRadii = false,
        strokeColor = color,
        strokeWidth = RING_WIDTH,
        strokeCapStyle = 'round',
    }
end

local function busyElements(center, color, filled, seconds)
    local start = phaseOf(seconds, ORBIT_SECONDS) * 360
    return {
        ring(center, RING_RADIUS, withAlpha(color, 0.3), RING_WIDTH, filled),
        arc(center, RING_RADIUS, color, start, start + 100),
    }
end

local function decisionElements(variant, center, color, filled, seconds)
    if variant == 'steady' then
        return { ring(center, RING_RADIUS, color, RING_WIDTH, filled) }
    elseif variant == 'blink' then
        local alpha = 1
        if phaseOf(seconds, 1.2) > 0.6 then
            alpha = 0.15
        end
        return { ring(center, RING_RADIUS, withAlpha(color, alpha), RING_WIDTH, filled) }
    elseif variant == 'double' then
        return {
            ring(center, RING_RADIUS - 1, color, RING_WIDTH - 1, filled),
            ring(center, RING_RADIUS + 4, color, 1.5, false),
        }
    elseif variant == 'bang' then
        return {
            ring(center, RING_RADIUS, color, RING_WIDTH, filled),
            line({ { x = center.x, y = center.y - 4.5 }, { x = center.x, y = center.y + 0.5 } }, color, 2.5),
            disc({ x = center.x, y = center.y + 4 }, 1.4, color),
        }
    elseif variant == 'nudge' then
        local lift = 3 * nudge(phaseOf(seconds, 2.4))
        return { ring({ x = center.x, y = center.y - lift }, RING_RADIUS, color, RING_WIDTH, filled) }
    elseif variant == 'flash' then
        return {
            disc(center, RING_RADIUS, withAlpha(color, 0.7 * wave(phaseOf(seconds, 1.5)))),
            ring(center, RING_RADIUS, color, RING_WIDTH, filled),
        }
    elseif variant == 'heartbeat' then
        local beat = heartbeat(phaseOf(seconds, 1.4))
        return { ring(center, RING_RADIUS + beat, withAlpha(color, 0.45 + 0.55 * beat), RING_WIDTH + beat, filled) }
    end
    error('unknown decision variant: ' .. variant)
end

local function checkElements(center, color, filled)
    return {
        ring(center, RING_RADIUS, color, RING_WIDTH, filled),
        line({
            { x = center.x - 3.5, y = center.y + 0.5 },
            { x = center.x - 1, y = center.y + 3 },
            { x = center.x + 3.5, y = center.y - 2.5 },
        }, color, 2),
    }
end

-- Add a ripple to `elements` early in each cycle, standing in for the one a dot sends out on turning ready.
local function withPing(elements, center, color, seconds)
    local phase = phaseOf(seconds, 4)
    if phase < 0.25 then
        local spread = phase / 0.25
        elements[#elements + 1] = ring(center, RING_RADIUS + spread * 8, withAlpha(color, 0.8 * (1 - spread)), 2, false)
    end
    return elements
end

local function readyElements(variant, center, color, filled, seconds)
    if variant == 'check' then
        return checkElements(center, color, filled)
    elseif variant == 'check_ping' then
        return withPing(checkElements(center, color, filled), center, color, seconds)
    end
    error('unknown ready variant: ' .. variant)
end

local function noneElements(variant, center, color, filled)
    if variant == 'thin' then
        return { ring(center, DOT_SIZE / 2 - 0.75, color, 1.5, filled) }
    elseif variant == 'speck' then
        return { disc(center, 3, color) }
    elseif variant == 'faint' then
        return { ring(center, DOT_SIZE / 2 - 0.75, withAlpha(color, 0.35), 1.5, filled) }
    end
    error('unknown none variant: ' .. variant)
end

local function stateElements(state, variant, center, filled, seconds)
    if state == 'busy' then
        return busyElements(center, STATE_COLORS.busy, filled, seconds)
    elseif state == 'decision' then
        return decisionElements(variant.decision, center, STATE_COLORS.decision, filled, seconds)
    elseif state == 'ready' then
        return readyElements(variant.ready, center, STATE_COLORS.ready, filled, seconds)
    elseif state == 'none' then
        return noneElements(variant.none, center, STATE_COLORS.none, filled)
    end
    error('unknown state: ' .. state)
end

-- Draw a focused dot, marking it the way `focus` says on top of its state.
local function focusedElements(state, variant, center, seconds)
    if variant.focus == 'fill' then
        return stateElements(state, variant, center, true, seconds)
    end

    local elements = stateElements(state, variant, center, false, seconds)
    if variant.focus == 'center' then
        local whitened = false
        -- Whiten a mark already inside the ring rather than stacking the dot on it, so the check stays legible.
        for _, element in ipairs(elements) do
            if element.type == 'segments' then
                element.strokeColor = FOCUS_MARK_COLOR
                whitened = true
            end
        end
        if not whitened then
            elements[#elements + 1] = disc(center, 3, FOCUS_MARK_COLOR)
        end
    elseif variant.focus == 'underline' then
        local y = center.y + DOT_SIZE / 2 + 5
        elements[#elements + 1] = line({ { x = center.x - 6, y = y }, { x = center.x + 6, y = y } }, FOCUS_MARK_COLOR, 2.5)
    elseif variant.focus == 'grow' then
        for _, element in ipairs(elements) do
            if element.radius then
                element.radius = element.radius + 3
            end
        end
    else
        error('unknown focus variant: ' .. variant.focus)
    end
    return elements
end

-- Draw one title-bar pill at `origin`: two busy, decision, ready, no session, marking the dot at `focusOn` as the focused Space.
local function pillElements(origin, variant, seconds)
    local elements = {
        {
            type = 'rectangle',
            action = 'fill',
            fillColor = { white = 0, alpha = 1 },
            frame = { x = origin.x, y = origin.y, w = PILL_WIDTH, h = TITLE_BAR_HEIGHT },
            roundedRectRadii = { xRadius = TITLE_BAR_HEIGHT / 2, yRadius = TITLE_BAR_HEIGHT / 2 },
        },
    }
    local states = { 'busy', 'busy', 'decision', 'ready', 'none' }
    for position, state in ipairs(states) do
        local center = {
            x = origin.x + DOTS_PADDING + (position - 1) * (DOT_SIZE + DOT_GAP) + DOT_SIZE / 2,
            y = origin.y + TITLE_BAR_HEIGHT / 2,
        }
        local dotElements
        if position == variant.focusOn then
            dotElements = focusedElements(state, variant, center, seconds)
        else
            dotElements = stateElements(state, variant, center, false, seconds)
        end
        for _, element in ipairs(dotElements) do
            elements[#elements + 1] = element
        end
    end
    return elements
end

-- Return the base treatments with the row's own choice swapped in.
local function rowVariant(row)
    local variant = {}
    for key, value in pairs(BASE_VARIANT) do
        variant[key] = row[key] or value
    end
    return variant
end

local function text(value, frame, size, white)
    return {
        type = 'text',
        text = value,
        frame = frame,
        textSize = size,
        textColor = { white = white, alpha = 1 },
        textFont = '.AppleSystemUIFont',
    }
end

local function columnHeight(column)
    local height = 0
    for _, row in ipairs(column) do
        if row.heading then
            height = height + HEADING_HEIGHT
        else
            height = height + ROW_HEIGHT
        end
    end
    return height
end

local function panelSize()
    local tallest = 0
    for _, column in ipairs(COLUMNS) do
        tallest = math.max(tallest, columnHeight(column))
    end
    return {
        w = 2 * PANEL_PADDING + #COLUMNS * COLUMN_WIDTH + (#COLUMNS - 1) * COLUMN_GAP,
        h = 2 * PANEL_PADDING + 40 + tallest + 24,
    }
end

local function draw()
    local seconds = hs.timer.secondsSinceEpoch()
    local size = panelSize()
    local elements = {
        {
            type = 'rectangle',
            action = 'fill',
            fillColor = { white = 0.13, alpha = 1 },
            roundedRectRadii = { xRadius = 14, yRadius = 14 },
        },
        text(
            'Dots, left to right: busy, busy, needs a decision, ready, no session. The marked dot is the Space you\'re on.',
            { x = PANEL_PADDING, y = PANEL_PADDING, w = size.w - 2 * PANEL_PADDING, h = 20 },
            13,
            0.75
        ),
    }
    for columnIndex, column in ipairs(COLUMNS) do
        local x = PANEL_PADDING + (columnIndex - 1) * (COLUMN_WIDTH + COLUMN_GAP)
        local pillX = x + LABEL_WIDTH
        local y = PANEL_PADDING + 40
        for _, row in ipairs(column) do
            if row.heading then
                elements[#elements + 1] = text(row.heading, { x = x, y = y + 6, w = COLUMN_WIDTH, h = 22 }, 15, 0.95)
                y = y + HEADING_HEIGHT
            else
                local textY = y + (TITLE_BAR_HEIGHT - 18) / 2
                elements[#elements + 1] = text(row.label, { x = x, y = textY, w = LABEL_WIDTH, h = 20 }, 14, 0.9)
                for _, element in ipairs(pillElements({ x = pillX, y = y }, rowVariant(row), seconds)) do
                    elements[#elements + 1] = element
                end
                elements[#elements + 1] = text(
                    row.description,
                    { x = pillX + PILL_WIDTH + 20, y = textY, w = DESCRIPTION_WIDTH, h = 20 },
                    12,
                    0.6
                )
                y = y + ROW_HEIGHT
            end
        end
    end
    elements[#elements + 1] = text(
        'Click or press Escape to close',
        { x = PANEL_PADDING, y = size.h - PANEL_PADDING - 16, w = 400, h = 18 },
        11,
        0.5
    )
    panel:replaceElements(elements)
end

local function hide()
    if frameTimer then
        frameTimer:stop()
        frameTimer = nil
    end
    if escapeHotkey then
        escapeHotkey:delete()
        escapeHotkey = nil
    end
    if panel then
        panel:delete()
        panel = nil
    end
end

local function show()
    local screenFrame = hs.screen.mainScreen():frame()
    local size = panelSize()
    panel = hs.canvas.new({
        x = screenFrame.x + (screenFrame.w - size.w) / 2,
        y = screenFrame.y + (screenFrame.h - size.h) / 2,
        w = size.w,
        h = size.h,
    })
    panel:level(hs.canvas.windowLevels.overlay)
    panel:canvasMouseEvents(true)
    panel:mouseCallback(function()
        hide()
    end)
    draw()
    panel:show()
    frameTimer = hs.timer.doEvery(1 / FRAMES_PER_SECOND, draw)
    escapeHotkey = hs.hotkey.bind({}, 'escape', hide)
end

-- Show the panel, or hide it when it's already up.
function showSpacePositionDemo.toggle()
    if panel then
        hide()
        return 'hidden'
    end
    show()
    return 'shown'
end

-- Hide a panel left up by the copy of this file a reload replaces, so its timer stops drawing.
if previousShowSpacePositionDemoHide then
    previousShowSpacePositionDemoHide()
end
previousShowSpacePositionDemoHide = hide

return showSpacePositionDemo
