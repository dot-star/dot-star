-- Show where the focused Space sits in the swipe order, as experiments toggled independently:
--   Keep a strip on a full-screen Space's right edge while another Space lies beyond it, a bumper once none does (edge_bars).
--   Add a strip on the left edge of the first full-screen Space, where swiping left leaves the full-screen apps (edge_bars).
--   Add a thin band along the bottom edge of every full-screen Space in that Space's strip color (bottom_bar, needs edge_bars).
--   Paint each Space's bars the next color in a cycle rather than one shared color (cycle_colors, needs edge_bars).
--   Add a row of dots in the title bar's upper-right corner of every full-screen Space, the focused Space filled (page_dots, needs edge_bars).
--   Show the dark pill behind the dots, to check where their canvas sits (page_dots_pill, needs page_dots).
--   Show on each dot the state of the Claude session whose window sits on that Space (session_state, needs page_dots).
--   Switch to a Space whose session turned ready, once you've been idle a while (follow_ready, needs session_state).
--   Show a countdown left of the dots to when follow_ready arms, for debugging (follow_countdown, needs follow_ready).
-- Toggle from the shell with `space_position_experiment`; each flag persists across reloads.
-- Pick the session dots' decision style and focus marker the same way; each style persists too.
-- Set how long you must be idle before follow_ready switches Spaces the same way, with follow_idle_seconds.
-- Re-place the bars after a display change or a wake, which move the screens without switching Spaces.
-- Redraw a beat after each Space change too, so bars of a full-screen Space that just closed get deleted.

-- Apply each experiment's default until it's toggled; a saved setting wins after that.
local DEFAULT_ENABLED = {
    bottom_bar = true,
    cycle_colors = false,
    edge_bars = true,
    follow_countdown = true,
    follow_ready = true,
    page_dots = true,
    page_dots_pill = false,
    session_state = true,
}
-- Apply each style's default until it's set; a saved choice wins after that.
local DEFAULT_STYLES = {
    decision_style = 'heartbeat',
    focus_marker = 'underline',
}
local STYLE_CHOICES = {
    decision_style = { 'blink', 'flash', 'heartbeat', 'nudge' },
    focus_marker = { 'center', 'underline' },
}
-- Apply each number's default until it's set; a saved value wins after that.
local DEFAULT_NUMBERS = {
    -- Wait out a pause for thought, so a session finishing while you're mid-task never pulls you off it.
    follow_idle_seconds = 10,
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
-- Leave room for the countdown's longest text, so it never clips against the dots.
local COUNTDOWN_WIDTH = 60
local COUNTDOWN_TEXT_SIZE = 22
-- Heat the countdown from calm white to red as follow_ready nears arming.
local COUNTDOWN_CALM_COLOR = { red = 1, green = 1, blue = 1, alpha = 1 }
local COUNTDOWN_ARMED_COLOR = { red = 1, green = 0.15, blue = 0.1, alpha = 1 }
-- Read each Claude session's state word and window record from where `announce_window_state.py` writes them.
local SESSION_STATE_DIR = '/tmp/claude-state-hook/'
-- Thicken a session dot's ring past the plain dots' hairline stroke, so its color reads at a glance.
local RING_WIDTH = 3.5
local RING_RADIUS = DOT_SIZE / 2 - RING_WIDTH / 2
-- Keep the orbit slow, so a long run of tool calls doesn't tug at the eye.
local ORBIT_SECONDS = 2
-- Ripple the ready ping out once, long enough to catch the eye without lingering.
local PING_SECONDS = 1
local FRAMES_PER_SECOND = 30
-- Color each state like a traffic light: amber busy, red decision, green ready.
local SESSION_STATE_COLORS = {
    busy = { red = 1, green = 0.69, blue = 0, alpha = 1 },
    decision = { red = 1, green = 0.23, blue = 0.19, alpha = 1 },
    ready = { red = 0.2, green = 0.78, blue = 0.35, alpha = 1 },
    none = { white = 0.55, alpha = 1 },
}
-- Rank the states, so a Space shared by several sessions shows the one most in need of you.
local SESSION_STATE_URGENCY = {
    busy = 1,
    ready = 2,
    decision = 3,
}
local FOCUS_MARK_COLOR = { white = 1, alpha = 1 }
-- Wait out macOS rearranging Spaces after a display change, a wake or a Space closing, which often runs on past the event reporting it.
local SETTLE_SECONDS = 1

local pinCanvasesToSpaces = require('pin_canvases_to_spaces')

local EDGE_BAR_BEHAVIOR = pinCanvasesToSpaces.BEHAVIOR

showSpacePosition = {}

-- Map each Space id to its own { left, right, bottom, bumper, dots } set of bars, bumper and dots.
local edgeBarsBySpace = {}
local edgeBarPairsCreated = 0
local settleTimer = nil
-- Map each Space id to its most urgent session state; nil until the first read, so a reload doesn't ping every ready dot.
local sessionStates = nil
-- Map each Space id to when its dot turned ready, to ripple its one ping.
local pingStartedAt = {}
local frameTimer = nil
-- Remember when follow_ready last switched Spaces, so a second session turning ready in the same idle stretch leaves you on the first.
local lastFollowAt = nil
-- Map each Space id to when its session turned ready while follow_ready wasn't armed, so arming later still takes you there.
local missedReadyAt = {}
-- Map each Space id to the window of its most urgent session, from the last read.
local sessionWindows = {}
local catchUpTimer = nil
local countdownTimer = nil

local function isEnabled(name)
    local value = hs.settings.get(SETTINGS_PREFIX .. name)
    if value == nil then
        return DEFAULT_ENABLED[name]
    end
    return value
end

local function isStyleChoice(name, value)
    for _, choice in ipairs(STYLE_CHOICES[name]) do
        if choice == value then
            return true
        end
    end
    return false
end

local function styleOf(name)
    local value = hs.settings.get(SETTINGS_PREFIX .. name)
    if value == nil then
        return DEFAULT_STYLES[name]
    elseif not isStyleChoice(name, value) then
        return DEFAULT_STYLES[name]
    end
    return value
end

local function numberOf(name)
    local value = hs.settings.get(SETTINGS_PREFIX .. name)
    if type(value) ~= 'number' then
        return DEFAULT_NUMBERS[name]
    end
    return value
end

local function sortedKeys(map)
    local names = {}
    for name in pairs(map) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function experimentNames()
    return sortedKeys(DEFAULT_ENABLED)
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

-- Right-align the text, so it hugs the dots however long it runs.
local function newCountdown()
    local countdown = newOverlay({ x = 0, y = 0, w = COUNTDOWN_WIDTH, h = TITLE_BAR_HEIGHT }, EDGE_BAR_BEHAVIOR)
    local textHeight = COUNTDOWN_TEXT_SIZE + 4
    countdown[1] = {
        type = 'text',
        text = '',
        textAlignment = 'right',
        textColor = COUNTDOWN_CALM_COLOR,
        -- Use fixed-width digits, so the text doesn't shift as each second ticks.
        textFont = 'Menlo',
        textSize = COUNTDOWN_TEXT_SIZE,
        frame = { x = 0, y = (TITLE_BAR_HEIGHT - textHeight) / 2, w = COUNTDOWN_WIDTH, h = textHeight },
    }
    return countdown
end

local function pageDotsWidth(count)
    return count * DOT_SIZE + (count - 1) * DOT_GAP + 2 * DOTS_PADDING
end

-- Keep the pill clear unless `pillVisible`, which shows where the canvas sits.
local function pageDotsPill(pillVisible)
    local height = TITLE_BAR_HEIGHT
    local pillAlpha
    if pillVisible then
        pillAlpha = 1
    else
        pillAlpha = 0
    end
    return {
        type = 'rectangle',
        action = 'fill',
        fillColor = { white = 0, alpha = pillAlpha },
        roundedRectRadii = { xRadius = height / 2, yRadius = height / 2 },
    }
end

local function pageDotCenter(position)
    return { x = DOTS_PADDING + (position - 1) * (DOT_SIZE + DOT_GAP) + DOT_SIZE / 2, y = TITLE_BAR_HEIGHT / 2 }
end

-- Draw one dot per Space in `color` on a pill, filling the dot at `index`.
local function layoutPageDots(dots, index, count, color, pillVisible)
    local elements = { pageDotsPill(pillVisible) }
    -- Draw the dots fully opaque, the same as the bumper, so they hold up against glare.
    local opaque = { red = color.red, green = color.green, blue = color.blue, alpha = 1 }
    for position = 1, count do
        local dot = {
            type = 'circle',
            center = pageDotCenter(position),
            radius = DOT_SIZE / 2,
            strokeColor = opaque,
            strokeWidth = 1.5,
        }
        if position == index then
            dot.action = 'strokeAndFill'
            dot.fillColor = opaque
        else
            dot.action = 'stroke'
        end
        elements[#elements + 1] = dot
    end
    dots:replaceElements(elements)
end

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

local function ring(center, radius, color, strokeWidth)
    return {
        type = 'circle',
        action = 'stroke',
        center = center,
        radius = radius,
        strokeColor = color,
        strokeWidth = strokeWidth,
    }
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

-- Circle a bright arc around a faint ring.
local function busyElements(center, seconds)
    local color = SESSION_STATE_COLORS.busy
    local start = phaseOf(seconds, ORBIT_SECONDS) * 360
    return {
        ring(center, RING_RADIUS, withAlpha(color, 0.3), RING_WIDTH),
        arc(center, RING_RADIUS, color, start, start + 100),
    }
end

local function decisionElements(style, center, seconds)
    local color = SESSION_STATE_COLORS.decision
    if style == 'blink' then
        local alpha = 1
        if phaseOf(seconds, 1.2) > 0.6 then
            alpha = 0.15
        end
        return { ring(center, RING_RADIUS, withAlpha(color, alpha), RING_WIDTH) }
    elseif style == 'flash' then
        return {
            disc(center, RING_RADIUS, withAlpha(color, 0.7 * wave(phaseOf(seconds, 1.5)))),
            ring(center, RING_RADIUS, color, RING_WIDTH),
        }
    elseif style == 'heartbeat' then
        local beat = heartbeat(phaseOf(seconds, 1.4))
        return { ring(center, RING_RADIUS + beat, withAlpha(color, 0.45 + 0.55 * beat), RING_WIDTH + beat) }
    elseif style == 'nudge' then
        local lift = 3 * nudge(phaseOf(seconds, 2.4))
        return { ring({ x = center.x, y = center.y - lift }, RING_RADIUS, color, RING_WIDTH) }
    end
    error('unknown decision style: ' .. style)
end

-- Draw a check inside the ring, rippling a ping out from it while `pingProgress` runs from 0 to 1.
local function readyElements(center, pingProgress)
    local color = SESSION_STATE_COLORS.ready
    local elements = {
        ring(center, RING_RADIUS, color, RING_WIDTH),
        line({
            { x = center.x - 3.5, y = center.y + 0.5 },
            { x = center.x - 1, y = center.y + 3 },
            { x = center.x + 3.5, y = center.y - 2.5 },
        }, color, 2),
    }
    if pingProgress ~= nil then
        elements[#elements + 1] = ring(center, RING_RADIUS + pingProgress * 8, withAlpha(color, 0.8 * (1 - pingProgress)), 2)
    end
    return elements
end

-- Draw the plain dots' thin ring, so a Space with no session looks as it did before session states.
local function noneElements(center)
    return { ring(center, DOT_SIZE / 2 - 0.75, SESSION_STATE_COLORS.none, 1.5) }
end

local function stateElements(state, center, seconds, pingProgress)
    if state == 'busy' then
        return busyElements(center, seconds)
    elseif state == 'decision' then
        return decisionElements(styleOf('decision_style'), center, seconds)
    elseif state == 'ready' then
        return readyElements(center, pingProgress)
    elseif state == 'none' then
        return noneElements(center)
    end
    error('unknown session state: ' .. state)
end

-- Mark the dot of the Space you're on the way the focus_marker style says, on top of its state.
local function focusedElements(state, center, seconds, pingProgress)
    local elements = stateElements(state, center, seconds, pingProgress)
    local marker = styleOf('focus_marker')
    if marker == 'center' then
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
    elseif marker == 'underline' then
        local y = center.y + DOT_SIZE / 2 + 5
        elements[#elements + 1] = line({ { x = center.x - 6, y = y }, { x = center.x + 6, y = y } }, FOCUS_MARK_COLOR, 2.5)
    else
        error('unknown focus marker: ' .. marker)
    end
    return elements
end

local function sessionStateOf(space)
    if sessionStates == nil then
        return 'none'
    end
    return sessionStates[space] or 'none'
end

-- Return how far the Space's ready ping has rippled, from 0 to 1, or nil once it's done.
local function pingProgressOf(space, seconds)
    local startedAt = pingStartedAt[space]
    if startedAt == nil then
        return nil
    elseif seconds - startedAt >= PING_SECONDS then
        return nil
    end
    return (seconds - startedAt) / PING_SECONDS
end

-- Return whether any dot in the row moves: an orbit, a decision's beat or a ping still rippling.
local function sessionDotsAnimate(spaces, seconds)
    for _, space in ipairs(spaces) do
        local state = sessionStateOf(space)
        if state == 'busy' then
            return true
        elseif state == 'decision' then
            return true
        elseif pingProgressOf(space, seconds) ~= nil then
            return true
        end
    end
    return false
end

-- Draw the home Space's triangle, so the row starts where the swipe does without the home Space reading as a session.
local function homeElements(center)
    local half = DOT_SIZE / 2 - 1
    local triangle = line({
        { x = center.x, y = center.y - half },
        { x = center.x + half, y = center.y + half * 0.8 },
        { x = center.x - half, y = center.y + half * 0.8 },
        -- Retrace the first side, so the closing corner gets the same round join as the others.
        { x = center.x, y = center.y - half },
        { x = center.x + half, y = center.y + half * 0.8 },
    }, SESSION_STATE_COLORS.none, 1.5)
    return { triangle }
end

-- Draw the home triangle, then one ring per Space in `spaces` showing its session's state, marking the ring at `index`; draw pings only when `animate`, since a still frame would freeze one mid-ripple.
local function layoutSessionDots(dots, index, spaces, pillVisible, seconds, animate)
    local elements = { pageDotsPill(pillVisible) }
    for _, element in ipairs(homeElements(pageDotCenter(1))) do
        elements[#elements + 1] = element
    end
    for position, space in ipairs(spaces) do
        -- Shift each ring one slot right of the home triangle.
        local center = pageDotCenter(position + 1)
        local state = sessionStateOf(space)
        local pingProgress = nil
        if animate then
            pingProgress = pingProgressOf(space, seconds)
        end
        local dotElements
        if position == index then
            dotElements = focusedElements(state, center, seconds, pingProgress)
        else
            dotElements = stateElements(state, center, seconds, pingProgress)
        end
        for _, element in ipairs(dotElements) do
            elements[#elements + 1] = element
        end
    end
    dots:replaceElements(elements)
end

-- Return a key that changes whenever a session row's still frame would, so an unchanged row skips its redraw.
local function sessionDotsKey(index, spaces, pillVisible)
    local parts = { index, tostring(pillVisible), styleOf('decision_style'), styleOf('focus_marker') }
    for _, space in ipairs(spaces) do
        parts[#parts + 1] = sessionStateOf(space)
    end
    return table.concat(parts, ' ')
end

local function readFile(filePath)
    local file = io.open(filePath, 'r')
    if file == nil then
        return nil
    end
    local contents = file:read('a')
    file:close()
    return contents
end

-- Return the Spaces holding a session's recorded window and that window's id; no Spaces once the window is gone, so a crashed session can't leave a stuck dot.
local function sessionSpaces(sessionId)
    local record = readFile(SESSION_STATE_DIR .. sessionId .. '.window')
    if record == nil then
        return {}
    end
    local windowId = tonumber(record:match('^%d+'))
    if windowId == nil then
        return {}
    end
    return hs.spaces.windowSpaces(windowId) or {}, windowId
end

-- Return each Space's most urgent session state, from the state words the hooks record, and the window of the session it came from.
local function readSessionStates()
    local states = {}
    local windows = {}
    if hs.fs.attributes(SESSION_STATE_DIR) == nil then
        return states, windows
    end
    for fileName in hs.fs.dir(SESSION_STATE_DIR) do
        local sessionId = fileName:match('^(.+)%.state$')
        local state = nil
        if sessionId ~= nil then
            state = (readFile(SESSION_STATE_DIR .. fileName) or ''):match('%a+')
        end
        if SESSION_STATE_URGENCY[state] ~= nil then
            local spaces, windowId = sessionSpaces(sessionId)
            for _, space in ipairs(spaces) do
                if states[space] == nil then
                    states[space] = state
                    windows[space] = windowId
                elseif SESSION_STATE_URGENCY[state] > SESSION_STATE_URGENCY[states[space]] then
                    states[space] = state
                    windows[space] = windowId
                end
            end
        end
    end
    return states, windows
end

-- Return where your idle stretch stands: 'waiting' until it's long enough to follow, 'armed' once it is, 'spent' after a follow in it.
local function followPhase(now)
    local idle = hs.host.idleTime()
    if idle < numberOf('follow_idle_seconds') then
        return 'waiting'
    elseif lastFollowAt == nil then
        return 'armed'
    elseif now - lastFollowAt < idle then
        -- Spend the stretch once a follow ran since your last input.
        return 'spent'
    end
    return 'armed'
end

-- Return whether follow_ready should switch you to `space`, which just turned ready.
local function shouldFollow(space, now)
    if not isEnabled('follow_ready') then
        return false
    elseif space == hs.spaces.focusedSpace() then
        return false
    elseif followPhase(now) ~= 'armed' then
        return false
    end
    return true
end

-- Switch to `space` by focusing its session's window, falling back to the Space itself when that window isn't reachable from here.
local function followTo(space, windowId, now)
    lastFollowAt = now
    local window = hs.window.get(windowId)
    if window then
        window:focus()
    else
        hs.spaces.gotoSpace(space)
    end
end

-- Follow the newest session that turned ready while you were busy, once you've been idle long enough to arm.
local function followMissedReady()
    local now = hs.timer.secondsSinceEpoch()
    if followPhase(now) ~= 'armed' then
        return
    end
    local newest = nil
    for space, readyAt in pairs(missedReadyAt) do
        if newest == nil or readyAt > missedReadyAt[newest] then
            newest = space
        end
    end
    if newest ~= nil then
        missedReadyAt[newest] = nil
        followTo(newest, sessionWindows[newest], now)
    end
end

local function stopCatchUp()
    if catchUpTimer then
        catchUpTimer:stop()
        catchUpTimer = nil
    end
end

-- Watch for arming once a second while a missed ready waits, and only then.
local function updateCatchUpTimer()
    if not isEnabled('follow_ready') then
        stopCatchUp()
    elseif next(missedReadyAt) == nil then
        stopCatchUp()
    elseif catchUpTimer == nil then
        catchUpTimer = hs.timer.doEvery(1, function()
            followMissedReady()
            updateCatchUpTimer()
        end)
    end
end

-- Re-read every session's state, starting a ping on each Space that just turned ready and following it there when you're away, or once you are.
local function refreshSessionStates()
    local states, windows = readSessionStates()
    if sessionStates ~= nil then
        local now = hs.timer.secondsSinceEpoch()
        for space, state in pairs(states) do
            if state == 'ready' and sessionStates[space] ~= 'ready' then
                pingStartedAt[space] = now
                if shouldFollow(space, now) then
                    followTo(space, windows[space], now)
                elseif space ~= hs.spaces.focusedSpace() then
                    missedReadyAt[space] = now
                end
            end
        end
    end
    -- Forget a missed ready once its session moves on.
    for space in pairs(missedReadyAt) do
        if states[space] ~= 'ready' then
            missedReadyAt[space] = nil
        end
    end
    sessionStates = states
    sessionWindows = windows
    updateCatchUpTimer()
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

-- Return whether the focused Space gets the countdown, which rides along with the dots.
local function showsCountdown(focused)
    if not isEnabled('follow_countdown') then
        return false
    elseif not isEnabled('follow_ready') then
        return false
    end
    return showsPageDots(focused)
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
    pair.countdown:delete()
end

-- Drop the pairs of Spaces that no longer exist.
local function pruneEdgeBars()
    pinCanvasesToSpaces.pruneClosedSpaces(edgeBarsBySpace, deleteEdgeBarPair)
end

-- Return the Spaces on `screen` that get a session ring, in row order.
local function sessionDotSpaces(screen)
    -- Leave the home Space out; it's where the swipe starts, not a page worth a ring, so it gets the home triangle instead.
    local spaces = {}
    for position, space in ipairs(hs.spaces.spacesForScreen(screen) or {}) do
        if position > 1 then
            spaces[#spaces + 1] = space
        end
    end
    return spaces
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
    -- Start the right bar below the title bar, level with the top of the alternate clock that sits there on a full-screen Space.
    local rightBarTop = frame.y + TITLE_BAR_HEIGHT
    local rightBarFrame = { x = frame.x, y = rightBarTop, w = frame.w, h = frame.y + frame.h - rightBarTop }
    -- Redraw the elements only when a bar's height changes, so a plain Space switch never repaints the bars.
    if pair.leftHeight ~= barFrame.h then
        layoutEdgeBar(pair.left, 'left', pair.color, barFrame.h)
        pair.leftHeight = barFrame.h
    end
    if pair.rightHeight ~= rightBarFrame.h then
        layoutEdgeBar(pair.right, 'right', pair.color, rightBarFrame.h)
        pair.rightHeight = rightBarFrame.h
    end
    pair.left:frame(edgeBarFrame(barFrame, barFrame.x))
    pair.right:frame(edgeBarFrame(rightBarFrame, rightBarFrame.x + rightBarFrame.w - EDGE_BAR_CANVAS_WIDTH))
    pair.bottom:frame({ x = frame.x, y = frame.y + frame.h - BOTTOM_BAR_HEIGHT, w = frame.w, h = BOTTOM_BAR_HEIGHT })
    pair.bumper:frame({
        x = frame.x + frame.w - BUMPER_DEPTH,
        y = frame.y + (frame.h - BUMPER_HEIGHT) / 2,
        w = BUMPER_DEPTH,
        h = BUMPER_HEIGHT,
    })
    -- Redraw the dots only when the Space moved, the count changed or the pill was toggled, the same as the bars' height check.
    local pillVisible = isEnabled('page_dots_pill')
    local dotsCount = count
    if isEnabled('session_state') then
        local spaces = sessionDotSpaces(screen)
        local rowIndex = index - 1
        local key = sessionDotsKey(rowIndex, spaces, pillVisible)
        pair.sessionIndex = rowIndex
        pair.sessionSpaces = spaces
        -- Count the home triangle too.
        dotsCount = #spaces + 1
        if pair.sessionKey ~= key then
            layoutSessionDots(pair.dots, rowIndex, spaces, pillVisible, hs.timer.secondsSinceEpoch(), false)
            pair.sessionKey = key
            -- Forget the plain dots, so turning session_state off redraws them.
            pair.dotsIndex = nil
        end
    elseif pair.dotsIndex ~= index or pair.dotsCount ~= count or pair.dotsPill ~= pillVisible then
        layoutPageDots(pair.dots, index, count, pair.color, pillVisible)
        pair.dotsIndex = index
        pair.dotsCount = count
        pair.dotsPill = pillVisible
        pair.sessionKey = nil
    end
    local dotsWidth = pageDotsWidth(dotsCount)
    -- Sit the dots flush against the screen's right edge, over the right bar's glow.
    pair.dots:frame({
        x = frame.x + frame.w - dotsWidth,
        y = frame.y,
        w = dotsWidth,
        h = TITLE_BAR_HEIGHT,
    })
    pair.countdown:frame({
        x = frame.x + frame.w - dotsWidth - COUNTDOWN_WIDTH,
        y = frame.y,
        w = COUNTDOWN_WIDTH,
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
            countdown = newCountdown(),
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
    setEdgeBarVisible(pair.countdown, showsCountdown(focused))
end

-- Return every Space's pair whose session dots are showing, not just the focused one, so whichever Space a swipe or jump reveals is already on the current frame.
local function shownSessionPairs()
    local shown = {}
    if not isEnabled('session_state') then
        return shown
    end
    for _, pair in pairs(edgeBarsBySpace) do
        if pair.sessionSpaces == nil then
            -- Skip a pair still showing plain dots.
        elseif not pair.dots:isShowing() then
            -- Skip a desktop's pair, which never shows its dots.
        else
            shown[#shown + 1] = pair
        end
    end
    return shown
end

-- Return whether any of `sessionPairs` has a dot moving.
local function anySessionDotsAnimate(sessionPairs, seconds)
    for _, pair in ipairs(sessionPairs) do
        if sessionDotsAnimate(pair.sessionSpaces, seconds) then
            return true
        end
    end
    return false
end

local function stopAnimating()
    if frameTimer then
        frameTimer:stop()
        frameTimer = nil
    end
end

-- Redraw every shown row of session dots one frame on; stop the timer on a still frame once nothing moves, so an idle machine never wakes for it.
local function animateFrame()
    local seconds = hs.timer.secondsSinceEpoch()
    local pillVisible = isEnabled('page_dots_pill')
    local moving = false
    for _, pair in ipairs(shownSessionPairs()) do
        local animate = sessionDotsAnimate(pair.sessionSpaces, seconds)
        layoutSessionDots(pair.dots, pair.sessionIndex, pair.sessionSpaces, pillVisible, seconds, animate)
        if animate then
            moving = true
        end
    end
    if not moving then
        stopAnimating()
    end
end

-- Run the frame timer while any shown row of session dots has something moving, and only then.
local function updateAnimation()
    if not anySessionDotsAnimate(shownSessionPairs(), hs.timer.secondsSinceEpoch()) then
        stopAnimating()
    elseif frameTimer == nil then
        frameTimer = hs.timer.doEvery(1 / FRAMES_PER_SECOND, animateFrame)
    end
end

-- Return what follow_ready would do if a session turned ready now.
local function countdownText(now)
    local phase = followPhase(now)
    if phase == 'waiting' then
        return string.format('%d', math.ceil(numberOf('follow_idle_seconds') - hs.host.idleTime()))
    elseif phase == 'armed' then
        return '0'
    elseif phase == 'spent' then
        return '-'
    end
    error('unknown follow phase: ' .. phase)
end

-- Return the countdown's color, hotter each second follow_ready nears arming.
local function countdownColor(now)
    local phase = followPhase(now)
    local heat
    if phase == 'waiting' then
        local idleSeconds = numberOf('follow_idle_seconds')
        heat = 1 - math.ceil(idleSeconds - hs.host.idleTime()) / idleSeconds
    elseif phase == 'armed' then
        heat = 1
    elseif phase == 'spent' then
        heat = 0
    else
        error('unknown follow phase: ' .. phase)
    end
    local color = {}
    for channel, calm in pairs(COUNTDOWN_CALM_COLOR) do
        color[channel] = calm + (COUNTDOWN_ARMED_COLOR[channel] - calm) * heat
    end
    return color
end

local function updateCountdowns()
    local now = hs.timer.secondsSinceEpoch()
    local text = countdownText(now)
    local color = countdownColor(now)
    for _, pair in pairs(edgeBarsBySpace) do
        if pair.countdown:isShowing() then
            pair.countdown[1].text = text
            pair.countdown[1].textColor = color
        end
    end
end

local function stopCountdowns()
    if countdownTimer then
        countdownTimer:stop()
        countdownTimer = nil
    end
end

-- Tick the countdowns once a second while follow_countdown is on, and only then.
local function updateCountdownTimer()
    if not isEnabled('follow_countdown') then
        stopCountdowns()
    elseif not isEnabled('follow_ready') then
        stopCountdowns()
    elseif countdownTimer == nil then
        countdownTimer = hs.timer.doEvery(1, updateCountdowns)
    end
end

local function render()
    if isEnabled('session_state') then
        refreshSessionStates()
    end
    local index, count, screen, focused = focusedPosition()
    -- Forget a missed ready once you've seen its Space.
    missedReadyAt[focused] = nil
    renderEdgeBars(index, count, screen, focused)
    updateAnimation()
    updateCountdownTimer()
    updateCountdowns()
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

-- Redraw every Space's session dots after a hook records a state, so each row is current before it's next seen.
local function renderSessionStates(changedPaths)
    if not isEnabled('session_state') then
        return
    end
    local stateChanged = false
    for _, changedPath in ipairs(changedPaths) do
        if changedPath:match('%.state$') then
            stateChanged = true
        end
    end
    if not stateChanged then
        return
    end
    refreshSessionStates()
    placeEveryEdgeBarSet()
    updateAnimation()
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

-- Turn an experiment on or off, pick a style or set a number, or report every one's current value when called with no name.
function showSpacePosition.set(name, value)
    if name == nil then
        local lines = {}
        for _, experiment in ipairs(experimentNames()) do
            lines[#lines + 1] = experiment .. ' ' .. (isEnabled(experiment) and 'on' or 'off')
        end
        for _, style in ipairs(sortedKeys(DEFAULT_STYLES)) do
            lines[#lines + 1] = style .. ' ' .. styleOf(style)
        end
        for _, number in ipairs(sortedKeys(DEFAULT_NUMBERS)) do
            lines[#lines + 1] = number .. ' ' .. numberOf(number)
        end
        return table.concat(lines, '\n')
    elseif DEFAULT_NUMBERS[name] ~= nil then
        if type(value) ~= 'number' then
            return name .. ' takes a number of seconds, not ' .. tostring(value)
        elseif value < 0 then
            return name .. ' takes a number of seconds, not ' .. tostring(value)
        end
        hs.settings.set(SETTINGS_PREFIX .. name, value)
        return name .. ' ' .. value
    elseif DEFAULT_STYLES[name] ~= nil then
        if not isStyleChoice(name, value) then
            return 'unknown ' .. name .. ': ' .. tostring(value) .. ' (expected one of: ' .. table.concat(STYLE_CHOICES[name], ', ') .. ')'
        end
        hs.settings.set(SETTINGS_PREFIX .. name, value)
        render()
        return name .. ' ' .. value
    elseif DEFAULT_ENABLED[name] == nil then
        local names = experimentNames()
        for _, style in ipairs(sortedKeys(DEFAULT_STYLES)) do
            names[#names + 1] = style
        end
        for _, number in ipairs(sortedKeys(DEFAULT_NUMBERS)) do
            names[#names + 1] = number
        end
        return 'unknown experiment: ' .. name .. ' (expected one of: ' .. table.concat(names, ', ') .. ')'
    elseif type(value) ~= 'boolean' then
        return name .. ' takes on or off, not ' .. tostring(value)
    end

    hs.settings.set(SETTINGS_PREFIX .. name, value)
    render()
    return name .. ' ' .. (value and 'on' or 'off')
end

-- Return which session ring stands for `space` on `screen`, the numbering the dots row shows.
local function ringLabel(space, screen)
    for ring, candidate in ipairs(sessionDotSpaces(screen)) do
        if candidate == space then
            return 'ring ' .. ring
        end
    end
    return 'home, no ring'
end

-- Name `space` by its swipe-order position and its session ring (Space #3 (ring 2)), since the id hs.spaces hands out means nothing to a person.
function showSpacePosition.spaceNumber(space)
    for screen, spaces in pairs(hs.spaces.allSpaces() or {}) do
        for index, candidate in ipairs(spaces) do
            if candidate == space then
                return 'Space #' .. index .. ' (' .. ringLabel(space, screen) .. ')'
            end
        end
    end
    return 'unknown Space ' .. tostring(space)
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
-- Create the hooks' folder if no session has yet, so the watcher has something to watch.
hs.fs.mkdir(SESSION_STATE_DIR)
showSpacePosition.sessionStateWatcher = hs.pathwatcher.new(SESSION_STATE_DIR, renderSessionStates)
showSpacePosition.sessionStateWatcher:start()
render()
