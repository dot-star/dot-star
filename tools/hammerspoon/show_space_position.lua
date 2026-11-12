-- Show where the focused Space sits in the swipe order, as experiments toggled independently:
--   Add a strip on the right edge of the last full-screen Space, where swiping right goes no further (edge_bars).
--   Add a strip on the left edge of the first full-screen Space, where swiping left leaves the full-screen apps (edge_bars).
--   Add a thin band along the bottom edge of every full-screen Space in that Space's strip color (bottom_bar, needs edge_bars).
--   Add a matching band along the top edge of every full-screen Space (top_bar, needs edge_bars).
--   Paint each Space's bars the next color in a cycle rather than one shared color (cycle_colors, needs edge_bars).
--   Add a row of dots in the title bar's upper-right corner of every full-screen Space, the focused Space filled; click a dot to jump to its Space (page_dots, needs edge_bars).
--   Show the dots on a desktop too, placed as on a full-screen Space over the menu bar, left of the clock in the corner (desktop_dots, needs page_dots).
--   Add a hint at the middle of a desktop's right edge while a Space lies beyond it, so swiping right reads as possible; a chevron, a large chevron, a double chevron, a block or a chevron on a dark tab (swipe_hint, needs edge_bars).
--   Show the dark pill behind the dots, to check where their canvas sits (page_dots_pill, needs page_dots).
--   Stack the dots in a column down the upper-right corner, in swipe order from the top (vertical_dots, needs page_dots).
--   Show on each dot the state of the Claude session whose window sits on that Space (session_state, needs page_dots).
--   Switch to a Space whose session turned ready, once you've been idle a while (follow_ready, needs session_state).
--   Show a countdown left of the dots to when follow_ready arms, for debugging (follow_countdown, needs follow_ready).
--   Mark the dots with letters in the order a closing session hops to them, by state then last seen, so they don't read as the Ctrl+number Space keys; for debugging (follow_order, needs session_state).
-- Hand follow_closed_full_screen_space the ranked Spaces with hopOrder, so a closing session hops to the one most in need of you.
-- Toggle from the shell with `space_position_experiment`; each flag persists across reloads.
-- Pick the session dots' decision style, pending style and focus marker the same way; each style persists too.
-- Set how long you must be idle before follow_ready switches Spaces the same way, with follow_idle_seconds.
-- Re-place the bars after a display change or a wake, which move the screens without switching Spaces.
-- Redraw a beat after each Space change too, so bars of a full-screen Space that just closed get deleted.

-- Apply each experiment's default until it's toggled; a saved setting wins after that.
local DEFAULT_ENABLED = {
    bottom_bar = true,
    cycle_colors = false,
    desktop_dots = false,
    edge_bars = true,
    follow_countdown = true,
    follow_order = true,
    follow_ready = true,
    page_dots = true,
    page_dots_pill = false,
    session_state = true,
    swipe_hint = true,
    top_bar = true,
    vertical_dots = false,
}
-- Apply each style's default until it's set; a saved choice wins after that.
local DEFAULT_STYLES = {
    decision_style = 'heartbeat',
    focus_marker = 'underline',
    pending_style = 'pulse',
    swipe_hint_style = 'double',
}
local STYLE_CHOICES = {
    decision_style = { 'blink', 'flash', 'heartbeat', 'nudge' },
    focus_marker = { 'center', 'underline' },
    pending_style = { 'dashed', 'dot', 'pulse' },
    swipe_hint_style = { 'block', 'chevron', 'double', 'large', 'tab' },
}
-- Apply each number's default until it's set; a saved value wins after that.
local DEFAULT_NUMBERS = {
    -- Wait out a pause for thought, so a session finishing while you're mid-task never pulls you off it.
    follow_idle_seconds = 30,
}
local SETTINGS_PREFIX = 'show_space_position.'
local EDGE_BAR_WIDTH = 7
-- Keep the top and bottom bands thinner than the edge strips, so they hint at the Space's color without eating into the terminal.
local BAND_HEIGHT = 5
-- Group the swipe hint's sizes and colors in one table, keeping the chunk under Lua's limit of 200 locals.
local SWIPE_HINT = {
    -- Size the swipe hint to the old last-page bumper, which read at a glance without crowding the desktop.
    WIDTH = 28,
    HEIGHT = 140,
    -- Keep the chevron shorter than the block, so it reads as an arrow rather than a bracket.
    CHEVRON_HEIGHT = 56,
    CHEVRON_WIDTH = 5,
    -- Outline the chevron in black, so it holds its shape over a light wallpaper or window.
    OUTLINE_WIDTH = 4,
    OUTLINE_COLOR = { white = 0, alpha = 1 },
    -- Back the tab style's chevron with a dark half-pill, a blob big and contrasty enough to spot through a squint on any wallpaper.
    TAB_WIDTH = 44,
    TAB_RADIUS = 14,
    TAB_COLOR = { white = 0, alpha = 1 },
    TAB_CHEVRON_HEIGHT = 70,
    TAB_CHEVRON_DEPTH = 16,
    TAB_CHEVRON_WIDTH = 10,
    -- Grow the large style's chevron to the hint's full height with a heavy stroke, so it survives a squint without a backing tab.
    LARGE_CHEVRON_DEPTH = 28,
    LARGE_CHEVRON_WIDTH = 12,
    -- Pair two full-height chevrons, doubling the yellow area and reading as fast-forward toward the next Space.
    DOUBLE_CHEVRON_DEPTH = 24,
    DOUBLE_CHEVRON_WIDTH = 10,
    -- Space the chevrons wider than their outlined stroke, so a gap of desktop shows between them.
    DOUBLE_SPACING = 26,
}
SWIPE_HINT.LARGE_OUTLINE_WIDTH = SWIPE_HINT.LARGE_CHEVRON_WIDTH + 2 * SWIPE_HINT.OUTLINE_WIDTH
SWIPE_HINT.LARGE_WIDTH = SWIPE_HINT.LARGE_CHEVRON_DEPTH + SWIPE_HINT.LARGE_OUTLINE_WIDTH
SWIPE_HINT.DOUBLE_OUTLINE_WIDTH = SWIPE_HINT.DOUBLE_CHEVRON_WIDTH + 2 * SWIPE_HINT.OUTLINE_WIDTH
SWIPE_HINT.DOUBLE_WIDTH = SWIPE_HINT.DOUBLE_SPACING + SWIPE_HINT.DOUBLE_CHEVRON_DEPTH + SWIPE_HINT.DOUBLE_OUTLINE_WIDTH
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
local DOT_GAP = 14
-- Fill the native title bar Ghostty keeps for its tabs with the dots' pill.
local TITLE_BAR_HEIGHT = require('ghostty_title_bar').HEIGHT
-- Run each dot from the screen's top edge down to the bottom of the tab strip centered in the title bar, pushing the underline, letters and hotkeys below it.
local DOT_SIZE = (TITLE_BAR_HEIGHT + require('ghostty_title_bar').TAB_STRIP_HEIGHT) / 2
-- Pad the pill's ends as much as its top and bottom, so the rounded ends hug the first and last dots evenly.
local DOTS_PADDING = (TITLE_BAR_HEIGHT - DOT_SIZE) / 2
-- Leave room for the countdown's longest text, so it never clips against the dots.
local COUNTDOWN_WIDTH = 60
local COUNTDOWN_TEXT_SIZE = 22
-- Stroke the countdown's debug outline green, apart from the dots' red, yellow and cyan boxes beside it.
local COUNTDOWN_OUTLINE_COLOR = { red = 0, green = 1, blue = 0, alpha = 1 }
local COUNTDOWN_OUTLINE_HIDDEN_COLOR = { red = 0, green = 1, blue = 0, alpha = 0 }
-- Heat the countdown from dim gray up to white a third of the way in, then hold white until follow_ready arms.
-- Keep the early seconds dim, so a countdown that resets on every keystroke stays out of the way.
local COUNTDOWN_COLOR_STOPS = {
    { heat = 0, color = { red = 0.3, green = 0.3, blue = 0.3, alpha = 1 } },
    { heat = 1 / 3, color = { red = 1, green = 1, blue = 1, alpha = 1 } },
    { heat = 1, color = { red = 1, green = 1, blue = 1, alpha = 1 } },
}
-- Read each Claude session's state word and window record from where `announce_window_state.py` writes them.
local SESSION_STATE_DIR = '/tmp/claude-state-hook/'
-- Thicken a session dot's ring past the plain dots' hairline stroke, so its color reads at a glance.
local RING_WIDTH = 3.5
local RING_RADIUS = DOT_SIZE / 2 - RING_WIDTH / 2
-- Thicken the home triangle past the plain dots' hairline, tuned by eye apart from the rings since its corners read differently from a ring's even line.
local HOME_TRIANGLE_WIDTH = 3
-- Keep the orbit slow, so a long run of tool calls doesn't tug at the eye.
local ORBIT_SECONDS = 2
-- Ripple the ready ping out once, long enough to catch the eye without lingering.
local PING_SECONDS = 1
-- Hold a session's ready back until it lasts this long, outlasting a Stop hook that blocks the stop and sends Claude back to work.
local READY_SETTLE_SECONDS = 3
local FRAMES_PER_SECOND = 30
-- Hand each moving ring and line a numeric frame it never draws with, since the canvas otherwise parses the frame's percentage default with a new number formatter on every repaint.
local UNDRAWN_FRAME = { x = 0, y = 0, w = 0, h = 0 }
-- Color each state like a traffic light: amber busy, red decision, green ready.
-- Keep pending colorless, so a session not yet known never reads as one at work.
local SESSION_STATE_COLORS = {
    busy = { red = 1, green = 0.69, blue = 0, alpha = 1 },
    decision = { red = 1, green = 0.23, blue = 0.19, alpha = 1 },
    ready = { red = 0.2, green = 0.78, blue = 0.35, alpha = 1 },
    pending = { white = 0.55, alpha = 1 },
    none = { white = 0.55, alpha = 1 },
}
-- Rank the states, so a Space shared by several sessions shows the one most in need of you.
local SESSION_STATE_URGENCY = {
    busy = 1,
    ready = 2,
    decision = 3,
}
-- Rank where a hop off a closing session lands: a decision blocks you, a finished session waits on you, and an empty Space beats one still working.
local HOP_STATE_PRIORITY = {
    decision = 1,
    ready = 2,
    none = 3,
    busy = 4,
}
local FOCUS_MARK_COLOR = { white = 1, alpha = 1 }
-- Frame the dot under the pointer, so a click's target shows before you commit to it.
local HOVER_FRAME_COLOR = { white = 1, alpha = 0.8 }
local HOVER_FRAME_WIDTH = 2.5
-- Reach into the gap on each side of the dot, stopping short of the neighbor's frame.
local HOVER_FRAME_SIDE_PADDING = DOT_GAP / 2 - 1
-- Keep the frame off the title bar's edges, tall enough to take in the focus underline and follow-order letter.
local HOVER_FRAME_MARGIN = 2
local HOVER_FRAME_RADIUS = 6
-- Size the follow-order letter to read at a glance under its dot.
local FOLLOW_ORDER_TEXT_SIZE = 13
local FOLLOW_ORDER_FONT = 'Menlo-Bold'
local BADGE_TEXT_HEIGHT = FOLLOW_ORDER_TEXT_SIZE + 2
-- Find the follow-order letters' cap midline below their frame's top, so the focus underline lines up with them; text hangs from the frame's top by the font's ascender.
local followOrderFontInfo = hs.styledtext.fontInfo({ name = FOLLOW_ORDER_FONT, size = FOLLOW_ORDER_TEXT_SIZE })
local FOLLOW_ORDER_MIDLINE = followOrderFontInfo.ascender - followOrderFontInfo.capHeight / 2
-- Size the Ctrl+N digits to read at a glance inside a dot without touching its ring.
local HOTKEY_TEXT_SIZE = 14
local HOTKEY_TEXT_HEIGHT = HOTKEY_TEXT_SIZE + 2
-- Grow a row of dots below the title bar to fit the follow-order letters, overlapping the window's top edge there.
local HORIZONTAL_DOTS_HEIGHT = DOT_SIZE + BADGE_TEXT_HEIGHT
local HOTKEY_COLOR = { white = 1, alpha = 1 }
-- Mark only the first few picks in the follow order, so the row shows where a close lands next without badging every dot.
local FOLLOW_ORDER_LIMIT = 3
-- Wait out macOS rearranging Spaces after a display change, a wake or a Space closing, which often runs on past the event reporting it.
local SETTLE_SECONDS = 1

local pinCanvasesToSpaces = require('pin_canvases_to_spaces')
-- Load the alternate clock first, whose update_clock_position re-places it beside the dots' column.
require('display_alternate_clock')
local numberedSpaceKeys = require('numbered_space_keys')
local spaceTypes = require('space_types')

local EDGE_BAR_BEHAVIOR = pinCanvasesToSpaces.BEHAVIOR

showSpacePosition = {}

-- Map each Space id to its own { left, right, top, bottom, swipeHint, dots } set of bars, hint and dots.
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
-- Map each Space id to when its session's ready was first read, so the dot shows it only once it has settled.
local readySince = {}
local readySettleTimer = nil
-- Redraw every Space's session dots; assigned once the drawing functions below exist.
local redrawSessionDots
-- Map each Space id to the window of its most urgent session, from the last read.
local sessionWindows = {}
-- Hold the last read's states before ready-settling, with their windows and change times, so the follow-order badges rank what hopOrder ranks without re-reading the folder per Space.
local sessionReading = nil
-- Map each Space id to when you were last on it, so the green checks can be ranked by how fresh each is in your head.
local lastSeenAt = {}
local currentSpace = nil
-- Map each screen to the Space showing on it, read once per render since each read copies every display's Space list.
local onScreenSpaces = {}
local catchUpTimer = nil
local countdownTimer = nil
-- Remember what every row was last placed from, so a state write that changes nothing on any row skips placing them all again.
local placedSessionKey = nil

-- Map each setting name to a box holding its saved value, since each read crosses into the defaults store and the frame timer asks for several per frame.
local settingsCache = {}

-- Return a setting's saved value, or nil when it was never set.
local function readSetting(name)
    local box = settingsCache[name]
    if box == nil then
        box = { value = hs.settings.get(SETTINGS_PREFIX .. name) }
        settingsCache[name] = box
    end
    return box.value
end

local function writeSetting(
    name,
    value
)
    hs.settings.set(SETTINGS_PREFIX .. name, value)
    settingsCache[name] = nil
    -- Place every row on the next state write, since a setting can change how each one draws.
    placedSessionKey = nil
end

local function isEnabled(name)
    local value = readSetting(name)
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
    local value = readSetting(name)
    if value == nil then
        return DEFAULT_STYLES[name]
    elseif not isStyleChoice(name, value) then
        return DEFAULT_STYLES[name]
    end
    return value
end

local function numberOf(name)
    local value = readSetting(name)
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

-- Return the focused Space's 1-based position, the Space count, the screen holding them, the focused Space's id and that screen's Spaces in swipe order.
local function focusedPosition()
    local focused = hs.spaces.focusedSpace()
    local screen = hs.screen.find(hs.spaces.spaceDisplay(focused)) or hs.screen.mainScreen()
    local spaces = hs.spaces.spacesForScreen(screen) or {}
    for index, space in ipairs(spaces) do
        if space == focused then
            return index, #spaces, screen, focused, spaces
        end
    end
    return nil, #spaces, screen, focused, spaces
end

local function edgeBarFrame(screenFrame, x)
    return { x = x, y = screenFrame.y, w = EDGE_BAR_WIDTH, h = screenFrame.h }
end

-- Fade the whole canvas rather than its fill, the same as a band.
local function newEdgeBar(color)
    local bar = newOverlay({ x = 0, y = 0, w = EDGE_BAR_WIDTH, h = 1 }, EDGE_BAR_BEHAVIOR)
    bar:alpha(color.alpha)
    return bar
end

-- Fill the whole canvas, so resizing the band to a new screen width needs no redraw.
local function newBand(color)
    local bar = newOverlay({ x = 0, y = 0, w = 1, h = BAND_HEIGHT }, EDGE_BAR_BEHAVIOR)
    bar:alpha(color.alpha)
    bar[1] = {
        type = 'rectangle',
        action = 'fill',
        fillColor = { red = color.red, green = color.green, blue = color.blue, alpha = 1 },
    }
    return bar
end

-- Fill the strip solid, flush against the screen edge its canvas sits on.
local function layoutEdgeBar(
    bar,
    color,
    height
)
    bar[1] = {
        type = 'rectangle',
        action = 'fill',
        fillColor = { red = color.red, green = color.green, blue = color.blue, alpha = 1 },
        frame = { x = 0, y = 0, w = EDGE_BAR_WIDTH, h = height },
    }
end

local function newSwipeHint()
    return newOverlay({ x = 0, y = 0, w = SWIPE_HINT.WIDTH, h = SWIPE_HINT.HEIGHT }, EDGE_BAR_BEHAVIOR)
end

local function newPageDots()
    local dots = newOverlay({ x = 0, y = 0, w = 1, h = TITLE_BAR_HEIGHT }, EDGE_BAR_BEHAVIOR)
    -- Keep Hammerspoon in the background on a click, so focusing the clicked Space's window isn't undone.
    dots:clickActivating(false)
    return dots
end

-- Hold a row's moving rings above its still row, so an animation frame repaints a few elements rather than the whole row.
-- Give it no mouse callback, which leaves it click-through to the row beneath.
local function newPageDotsMotion()
    local motion = newOverlay({ x = 0, y = 0, w = 1, h = TITLE_BAR_HEIGHT }, EDGE_BAR_BEHAVIOR)
    -- Stack above the still row, which shares the overlay level.
    motion:level(hs.canvas.windowLevels.overlay + 1)
    return motion
end

-- Right-align the text, so it hugs the dots however long it runs.
local function newCountdown()
    local countdown = newOverlay({ x = 0, y = 0, w = COUNTDOWN_WIDTH, h = DOT_SIZE }, EDGE_BAR_BEHAVIOR)
    local textHeight = COUNTDOWN_TEXT_SIZE + 4
    countdown[1] = {
        type = 'text',
        text = '',
        textAlignment = 'right',
        textColor = COUNTDOWN_CALM_COLOR,
        -- Use fixed-width digits, so the text doesn't shift as each second ticks.
        textFont = 'Menlo',
        textSize = COUNTDOWN_TEXT_SIZE,
        frame = { x = 0, y = (DOT_SIZE - textHeight) / 2, w = COUNTDOWN_WIDTH, h = textHeight },
    }
    -- Trace the whole canvas for debugging; placement shows it only while page_dots_pill is on.
    countdown[2] = {
        type = 'rectangle',
        action = 'stroke',
        strokeColor = COUNTDOWN_OUTLINE_HIDDEN_COLOR,
        strokeWidth = 1,
    }
    return countdown
end

-- Return the dots canvas's size; a column gives each slot the strip beneath its dot too, so the last dot's follow-order letter isn't clipped.
local function pageDotsSize(count)
    if isEnabled('vertical_dots') then
        return { w = TITLE_BAR_HEIGHT, h = count * (DOT_SIZE + DOT_GAP) + 2 * DOTS_PADDING }
    end
    return { w = count * DOT_SIZE + (count - 1) * DOT_GAP + 2 * DOTS_PADDING, h = HORIZONTAL_DOTS_HEIGHT }
end

-- Keep the pill clear unless `pillVisible`, which shows where the canvas sits.
-- Draw it square-cornered, so it traces the canvas's edges even where the row hangs below the title bar.
local function pageDotsPill(pillVisible)
    local pillAlpha
    if pillVisible then
        pillAlpha = 1
    else
        pillAlpha = 0
    end
    return {
        type = 'rectangle',
        action = 'fill',
        -- Tint it a debug magenta, which stands out against both the gray tab strip and the black window below it.
        fillColor = { red = 1, green = 0, blue = 1, alpha = 0.35 * pillAlpha },
    }
end

local function pageDotCenter(slot)
    local along = DOTS_PADDING + (slot - 1) * (DOT_SIZE + DOT_GAP) + DOT_SIZE / 2
    if isEnabled('vertical_dots') then
        return { x = TITLE_BAR_HEIGHT / 2, y = along }
    end
    -- Hang a row from the canvas's top edge, which sits at the screen's top.
    return { x = along, y = DOT_SIZE / 2 }
end

-- Return the frame of the band the `count` dots run along.
local function pageDotsBandFrame(count)
    local first = pageDotCenter(1)
    local last = pageDotCenter(count)
    -- Span the canvas's full width, so only the dots' top and bottom edges set it apart from the tint.
    return {
        x = 0,
        y = first.y - DOT_SIZE / 2,
        w = pageDotsSize(count).w,
        h = last.y - first.y + DOT_SIZE,
    }
end

-- Return the frame of the dots' band plus the strip under it, where the focus underline and follow-order letters sit.
local function pageDotsBadgeFrame(count)
    local frame = pageDotsBandFrame(count)
    frame.h = frame.h + BADGE_TEXT_HEIGHT
    return frame
end

-- Back the band the `count` dots run along, and the labels under it, in black whether or not `pillVisible`, so they read the same against whatever sits behind them.
local function pageDotsBand(count)
    return {
        type = 'rectangle',
        action = 'fill',
        fillColor = { red = 0, green = 0, blue = 0, alpha = 1 },
        frame = pageDotsBadgeFrame(count),
    }
end

-- Rule off the black band's bottom edge in white unless `pillVisible`, whose debug boxes trace that edge already, so the band reads as a panel against a black window.
local function appendDotsBottomEdge(
    elements,
    pillVisible,
    count
)
    if pillVisible then
        return
    end
    local frame = pageDotsBadgeFrame(count)
    -- Inset by half the stroke, so the whole line lands inside the canvas.
    local y = frame.y + frame.h - 0.5
    elements[#elements + 1] = {
        type = 'segments',
        action = 'stroke',
        closed = false,
        coordinates = { { x = frame.x, y = y }, { x = frame.x + frame.w, y = y } },
        strokeColor = { white = 1, alpha = 1 },
        strokeWidth = 1,
    }
end

-- Outline the band the `count` dots run along, and the whole canvas, while `pillVisible`, inside the tinted canvas, so the boxes show how far the labels hang past the dots.
local function appendDotsOutline(
    elements,
    pillVisible,
    count
)
    if not pillVisible then
        return
    end
    elements[#elements + 1] = {
        type = 'rectangle',
        action = 'stroke',
        -- Stroke it red, apart from the cyan dots band it shares its top and sides with; draw it first so the cyan lands on top there.
        strokeColor = { red = 1, green = 0, blue = 0, alpha = 1 },
        strokeWidth = 1,
        -- Trace the whole canvas, so its edges show even where the tint fades into what's behind it.
        frame = {
            x = 0,
            y = 0,
            w = pageDotsSize(count).w,
            h = pageDotsSize(count).h,
        },
    }
    elements[#elements + 1] = {
        type = 'rectangle',
        action = 'stroke',
        -- Stroke it yellow, apart from the red and cyan boxes; draw it before the cyan so the cyan lands on top where they share edges.
        strokeColor = { red = 1, green = 1, blue = 0, alpha = 1 },
        strokeWidth = 1,
        frame = pageDotsBadgeFrame(count),
    }
    elements[#elements + 1] = {
        type = 'rectangle',
        action = 'stroke',
        -- Stroke it cyan, apart from the magenta canvas tint.
        strokeColor = { red = 0, green = 1, blue = 1, alpha = 1 },
        strokeWidth = 1,
        frame = pageDotsBandFrame(count),
    }
end

-- Return the slot under (`x`, `y`) among `count` dots, or nil past either end.
local function dotSlotAt(
    x,
    y,
    count
)
    local slot
    if isEnabled('vertical_dots') then
        -- Count the strip beneath a dot as its own, where its underline and follow-order letter sit.
        slot = math.floor((y - DOTS_PADDING) / (DOT_SIZE + DOT_GAP)) + 1
    else
        -- Count half the gap on each side of a dot as its own.
        slot = math.floor((x - DOTS_PADDING + DOT_GAP / 2) / (DOT_SIZE + DOT_GAP)) + 1
    end
    if slot < 1 then
        return nil
    elseif slot > count then
        return nil
    end
    return slot
end

local function hoverFrameElement(center)
    local frame
    if isEnabled('vertical_dots') then
        -- Take in the strip beneath the dot, where its underline and follow-order letter sit.
        frame = {
            x = HOVER_FRAME_MARGIN,
            y = center.y - DOT_SIZE / 2 - HOVER_FRAME_MARGIN,
            w = TITLE_BAR_HEIGHT - 2 * HOVER_FRAME_MARGIN,
            h = DOT_SIZE + DOT_GAP,
        }
    else
        local halfWidth = DOT_SIZE / 2 + HOVER_FRAME_SIDE_PADDING
        frame = {
            x = center.x - halfWidth,
            y = HOVER_FRAME_MARGIN,
            w = 2 * halfWidth,
            h = HORIZONTAL_DOTS_HEIGHT - 2 * HOVER_FRAME_MARGIN,
        }
    end
    return {
        type = 'rectangle',
        action = 'stroke',
        strokeColor = HOVER_FRAME_COLOR,
        strokeWidth = HOVER_FRAME_WIDTH,
        roundedRectRadii = { xRadius = HOVER_FRAME_RADIUS, yRadius = HOVER_FRAME_RADIUS },
        frame = frame,
    }
end

-- Write the digit of the Ctrl+N key that reaches the dot at `slot` inside the dot, on top of whatever it holds.
local function appendHotkey(
    elements,
    slot,
    slotHotkeys
)
    local digit = slotHotkeys[slot]
    if digit == nil then
        return
    end
    local center = pageDotCenter(slot)
    elements[#elements + 1] = {
        type = 'text',
        text = tostring(digit),
        textColor = HOTKEY_COLOR,
        textFont = 'Menlo',
        textSize = HOTKEY_TEXT_SIZE,
        textAlignment = 'center',
        frame = { x = center.x - DOT_SIZE / 2, y = center.y - HOTKEY_TEXT_HEIGHT / 2, w = DOT_SIZE, h = HOTKEY_TEXT_HEIGHT },
    }
end

-- Draw one dot per Space in `color` on a pill, filling the dot at `index`, framing the one at `hoverSlot` and labeling each with its key in `slotHotkeys`.
local function layoutPageDots(
    dots,
    index,
    count,
    color,
    pillVisible,
    hoverSlot,
    slotHotkeys
)
    local elements = { pageDotsPill(pillVisible), pageDotsBand(count) }
    appendDotsBottomEdge(elements, pillVisible, count)
    appendDotsOutline(elements, pillVisible, count)
    -- Draw the dots fully opaque, so they hold up against glare.
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
        appendHotkey(elements, position, slotHotkeys)
    end
    if hoverSlot ~= nil then
        elements[#elements + 1] = hoverFrameElement(pageDotCenter(hoverSlot))
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

-- Draw the hint fully opaque, so it holds up against glare the same as the dots.
local function layoutSwipeHint(
    hint,
    color,
    style
)
    local opaque = { red = color.red, green = color.green, blue = color.blue, alpha = 1 }
    -- Drop the last style's elements from the end, since styles draw different counts and a leftover would show over the new one.
    while #hint > 0 do
        hint[#hint] = nil
    end
    if style == 'block' then
        hint[1] = { type = 'rectangle', action = 'fill', fillColor = opaque }
        return
    elseif style == 'double' then
        -- Stroke both outlines before either chevron, so the second outline never cuts across the first chevron.
        local doubleInset = SWIPE_HINT.DOUBLE_OUTLINE_WIDTH / 2
        local function chevronAt(left)
            return {
                { x = left, y = doubleInset },
                { x = left + SWIPE_HINT.DOUBLE_CHEVRON_DEPTH, y = SWIPE_HINT.HEIGHT / 2 },
                { x = left, y = SWIPE_HINT.HEIGHT - doubleInset },
            }
        end
        local chevrons = {
            chevronAt(doubleInset),
            chevronAt(doubleInset + SWIPE_HINT.DOUBLE_SPACING),
        }
        for _, points in ipairs(chevrons) do
            hint[#hint + 1] = line(points, SWIPE_HINT.OUTLINE_COLOR, SWIPE_HINT.DOUBLE_OUTLINE_WIDTH)
        end
        for _, points in ipairs(chevrons) do
            hint[#hint + 1] = line(points, opaque, SWIPE_HINT.DOUBLE_CHEVRON_WIDTH)
        end
        return
    elseif style == 'tab' then
        -- Run the pill past the canvas's right side, so only its left corners round and it sits flush on the screen edge.
        hint[1] = {
            type = 'rectangle',
            action = 'fill',
            fillColor = SWIPE_HINT.TAB_COLOR,
            frame = { x = 0, y = 0, w = SWIPE_HINT.TAB_WIDTH + SWIPE_HINT.TAB_RADIUS, h = SWIPE_HINT.HEIGHT },
            roundedRectRadii = { xRadius = SWIPE_HINT.TAB_RADIUS, yRadius = SWIPE_HINT.TAB_RADIUS },
        }
        local left = (SWIPE_HINT.TAB_WIDTH - SWIPE_HINT.TAB_CHEVRON_DEPTH) / 2
        local tabMiddle = SWIPE_HINT.HEIGHT / 2
        hint[2] = line({
            { x = left, y = tabMiddle - SWIPE_HINT.TAB_CHEVRON_HEIGHT / 2 },
            { x = left + SWIPE_HINT.TAB_CHEVRON_DEPTH, y = tabMiddle },
            { x = left, y = tabMiddle + SWIPE_HINT.TAB_CHEVRON_HEIGHT / 2 },
        }, opaque, SWIPE_HINT.TAB_CHEVRON_WIDTH)
        return
    elseif style == 'large' then
        -- Inset by half the outline's stroke on every side, so the round caps stay inside the canvas.
        local largeInset = SWIPE_HINT.LARGE_OUTLINE_WIDTH / 2
        local largePoints = {
            { x = largeInset, y = largeInset },
            { x = largeInset + SWIPE_HINT.LARGE_CHEVRON_DEPTH, y = SWIPE_HINT.HEIGHT / 2 },
            { x = largeInset, y = SWIPE_HINT.HEIGHT - largeInset },
        }
        hint[1] = line(largePoints, SWIPE_HINT.OUTLINE_COLOR, SWIPE_HINT.LARGE_OUTLINE_WIDTH)
        hint[2] = line(largePoints, opaque, SWIPE_HINT.LARGE_CHEVRON_WIDTH)
        return
    end
    -- Stroke the outline first, wider by its width on each side, so the chevron drawn over it leaves a black rim.
    local outlineWidth = SWIPE_HINT.CHEVRON_WIDTH + 2 * SWIPE_HINT.OUTLINE_WIDTH
    -- Point the chevron at the screen edge, inset by half the outline's stroke so the round caps stay inside the canvas.
    local inset = outlineWidth / 2
    local middle = SWIPE_HINT.HEIGHT / 2
    local points = {
        { x = inset, y = middle - SWIPE_HINT.CHEVRON_HEIGHT / 2 },
        { x = SWIPE_HINT.WIDTH - inset, y = middle },
        { x = inset, y = middle + SWIPE_HINT.CHEVRON_HEIGHT / 2 },
    }
    hint[1] = line(points, SWIPE_HINT.OUTLINE_COLOR, outlineWidth)
    hint[2] = line(points, opaque, SWIPE_HINT.CHEVRON_WIDTH)
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

-- Return the faint ring a busy dot's arc circles.
local function busyTrackElement(center)
    return ring(center, RING_RADIUS, withAlpha(SESSION_STATE_COLORS.busy, 0.3), RING_WIDTH)
end

-- Return the bright arc that circles a busy dot's track.
local function busyArcElement(
    center,
    seconds
)
    local start = phaseOf(seconds, ORBIT_SECONDS) * 360
    return arc(center, RING_RADIUS, SESSION_STATE_COLORS.busy, start, start + 100)
end

-- Circle a bright arc around a faint ring.
local function busyElements(center, seconds)
    return {
        busyTrackElement(center),
        busyArcElement(center, seconds),
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

-- Draw a check inside the ring unless `labeled`, whose hotkey digit takes the middle, rippling a ping out from it while `pingProgress` runs from 0 to 1.
local function readyElements(
    center,
    pingProgress,
    labeled
)
    local color = SESSION_STATE_COLORS.ready
    local elements = { ring(center, RING_RADIUS, color, RING_WIDTH) }
    if not labeled then
        -- Grow the check with the dot; its points were drawn for a 20-point dot.
        local scale = DOT_SIZE / 20
        elements[#elements + 1] = line({
            { x = center.x - 3.5 * scale, y = center.y + 0.5 * scale },
            { x = center.x - 1 * scale, y = center.y + 3 * scale },
            { x = center.x + 3.5 * scale, y = center.y - 2.5 * scale },
        }, color, 2 * scale)
    end
    if pingProgress ~= nil then
        elements[#elements + 1] = ring(center, RING_RADIUS + pingProgress * 8, withAlpha(color, 0.8 * (1 - pingProgress)), 2)
    end
    return elements
end

-- Draw a session ring in gray, so a session whose state isn't known yet shows up without claiming to be busy.
local function pendingElements(style, center, seconds)
    local color = SESSION_STATE_COLORS.pending
    if style == 'dashed' then
        local dashed = ring(center, RING_RADIUS, color, RING_WIDTH)
        dashed.strokeDashPattern = { 3, 3 }
        return { dashed }
    elseif style == 'dot' then
        return {
            ring(center, RING_RADIUS, withAlpha(color, 0.3), RING_WIDTH),
            disc(center, 2.5, color),
        }
    elseif style == 'pulse' then
        return { ring(center, RING_RADIUS, withAlpha(color, 0.25 + 0.75 * wave(phaseOf(seconds, 1.5))), RING_WIDTH) }
    end
    error('unknown pending style: ' .. style)
end

-- Draw a Space with no session as a gray ring as thick as the session states' rings, so every ring in the row reads at one weight.
local function noneElements(center)
    return { ring(center, RING_RADIUS, SESSION_STATE_COLORS.none, RING_WIDTH) }
end

local function stateElements(
    state,
    center,
    seconds,
    pingProgress,
    labeled
)
    if state == 'busy' then
        return busyElements(center, seconds)
    elseif state == 'decision' then
        return decisionElements(styleOf('decision_style'), center, seconds)
    elseif state == 'ready' then
        return readyElements(center, pingProgress, labeled)
    elseif state == 'pending' then
        return pendingElements(styleOf('pending_style'), center, seconds)
    elseif state == 'none' then
        return noneElements(center)
    end
    error('unknown session state: ' .. state)
end

-- Mark `elements`, drawn around `center`, as the focused Space's in the focus_marker style.
local function addFocusMarker(elements, center)
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
        if isEnabled('vertical_dots') then
            -- Point up at the dot from the underline's slot, since a line under a dot in a column reads as a divider.
            local tip = center.y + DOT_SIZE / 2 + 3
            local base = tip + 7
            elements[#elements + 1] = {
                type = 'segments',
                action = 'fill',
                closed = true,
                coordinates = { { x = center.x, y = tip }, { x = center.x + 6, y = base }, { x = center.x - 6, y = base } },
                fillColor = FOCUS_MARK_COLOR,
            }
        else
            local y = center.y + DOT_SIZE / 2 + FOLLOW_ORDER_MIDLINE
            elements[#elements + 1] = line({ { x = center.x - 9, y = y }, { x = center.x + 9, y = y } }, FOCUS_MARK_COLOR, 2.5)
        end
    else
        error('unknown focus marker: ' .. marker)
    end
end

-- Mark the dot of the Space you're on the way the focus_marker style says, on top of its state.
local function focusedElements(
    state,
    center,
    seconds,
    pingProgress,
    labeled
)
    local elements = stateElements(state, center, seconds, pingProgress, labeled)
    addFocusMarker(elements, center)
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

-- Return whether the Space's dot moves: an orbit, a decision's beat, a pending pulse or a ping still rippling.
local function dotAnimates(
    space,
    seconds
)
    local state = sessionStateOf(space)
    if state == 'busy' then
        return true
    elseif state == 'decision' then
        return true
    elseif pingProgressOf(space, seconds) ~= nil then
        return true
    elseif state == 'pending' then
        if styleOf('pending_style') == 'pulse' then
            return true
        end
    end
    return false
end

-- Return whether any dot in the row moves.
local function sessionDotsAnimate(
    spaces,
    seconds
)
    for _, space in ipairs(spaces) do
        if dotAnimates(space, seconds) then
            return true
        end
    end
    return false
end

-- Return the set of slots whose dot moves, counting the home triangle as slot 1.
local function movingSlots(
    spaces,
    seconds
)
    local moving = {}
    for position, space in ipairs(spaces) do
        if dotAnimates(space, seconds) then
            moving[position + 1] = true
        end
    end
    return moving
end

-- Draw the home Space's triangle, so the row starts where the swipe does without the home Space reading as a session.
local function homeElements(center)
    -- Inset the corners by half the stroke, so the thick line stays inside the dot's slot.
    local half = DOT_SIZE / 2 - HOME_TRIANGLE_WIDTH / 2
    local triangle = line({
        { x = center.x, y = center.y - half },
        { x = center.x + half, y = center.y + half * 0.8 },
        { x = center.x - half, y = center.y + half * 0.8 },
        -- Retrace the first side, so the closing corner gets the same round join as the others.
        { x = center.x, y = center.y - half },
        { x = center.x + half, y = center.y + half * 0.8 },
    }, SESSION_STATE_COLORS.none, HOME_TRIANGLE_WIDTH)
    return { triangle }
end

-- Write a dot's place in the follow order centered beneath it, in the slot the focus underline uses; the focused dot is never ranked, so the two never meet.
local function followOrderElement(center, rank)
    local textHeight = BADGE_TEXT_HEIGHT
    return {
        type = 'text',
        text = string.char(string.byte('A') + rank - 1),
        textColor = FOCUS_MARK_COLOR,
        textFont = FOLLOW_ORDER_FONT,
        textSize = FOLLOW_ORDER_TEXT_SIZE,
        textAlignment = 'center',
        frame = { x = center.x - DOT_SIZE / 2, y = center.y + DOT_SIZE / 2, w = DOT_SIZE, h = textHeight },
    }
end

-- Draw the ring of the Space at `position` in the row showing its session's state, marking it when it's the ring at `index`; draw its ping only when `animate`, since a still frame would freeze one mid-ripple.
local function sessionDotElements(
    index,
    position,
    space,
    seconds,
    animate,
    slotHotkeys
)
    -- Shift each ring one slot past the home triangle.
    local center = pageDotCenter(position + 1)
    local state = sessionStateOf(space)
    local pingProgress = nil
    if animate then
        pingProgress = pingProgressOf(space, seconds)
    end
    local labeled = slotHotkeys[position + 1] ~= nil
    if position == index then
        return focusedElements(state, center, seconds, pingProgress, labeled)
    end
    return stateElements(state, center, seconds, pingProgress, labeled)
end

-- Remove every element from `canvas`, skipping the repaint when it's already empty.
local function clearCanvas(canvas)
    while #canvas > 0 do
        canvas[#canvas] = nil
    end
end

-- Return whether `a` and `b` hold the same value, comparing tables key by key.
local function sameValue(
    a,
    b
)
    if a == b then
        return true
    elseif type(a) ~= 'table' then
        return false
    elseif type(b) ~= 'table' then
        return false
    end
    for key, value in pairs(a) do
        if not sameValue(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

-- Return whether every element in `elements` has the same type and keys as its counterpart in `previous`.
local function sameElementShapes(
    previous,
    elements
)
    if #previous ~= #elements then
        return false
    end
    for position, element in ipairs(elements) do
        local old = previous[position]
        if old.type ~= element.type then
            return false
        end
        for key in pairs(old) do
            if element[key] == nil then
                return false
            end
        end
        for key in pairs(element) do
            if old[key] == nil then
                return false
            end
        end
    end
    return true
end

-- Move `canvas` from `previous` to `elements` by setting only the attributes that changed, which costs a fraction of replacing every element.
-- Replace them all when an element came, went or changed shape, or the canvas no longer holds `previous`.
local function updateElements(
    canvas,
    previous,
    elements
)
    if previous == nil then
        canvas:replaceElements(elements)
        return
    elseif #canvas ~= #previous then
        canvas:replaceElements(elements)
        return
    elseif not sameElementShapes(previous, elements) then
        canvas:replaceElements(elements)
        return
    end
    for position, element in ipairs(elements) do
        local old = previous[position]
        for key, value in pairs(element) do
            if not sameValue(old[key], value) then
                canvas[position][key] = value
            end
        end
    end
end

-- Draw each moving ring in `moving` with its hotkey label on the row's motion canvas, so an animation frame repaints only those.
-- Return the elements drawn, for the next frame to update from `previous`.
local function layoutSessionDotsMotion(
    motion,
    previous,
    index,
    spaces,
    seconds,
    moving,
    slotHotkeys
)
    local elements = {}
    for position, space in ipairs(spaces) do
        if not moving[position + 1] then
            -- Skip a still dot, which the still row draws.
        elseif sessionStateOf(space) == 'busy' then
            -- Draw only the arc, since the still row holds the busy dot's track, focus mark and digit.
            elements[#elements + 1] = busyArcElement(pageDotCenter(position + 1), seconds)
        else
            for _, element in ipairs(sessionDotElements(index, position, space, seconds, true, slotHotkeys)) do
                elements[#elements + 1] = element
            end
            -- Label the ring here rather than on the still row, so the digit stays on top of it.
            appendHotkey(elements, position + 1, slotHotkeys)
        end
    end
    if #elements == 0 then
        clearCanvas(motion)
        return elements
    end
    for _, element in ipairs(elements) do
        if element.frame == nil then
            element.frame = UNDRAWN_FRAME
        end
    end
    updateElements(motion, previous, elements)
    return elements
end

-- Draw the home triangle, then one ring per Space in `spaces` showing its session's state, marking the ring at `index` and badging each ranked in `followOrder`.
-- Leave each slot in `moving` empty for the motion canvas to draw.
-- Frame the slot at `hoverSlot` and label each slot with its key in `slotHotkeys`, counting the home triangle as slot 1.
local function layoutSessionDots(
    dots,
    index,
    spaces,
    followOrder,
    pillVisible,
    seconds,
    moving,
    hoverSlot,
    slotHotkeys
)
    -- Count the home triangle too.
    local elements = { pageDotsPill(pillVisible), pageDotsBand(#spaces + 1) }
    appendDotsBottomEdge(elements, pillVisible, #spaces + 1)
    appendDotsOutline(elements, pillVisible, #spaces + 1)
    local home = homeElements(pageDotCenter(1))
    -- Mark the home triangle while you're on the home Space, which sits before the first ring.
    if index == 0 then
        addFocusMarker(home, pageDotCenter(1))
    end
    for _, element in ipairs(home) do
        elements[#elements + 1] = element
    end
    appendHotkey(elements, 1, slotHotkeys)
    for position, space in ipairs(spaces) do
        local moves = moving[position + 1] == true
        -- Hold a busy dot's track, focus mark and digit here even while it moves, since only its arc changes and the arc never crosses the digit.
        local busyMoves = moves and sessionStateOf(space) == 'busy'
        if not moves then
            for _, element in ipairs(sessionDotElements(index, position, space, seconds, false, slotHotkeys)) do
                elements[#elements + 1] = element
            end
        elseif busyMoves then
            local center = pageDotCenter(position + 1)
            local track = { busyTrackElement(center) }
            if position == index then
                addFocusMarker(track, center)
            end
            for _, element in ipairs(track) do
                elements[#elements + 1] = element
            end
        end
        if followOrder[space] ~= nil then
            elements[#elements + 1] = followOrderElement(pageDotCenter(position + 1), followOrder[space])
        end
        if not moves then
            appendHotkey(elements, position + 1, slotHotkeys)
        elseif busyMoves then
            appendHotkey(elements, position + 1, slotHotkeys)
        end
    end
    if hoverSlot ~= nil then
        elements[#elements + 1] = hoverFrameElement(pageDotCenter(hoverSlot))
    end
    dots:replaceElements(elements)
end

-- Return a key that changes whenever a session row's still frame would, so an unchanged row skips its redraw.
local function sessionDotsKey(
    index,
    spaces,
    followOrder,
    pillVisible,
    hoverSlot,
    moving
)
    local parts = {
        index,
        tostring(pillVisible),
        tostring(hoverSlot),
        styleOf('decision_style'),
        styleOf('pending_style'),
        styleOf('focus_marker'),
        tostring(isEnabled('vertical_dots')),
    }
    for position, space in ipairs(spaces) do
        parts[#parts + 1] = sessionStateOf(space) .. ':' .. tostring(followOrder[space]) .. ':' .. tostring(moving[position + 1] == true)
    end
    return table.concat(parts, ' ')
end

-- Redraw a pair's still row only when its key changed, then its moving rings, from what its last placement recorded.
local function drawSessionDots(
    pair,
    pillVisible,
    seconds
)
    local moving = movingSlots(pair.sessionSpaces, seconds)
    local key = sessionDotsKey(pair.sessionIndex, pair.sessionSpaces, pair.followOrder, pillVisible, pair.hoverSlot, moving)
    if pair.sessionKey ~= key then
        layoutSessionDots(
            pair.dots,
            pair.sessionIndex,
            pair.sessionSpaces,
            pair.followOrder,
            pillVisible,
            seconds,
            moving,
            pair.hoverSlot,
            pair.slotHotkeys
        )
        pair.sessionKey = key
    end
    pair.motionElements = layoutSessionDotsMotion(
        pair.dotsMotion,
        pair.motionElements,
        pair.sessionIndex,
        pair.sessionSpaces,
        seconds,
        moving,
        pair.slotHotkeys
    )
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

-- Return each Space's most urgent session state, from the state words the hooks record, the window of the session it came from and when that state was recorded.
local function readSessionStates()
    local states = {}
    local windows = {}
    local changedAt = {}
    if hs.fs.attributes(SESSION_STATE_DIR) == nil then
        return states, windows, changedAt
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
                    changedAt[space] = hs.fs.attributes(SESSION_STATE_DIR .. fileName, 'modification')
                elseif SESSION_STATE_URGENCY[state] > SESSION_STATE_URGENCY[states[space]] then
                    states[space] = state
                    windows[space] = windowId
                    changedAt[space] = hs.fs.attributes(SESSION_STATE_DIR .. fileName, 'modification')
                end
            end
        end
    end
    return states, windows, changedAt
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

-- Switch to `space` by focusing its session's window, falling back to the Space itself when it has no session or that window isn't reachable from here.
local function focusSpace(
    space,
    windowId
)
    local window = nil
    if windowId ~= nil then
        window = hs.window.get(windowId)
    end
    if window then
        window:focus()
    else
        hs.spaces.gotoSpace(space)
    end
end

local function followTo(space, windowId, now)
    lastFollowAt = now
    focusSpace(space, windowId)
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

-- Return what a Space shows while its ready settles: a turn's orbit keeps spinning, anything else waits as pending.
local function heldReadyState(space)
    if sessionStates == nil then
        return 'pending'
    elseif sessionStates[space] == 'busy' then
        return 'busy'
    elseif sessionStates[space] == 'decision' then
        return 'busy'
    end
    return 'pending'
end

-- Hold back a ready not yet settled, so a stop a Stop hook blocks never draws a check, pings or follows.
local function settleReadyStates(
    states,
    changedAt,
    now
)
    for space, state in pairs(states) do
        if state ~= 'ready' then
            readySince[space] = nil
        elseif readySince[space] == nil and sessionStates == nil then
            -- Start the clock at the state file's write, so an old check skips its ping but a fresh one still waits.
            -- Round the whole-second write time up; count a file gone mid-read as fresh.
            if changedAt[space] == nil then
                readySince[space] = now
            else
                readySince[space] = changedAt[space] + 1
            end
            if now - readySince[space] < READY_SETTLE_SECONDS then
                states[space] = heldReadyState(space)
            end
        elseif readySince[space] == nil then
            readySince[space] = now
            states[space] = heldReadyState(space)
        elseif now - readySince[space] < READY_SETTLE_SECONDS then
            states[space] = heldReadyState(space)
        end
    end
    -- Forget the Spaces whose session went away.
    for space in pairs(readySince) do
        if states[space] == nil then
            readySince[space] = nil
        end
    end
end

-- Redraw when the soonest held-back ready settles, since no state file write marks that moment.
local function scheduleReadySettle(now)
    if readySettleTimer then
        readySettleTimer:stop()
        readySettleTimer = nil
    end
    local soonest = nil
    for _, since in pairs(readySince) do
        local remaining = since + READY_SETTLE_SECONDS - now
        if remaining <= 0 then
            -- Skip a ready that already settled.
        elseif soonest == nil then
            soonest = remaining
        elseif remaining < soonest then
            soonest = remaining
        end
    end
    if soonest ~= nil then
        readySettleTimer = hs.timer.doAfter(soonest, function()
            readySettleTimer = nil
            redrawSessionDots()
        end)
    end
end

-- Re-read every session's state, starting a ping on each Space that just turned ready and following it there when you're away, or once you are.
local function refreshSessionStates()
    local states, windows, changedAt = readSessionStates()
    local rawStates = {}
    for space, state in pairs(states) do
        rawStates[space] = state
    end
    sessionReading = { states = rawStates, windows = windows, changedAt = changedAt }
    local now = hs.timer.secondsSinceEpoch()
    settleReadyStates(states, changedAt, now)
    if sessionStates ~= nil then
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
    scheduleReadySettle(now)
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
    elseif spaceTypes.of(spaces[index]) ~= 'fullscreen' then
        return false
    elseif spaceTypes.of(spaces[index - 1]) == 'fullscreen' then
        return false
    end
    return true
end

-- Return whether the focused Space gets a right bar, which marks the last Space, where a swipe right goes no further; desktops stay clear so bars mark only the full-screen apps.
local function showsRightBar(focused, index, count)
    if spaceTypes.of(focused) ~= 'fullscreen' then
        return false
    elseif index ~= count then
        return false
    end
    return true
end

-- Return whether the focused Space gets a bottom band; desktops stay clear, the same as for the right bar.
local function showsBottomBar(focused)
    if not isEnabled('bottom_bar') then
        return false
    elseif spaceTypes.of(focused) ~= 'fullscreen' then
        return false
    end
    return true
end

-- Return whether the focused Space gets a top band; desktops stay clear, the same as for the right bar.
local function showsTopBar(focused)
    if not isEnabled('top_bar') then
        return false
    elseif spaceTypes.of(focused) ~= 'fullscreen' then
        return false
    end
    return true
end

-- Return whether the focused Space gets the swipe hint, which marks a desktop with a Space beyond it; full-screen Spaces have their dots for that.
local function showsSwipeHint(focused, index, count)
    if not isEnabled('swipe_hint') then
        return false
    elseif spaceTypes.of(focused) == 'fullscreen' then
        return false
    elseif index == count then
        return false
    end
    return true
end

-- Return whether the focused Space gets the dots; desktops stay clear, the same as for the right bar, unless desktop_dots is on.
local function showsPageDots(focused)
    if not isEnabled('page_dots') then
        return false
    elseif spaceTypes.of(focused) == 'fullscreen' then
        return true
    elseif isEnabled('desktop_dots') then
        return true
    end
    return false
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
    pair.top:delete()
    pair.bottom:delete()
    pair.swipeHint:delete()
    pair.dots:delete()
    pair.dotsMotion:delete()
    pair.countdown:delete()
end

-- Drop the pairs of Spaces that no longer exist.
local function pruneEdgeBars()
    pinCanvasesToSpaces.pruneClosedSpaces(edgeBarsBySpace, deleteEdgeBarPair)
end

-- Return the Spaces among a screen's `screenSpaces` that get a session ring, in row order.
local function sessionDotSpaces(screenSpaces)
    -- Leave the home Space out; it's where the swipe starts, not a page worth a ring, so it gets the home triangle instead.
    local spaces = {}
    for position, space in ipairs(screenSpaces) do
        if position > 1 then
            spaces[#spaces + 1] = space
        end
    end
    return spaces
end

-- Rank hop targets from a given read; assigned beside hopOrder below, which ranks a fresh one.
local hopOrderFrom

-- Return each of `spaces` mapped to its place in line for a hop off `closing`, the order follow_closed_full_screen_space walks; empty while follow_order is off.
local function followOrderOf(spaces, closing)
    local order = {}
    if not isEnabled('follow_order') then
        return order
    end
    -- Rank the refresh's read rather than a fresh one per Space; fall back to reading when no refresh has run yet.
    local reading = sessionReading
    if reading == nil then
        local states, windows, changedAt = readSessionStates()
        reading = { states = states, windows = windows, changedAt = changedAt }
    end
    for rank, next in ipairs(hopOrderFrom(reading, spaces, closing)) do
        if rank > FOLLOW_ORDER_LIMIT then
            break
        end
        order[next.space] = rank
    end
    return order
end

-- Fit a pair's bars, hint and dots flush to the edges of `screen`, for the Space at `index` of `count` on it.
-- Return whether display_alternate_clock holds the top-right corner of a full-screen Space or, unless `fullScreen`, a desktop, which it does beside a row of dots there.
local function clockHoldsCorner(fullScreen)
    if not isEnabled('page_dots') then
        return false
    elseif isEnabled('vertical_dots') then
        return false
    elseif fullScreen then
        return true
    elseif isEnabled('desktop_dots') then
        return true
    end
    return false
end

-- Return the width display_alternate_clock takes in the top-right corner of `pair`'s Space, so the dots can sit left of it.
local function cornerClockWidth(pair)
    if clockHoldsCorner(pair.fullScreen) then
        return alternateClockWidth()
    end
    return 0
end

-- Take the screen's Spaces in swipe order as `screenSpaces` from the caller, which already read them, since each read copies every display's Space list.
local function placeEdgeBars(
    pair,
    index,
    count,
    screen,
    screenSpaces
)
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
        layoutEdgeBar(pair.left, pair.color, barFrame.h)
        pair.leftHeight = barFrame.h
    end
    if pair.rightHeight ~= rightBarFrame.h then
        layoutEdgeBar(pair.right, pair.color, rightBarFrame.h)
        pair.rightHeight = rightBarFrame.h
    end
    pair.left:frame(edgeBarFrame(barFrame, barFrame.x))
    pair.right:frame(edgeBarFrame(rightBarFrame, rightBarFrame.x + rightBarFrame.w - EDGE_BAR_WIDTH))
    pair.bottom:frame({ x = frame.x, y = frame.y + frame.h - BAND_HEIGHT, w = frame.w, h = BAND_HEIGHT })
    -- Redraw the hint only when its style changed, the same as the bars' height check.
    local swipeHintStyle = styleOf('swipe_hint_style')
    if pair.swipeHintStyle ~= swipeHintStyle then
        layoutSwipeHint(pair.swipeHint, pair.color, swipeHintStyle)
        pair.swipeHintStyle = swipeHintStyle
    end
    local swipeHintWidth = SWIPE_HINT.WIDTH
    if swipeHintStyle == 'tab' then
        swipeHintWidth = SWIPE_HINT.TAB_WIDTH
    elseif swipeHintStyle == 'large' then
        swipeHintWidth = SWIPE_HINT.LARGE_WIDTH
    elseif swipeHintStyle == 'double' then
        swipeHintWidth = SWIPE_HINT.DOUBLE_WIDTH
    end
    pair.swipeHint:frame({
        x = frame.x + frame.w - swipeHintWidth,
        y = frame.y + (frame.h - SWIPE_HINT.HEIGHT) / 2,
        w = swipeHintWidth,
        h = SWIPE_HINT.HEIGHT,
    })
    -- Redraw the dots only when the Space moved, the count changed or the pill or column was toggled, the same as the bars' height check.
    local pillVisible = isEnabled('page_dots_pill')
    local vertical = isEnabled('vertical_dots')
    local dotsCount = count
    -- Map each dot slot to its Space for a click; both rows run in swipe order, the session row's home triangle standing in for the first Space.
    pair.dotSpaces = screenSpaces
    -- Label each slot with the Ctrl+N key that reaches its Space.
    local keys = numberedSpaceKeys.keysFor(screenSpaces)
    pair.slotHotkeys = {}
    for slot, space in ipairs(screenSpaces) do
        pair.slotHotkeys[slot] = keys[space]
    end
    if isEnabled('session_state') then
        local spaces = sessionDotSpaces(screenSpaces)
        local rowIndex = index - 1
        local followOrder = followOrderOf(screenSpaces, screenSpaces[index])
        pair.sessionIndex = rowIndex
        pair.sessionSpaces = spaces
        pair.followOrder = followOrder
        -- Count the home triangle too.
        dotsCount = #spaces + 1
        drawSessionDots(pair, pillVisible, hs.timer.secondsSinceEpoch())
        -- Forget the plain dots, so turning session_state off redraws them.
        pair.dotsIndex = nil
    elseif pair.dotsIndex ~= index or pair.dotsCount ~= count or pair.dotsPill ~= pillVisible or pair.dotsHover ~= pair.hoverSlot or pair.dotsVertical ~= vertical then
        layoutPageDots(pair.dots, index, count, pair.color, pillVisible, pair.hoverSlot, pair.slotHotkeys)
        pair.dotsIndex = index
        pair.dotsCount = count
        pair.dotsPill = pillVisible
        pair.dotsHover = pair.hoverSlot
        pair.dotsVertical = vertical
        pair.sessionKey = nil
        -- Drop any moving rings left from session_state, which the plain dots replace.
        clearCanvas(pair.dotsMotion)
    end
    local dotsSize = pageDotsSize(dotsCount)
    -- Sit the dots flush against the screen's right edge, or left of the clock where it holds the corner.
    local dotsX = frame.x + frame.w - cornerClockWidth(pair) - dotsSize.w
    -- Stop the top band where the dots' canvas starts, so it doesn't run across the dots.
    local topBandWidth = frame.w
    if isEnabled('page_dots') then
        topBandWidth = dotsX - frame.x
    end
    pair.top:frame({ x = frame.x, y = frame.y, w = topBandWidth, h = BAND_HEIGHT })
    local dotsFrame = {
        x = dotsX,
        y = frame.y,
        w = dotsSize.w,
        h = dotsSize.h,
    }
    pair.dots:frame(dotsFrame)
    pair.dotsMotion:frame(dotsFrame)
    -- Line the countdown up with the first dot's band, so it reads as part of the row.
    local firstBand = pageDotsBandFrame(1)
    pair.countdown:frame({
        x = dotsX - COUNTDOWN_WIDTH,
        y = frame.y + firstBand.y,
        w = COUNTDOWN_WIDTH,
        h = firstBand.h,
    })
    if pillVisible then
        pair.countdown[2].strokeColor = COUNTDOWN_OUTLINE_COLOR
    else
        pair.countdown[2].strokeColor = COUNTDOWN_OUTLINE_HIDDEN_COLOR
    end
end

-- Redraw a pair's dots in place from what its last placement recorded, for a hover that moved without the Space changing.
local function redrawPageDots(pair)
    local pillVisible = isEnabled('page_dots_pill')
    if isEnabled('session_state') then
        drawSessionDots(pair, pillVisible, hs.timer.secondsSinceEpoch())
        return
    end
    layoutPageDots(pair.dots, pair.dotsIndex, pair.dotsCount, pair.color, pillVisible, pair.hoverSlot, pair.slotHotkeys)
    pair.dotsPill = pillVisible
    pair.dotsHover = pair.hoverSlot
end

-- Frame the dot at `slot`, or none when nil, redrawing only on a change.
local function hoverPageDot(
    pair,
    slot
)
    if pair.hoverSlot == slot then
        return
    end
    pair.hoverSlot = slot
    redrawPageDots(pair)
end

-- Return the dot slot under the pointer, or nil when the pointer is off the row.
local function pointerPageDotSlot(pair)
    local pointer = hs.mouse.absolutePosition()
    local frame = pair.dots:frame()
    if pointer.x < frame.x then
        return nil
    elseif pointer.x >= frame.x + frame.w then
        return nil
    elseif pointer.y < frame.y then
        return nil
    elseif pointer.y >= frame.y + frame.h then
        return nil
    end
    return dotSlotAt(pointer.x - frame.x, pointer.y - frame.y, #pair.dotSpaces)
end

-- Frame the dot under the pointer as it moves and jump to the Space of a clicked dot.
local function handlePageDotsMouse(
    pair,
    message,
    x,
    y
)
    if message == 'mouseExit' then
        hoverPageDot(pair, nil)
    elseif message == 'mouseEnter' then
        hoverPageDot(pair, dotSlotAt(x, y, #pair.dotSpaces))
    elseif message == 'mouseMove' then
        hoverPageDot(pair, dotSlotAt(x, y, #pair.dotSpaces))
    elseif message == 'mouseUp' then
        local slot = dotSlotAt(x, y, #pair.dotSpaces)
        if slot == nil then
            return
        end
        local space = pair.dotSpaces[slot]
        -- Clear the frame first, since leaving the Space can skip the exit event and strand it for your return.
        hoverPageDot(pair, nil)
        focusSpace(space, sessionWindows[space])
    end
end

-- Give the focused Space its own pair on first visit; only a reorder of Spaces ever flips a pair's visibility.
local function renderEdgeBars(
    index,
    count,
    screen,
    focused,
    screenSpaces
)
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
            top = newBand(color),
            bottom = newBand(color),
            swipeHint = newSwipeHint(),
            dots = newPageDots(),
            dotsMotion = newPageDotsMotion(),
            countdown = newCountdown(),
            color = color,
            cycleColor = cycleColor,
            fullScreen = spaceTypes.of(focused) == 'fullscreen',
        }
        pair.dots:canvasMouseEvents(true, true, true, true)
        pair.dots:mouseCallback(function(_, message, _, x, y)
            handlePageDotsMouse(pair, message, x, y)
        end)
        edgeBarsBySpace[focused] = pair
    end

    placeEdgeBars(pair, index, count, screen, screenSpaces)
    -- Frame whatever dot the pointer rests on as you land, which no mouse event reports when the Space switched under a still pointer.
    hoverPageDot(pair, pointerPageDotSlot(pair))
    local rightVisible = showsRightBar(focused, index, count)
    setEdgeBarVisible(pair.left, startsFullScreenRun(screenSpaces, index))
    setEdgeBarVisible(pair.right, rightVisible)
    setEdgeBarVisible(pair.top, showsTopBar(focused))
    setEdgeBarVisible(pair.bottom, showsBottomBar(focused))
    setEdgeBarVisible(pair.swipeHint, showsSwipeHint(focused, index, count))
    setEdgeBarVisible(pair.dots, showsPageDots(focused))
    setEdgeBarVisible(pair.dotsMotion, showsPageDots(focused))
    setEdgeBarVisible(pair.countdown, showsCountdown(focused))
end

-- Return the pair of each Space on a screen right now whose session dots are showing.
-- Leave off-screen rows still, since repainting each Space's row every frame costs a core; a switch re-places the row it lands on.
local function shownSessionPairs()
    local shown = {}
    if not isEnabled('session_state') then
        return shown
    end
    for _, space in pairs(onScreenSpaces) do
        local pair = edgeBarsBySpace[space]
        if pair == nil then
            -- Skip a Space not visited yet, which has no pair.
        elseif pair.sessionSpaces == nil then
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
        drawSessionDots(pair, pillVisible, seconds)
        if sessionDotsAnimate(pair.sessionSpaces, seconds) then
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
    for i = 2, #COUNTDOWN_COLOR_STOPS do
        local from, to = COUNTDOWN_COLOR_STOPS[i - 1], COUNTDOWN_COLOR_STOPS[i]
        if heat <= to.heat then
            local progress = (heat - from.heat) / (to.heat - from.heat)
            local color = {}
            for channel, start in pairs(from.color) do
                color[channel] = start + (to.color[channel] - start) * progress
            end
            return color
        end
    end
    error('heat past the last color stop: ' .. heat)
end

local function updateCountdowns()
    local now = hs.timer.secondsSinceEpoch()
    local text = countdownText(now)
    local color = countdownColor(now)
    for _, pair in pairs(edgeBarsBySpace) do
        -- Write only what changed, since each write repaints the countdown and an armed one holds still for minutes.
        if pair.countdown:isShowing() then
            if pair.countdownText ~= text then
                pair.countdown[1].text = text
                pair.countdownText = text
            end
            if not sameValue(pair.countdownColor, color) then
                pair.countdown[1].textColor = color
                pair.countdownColor = color
            end
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
    local index, count, screen, focused, screenSpaces = focusedPosition()
    onScreenSpaces = hs.spaces.activeSpaces()
    -- Forget a missed ready once you've seen its Space.
    missedReadyAt[focused] = nil
    renderEdgeBars(index, count, screen, focused, screenSpaces)
    updateAnimation()
    updateCountdownTimer()
    updateCountdowns()
end

-- Return a key that changes whenever the last session read would change a row: each Space's drawn state, and what the follow-order letters rank on.
local function sessionPlacementKey()
    local parts = {}
    for _, space in ipairs(sortedKeys(sessionReading.states)) do
        parts[#parts + 1] = space .. ':' .. sessionStateOf(space) .. ':' .. sessionReading.states[space] .. ':' .. tostring(sessionReading.windows[space])
        -- Rank a Space never seen since the reload by its state file's write time, which every rewrite of the same word still moves.
        if lastSeenAt[space] == nil then
            parts[#parts + 1] = tostring(sessionReading.changedAt[space])
        end
    end
    return table.concat(parts, ' ')
end

-- Move every Space's pair onto its screen's current edges; leave visibility to the next visit, since showing an off-Space canvas can pull it onto this one.
local function placeEveryEdgeBarSet()
    for screenId, spaces in pairs(hs.spaces.allSpaces() or {}) do
        local screen = hs.screen.find(screenId)
        if screen then
            for index, space in ipairs(spaces) do
                local pair = edgeBarsBySpace[space]
                if pair then
                    placeEdgeBars(pair, index, #spaces, screen, spaces)
                end
            end
        end
    end
    if sessionReading ~= nil then
        placedSessionKey = sessionPlacementKey()
    end
end

redrawSessionDots = function()
    if not isEnabled('session_state') then
        return
    end
    refreshSessionStates()
    placeEveryEdgeBarSet()
    updateAnimation()
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
    -- Skip placing every row when the write changed none, as a busy session's rewrite of the same word on each tool call does.
    if sessionPlacementKey() == placedSessionKey then
        return
    end
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

-- Return how far from the screen's right edge display_alternate_clock should end its rows at the screen's top on a full-screen Space or, unless `fullScreen`, a desktop, or nil to leave them below.
-- Sit left of a column of dots on a full-screen Space, reserving the countdown's slot even while it's hidden, so the clock holds still as follow_ready toggles.
function showSpacePosition.clockRightInset(fullScreen)
    if not isEnabled('page_dots') then
        return nil
    elseif clockHoldsCorner(fullScreen) then
        return 0
    elseif not fullScreen then
        return nil
    end
    return pageDotsSize(1).w + COUNTDOWN_WIDTH
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
        writeSetting(name, value)
        return name .. ' ' .. value
    elseif DEFAULT_STYLES[name] ~= nil then
        if not isStyleChoice(name, value) then
            return 'unknown ' .. name .. ': ' .. tostring(value) .. ' (expected one of: ' .. table.concat(STYLE_CHOICES[name], ', ') .. ')'
        end
        writeSetting(name, value)
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

    writeSetting(name, value)
    render()
    -- Re-place the alternate clock, whose spot follows clockRightInset.
    update_clock_position()
    return name .. ' ' .. (value and 'on' or 'off')
end

-- Return which session ring stands for `space` among its screen's `screenSpaces`, the numbering the dots row shows.
local function ringLabel(
    space,
    screenSpaces
)
    for ring, candidate in ipairs(sessionDotSpaces(screenSpaces)) do
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
                return 'Space #' .. index .. ' (' .. ringLabel(space, spaces) .. ')'
            end
        end
    end
    return 'unknown Space ' .. tostring(space)
end

local function indexOf(spaces, space)
    for index, candidate in ipairs(spaces) do
        if candidate == space then
            return index
        end
    end
    return nil
end

-- Return whether a hop off `closing` may land on `space`, whose session shows `state`.
local function isHopTarget(
    space,
    state,
    closing
)
    if space == closing then
        return false
    elseif state ~= 'none' then
        return true
    -- Land on an empty Space only when it's full screen, never the desktop the swipe starts from.
    elseif spaceTypes.of(space) == 'fullscreen' then
        return true
    end
    return false
end

-- Return how a hop picked a Space showing `state`, for the follow log.
local function hopPickedBy(state)
    if state == 'none' then
        return 'empty full screen'
    end
    return state .. ' session'
end

-- Return how far `position` sits from the closing Space at `closingIndex`, counting every Space to its right before any to its left.
local function hopDistance(
    position,
    closingIndex,
    count
)
    if position > closingIndex then
        return position - closingIndex
    end
    return count + closingIndex - position
end

-- Return where a hop off `closing` goes, first choice first, as { space, windowId, pickedBy } among `spaces`, the closing Space's screen.
-- Rank by HOP_STATE_PRIORITY, then by last seen, so a switch lands where your context for its objective is freshest.
-- Rank by last seen rather than by state change: a session started long ago that just finished is already stale in your head.
hopOrderFrom = function(reading, spaces, closing)
    local states = reading.states
    local windows = reading.windows
    local changedAt = reading.changedAt
    local closingIndex = indexOf(spaces, closing) or 0
    local order = {}
    for position, space in ipairs(spaces) do
        local state = states[space] or 'none'
        if isHopTarget(space, state, closing) then
            order[#order + 1] = {
                space = space,
                fullScreen = spaceTypes.of(space) == 'fullscreen',
                windowId = windows[space],
                pickedBy = hopPickedBy(state),
                priority = HOP_STATE_PRIORITY[state],
                recency = lastSeenAt[space] or changedAt[space] or 0,
                distance = hopDistance(position, closingIndex, #spaces),
            }
        end
    end
    table.sort(order, function(a, b)
        -- Rank every full-screen Space ahead of the desktop, so a session there is the last resort rather than skipped.
        if a.fullScreen ~= b.fullScreen then
            return a.fullScreen
        elseif a.priority ~= b.priority then
            return a.priority < b.priority
        elseif a.recency ~= b.recency then
            return a.recency > b.recency
        end
        return a.distance < b.distance
    end)
    return order
end

-- Return where a hop off `closing` goes, as hopOrderFrom ranks it, from a fresh read so a state the watcher hasn't drawn yet still counts.
function showSpacePosition.hopOrder(spaces, closing)
    local states, windows, changedAt = readSessionStates()
    return hopOrderFrom({ states = states, windows = windows, changedAt = changedAt }, spaces, closing)
end

-- Stamp the Space you're leaving and the one you land on, so last seen means the last moment you were on it.
local function recordSpaceSeen()
    local now = hs.timer.secondsSinceEpoch()
    if currentSpace ~= nil then
        lastSeenAt[currentSpace] = now
    end
    currentSpace = hs.spaces.focusedSpace()
    lastSeenAt[currentSpace] = now
end

-- Hold each watcher in the global table so garbage collection can't stop it.
showSpacePosition.watcher = hs.spaces.watcher.new(function()
    recordSpaceSeen()
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
recordSpaceSeen()
render()
-- Re-place the alternate clock now that clockRightInset exists; it loaded first and placed itself without it.
update_clock_position()
