print('display alternate clock')

-- EST_time_command = "TZ='America/New_York'    date '+%a %b %e %H:%M:%S'"
-- PST_time_command = "TZ='America/Los_Angeles' date '+%a %b %e %H:%M:%S'"

EST_time_command = "TZ='America/New_York'    date '+%a %b %e %H:%M' | perl -pe 's/  / /'"
PST_time_command = "TZ='America/Los_Angeles' date '+%a %b %e %H:%M' | perl -pe 's/  / /'"

-- Keep the main screen's width private to this file, so another file's global of the same name can't move the clock.
local full_screen_width

function update_clock_position()
    -- print('update_clock_position')

    -- Find the screen without a window, since none has focus while Hammerspoon starts up.
    local main_screen = hs.screen.mainScreen()

    local local_main_screen_coords = main_screen:absoluteToLocal(main_screen:frame())
    -- print(string.format('local_main_screen_coords: %s', local_main_screen_coords))

    full_screen_width = local_main_screen_coords.w
    -- print(string.format('full_screen_width: %s', full_screen_width))

    h = 19
    w = 220

    x = full_screen_width - w
    y = 24
    -- print(string.format('x: %s', x))
    -- print(string.format('y: %s', y))

    eachClockPair(function(a, b, pair)
        a:frame({
            x = clockLeft(pair),
            y = clockTop(pair),
            h = h,
            w = w,
        })

        b:frame({
            x = clockLeft(pair),
            y = clockTop(pair) + h,
            h = h,
            w = w,
        })
    end)
end

h = 19
w = 252

x = 0
y = 0

textAlignment = 'right'

-- textFont = 'Helvetica Neue'
-- textFont = 'Andale Mono'
textFont = 'Menlo'

-- textSize = 14.7
-- textSize = 13.6
textSize = 14
-- textSize = 15

MOUSEEXIT_CANVAS_FILLCOLOR_STATE = {
    alpha = 1, red = 0, green = 0, blue = 0
    --alpha = 0.4, red = 0, green = 0, blue = 0
}
MOUSEENTER_CANVAS_FILLCOLOR_STATE = {
    alpha = 0, red = 0, green = 0, blue = 0
}
pinCanvasesToSpaces = require('pin_canvases_to_spaces')

CLOCK_CANVAS_BEHAVIOR = pinCanvasesToSpaces.BEHAVIOR

-- Map each Space id to its own { a, b } pair of clock rows.
clocksBySpace = {}

-- Build one clock row at (`rowX`, `rowY`), calling `mouseCallbackFn` as the pointer enters or leaves it.
function newClockRow(
    rowX,
    rowY,
    mouseCallbackFn
)
    local row = hs.canvas.new{
        x = rowX,
        y = rowY,
        h = h,
        w = w,
    }
    row[1] = {
        -- Prod transparent:
        -- action = 'build',
        -- type = 'rectangle',

        -- Prod semi-transparent.
        action = 'fill',
        type = 'rectangle',
        fillColor = MOUSEEXIT_CANVAS_FILLCOLOR_STATE,

        -- Dev:
        -- action = 'fill',
        -- type = 'rectangle',
        -- fillColor = { alpha = 0.5, green = 1.0  },
    }
    row[2] = {
        type = 'text',
        text = '--',
        textAlignment = textAlignment,
        textSize = textSize,
        textFont = textFont,
    }
    row:behavior(CLOCK_CANVAS_BEHAVIOR)
    row:canvasMouseEvents(trackMouseEventsDown, trackMouseEventsUp, trackMouseEventsEnterExit, trackMouseEventsMove)
    -- hs.canvas:mouseCallback(mouseCallbackFn) -> canvasObject
    row:mouseCallback(mouseCallbackFn)
    return row
end

-- Call `fn` with every Space's pair of clock rows.
function eachClockPair(fn)
    for _, pair in pairs(clocksBySpace) do
        fn(pair.a, pair.b, pair)
    end
end

-- Drop the clock below the title bar Ghostty keeps on a full-screen Space, so it clears the page dots there.
FULL_SCREEN_CLOCK_TOP = require('ghostty_title_bar').HEIGHT

local TITLE_BAR_HEIGHT = require('ghostty_title_bar').HEIGHT

-- Return how far from the screen's right edge show_space_position wants `pair`'s clock to end at the screen's top, or nil to leave it below; nil too until that module loads, since it loads after this one.
local function titleBarClockInset(pair)
    if showSpacePosition == nil then
        return nil
    end
    return showSpacePosition.clockRightInset(pair.fullScreen)
end

-- Return the top of `pair`'s first row: at the screen's top where the page dots make room there, else under the menu bar on a desktop or the title bar on a full-screen Space.
function clockTop(pair)
    if titleBarClockInset(pair) ~= nil then
        -- Center both rows in the title bar's height, level with the dots.
        return (TITLE_BAR_HEIGHT - 2 * h) / 2
    elseif not pair.fullScreen then
        return y
    end
    return FULL_SCREEN_CLOCK_TOP
end

-- Return the clock's width, so show_space_position can make room for it beside the dots.
function alternateClockWidth()
    return w
end

-- Return the left edge of `pair`'s rows: flush right, or left of what the page dots keep in the title bar.
function clockLeft(pair)
    local inset = titleBarClockInset(pair)
    if inset == nil then
        return x
    end
    return full_screen_width - inset - w
end

aMouseEnter = false
bMouseEnter = false

function updateCanvasOnHoverStateChange()
    eachClockPair(function(a, b)
        if aMouseEnter or bMouseEnter then
            -- print('yes hovered')
            a[1].fillColor = MOUSEENTER_CANVAS_FILLCOLOR_STATE
            b[1].fillColor = MOUSEENTER_CANVAS_FILLCOLOR_STATE

            a[2].text = ''
            b[2].text = ''
        else
            -- print('not hovered')
            a[1].fillColor = MOUSEEXIT_CANVAS_FILLCOLOR_STATE
            b[1].fillColor = MOUSEEXIT_CANVAS_FILLCOLOR_STATE

            a[2].text = pst_text
            b[2].text = est_text
        end
    end)
end

function canvasAMouseCallbackFn(canvasObject, mouseEventMessage, canvasElementId, mouseX, mouseY)
    -- print('--')
    -- print(string.format('canvasAMouseCallbackFn (%s, %s, %s)', mouseEventMessage, mouseX, mouseY))
    if mouseEventMessage == 'mouseEnter' then
        aMouseEnter = true
    elseif mouseEventMessage == 'mouseExit' then
        aMouseEnter = false
    end
    updateCanvasOnHoverStateChange()
end

function canvasBMouseCallbackFn(canvasObject, mouseEventMessage, canvasElementId, mouseX, mouseY)
    -- print('--')
    -- print(string.format('canvasBMouseCallbackFn (%s, %s, %s)', mouseEventMessage, mouseX, mouseY))
    if mouseEventMessage == 'mouseEnter' then
        -- print('mouseEnter')
        bMouseEnter = true
    elseif mouseEventMessage == 'mouseExit' then
        -- print('mouseExit')
        bMouseEnter = false
    end
    updateCanvasOnHoverStateChange()
end

trackMouseEventsDown = false
trackMouseEventsUp = false
trackMouseEventsEnterExit = true
trackMouseEventsMove = false

pst_text = ''
est_text = ''

-- Print the Pacific then the Eastern time in one process, a line each, so a tick spawns one shell rather than one per zone.
local CLOCK_TIMES_COMMAND = PST_time_command .. '; ' .. EST_time_command

-- Hold the running read, so a slow one never overlaps the next tick's.
local clockTimesTask = nil

-- Show the read times, repainting the rows only when the minute changed.
local function showClockTimes(
    pstTime,
    estTime
)
    local newPstText = string.format(' Pacific: %s', pstTime)
    local newEstText = string.format(' Eastern: %s', estTime)
    if newPstText == pst_text then
        if newEstText == est_text then
            return
        end
    end

    pst_text = newPstText
    est_text = newEstText

    eachClockPair(function(a, b)
        a[2].text = pst_text
        b[2].text = est_text
    end)
end

-- Read the times in the background, since running the shell in line stalls every animation for its whole run.
function update_clock_time()
    if clockTimesTask ~= nil then
        if clockTimesTask:isRunning() then
            return
        end
    end
    clockTimesTask = hs.task.new('/bin/sh', function(exitCode, stdOut)
        clockTimesTask = nil
        if exitCode ~= 0 then
            return
        end
        local pstTime, estTime = stdOut:match('^([^\n]*)\n([^\n]*)')
        if pstTime == nil then
            return
        end
        showClockTimes(pstTime, estTime)
    end, { '-c', CLOCK_TIMES_COMMAND })
    clockTimesTask:start()
end

-- Give the focused Space its own pair on first visit, and drop the pairs of Spaces that no longer exist.
function showClockOnFocusedSpace()
    pinCanvasesToSpaces.pruneClosedSpaces(clocksBySpace, function(pair)
        pair.a:delete()
        pair.b:delete()
    end)

    local focused = hs.spaces.focusedSpace()
    if clocksBySpace[focused] ~= nil then
        return
    end
    local pair = {
        fullScreen = hs.spaces.spaceType(focused) == 'fullscreen',
    }
    pair.a = newClockRow(clockLeft(pair), clockTop(pair), canvasAMouseCallbackFn)
    pair.b = newClockRow(clockLeft(pair), clockTop(pair) + h, canvasBMouseCallbackFn)
    pair.a[2].text = pst_text
    pair.b[2].text = est_text
    pair.a:show()
    pair.b:show()
    clocksBySpace[focused] = pair
end

update_clock_position()
update_clock_time()
showClockOnFocusedSpace()

-- Hold the watcher in a global so garbage collection can't stop it.
spacesWatcher = hs.spaces.watcher.new(function()
    showClockOnFocusedSpace()
end):start()

-- Land each tick a beat past the minute's start, so the read never catches the minute that's ending.
local CLOCK_TICK_SLACK_SECONDS = 0.1

-- Tick at each minute's start, so the clock turns over with the minute rather than up to a tick late.
local function scheduleClockTick()
    local delay = 60 - hs.timer.secondsSinceEpoch() % 60 + CLOCK_TICK_SLACK_SECONDS
    t = hs.timer.doAfter(delay, function()
        update_clock_time()
        scheduleClockTick()
    end)
end
scheduleClockTick()

-- Watch for addition or removal of a monitor and update positioning.
current_screen_count = 0
screenWatcher = hs.screen.watcher.new(function()
    -- print(string.format('current screen count: %s', current_screen_count))
    screen_count = #hs.screen.allScreens()
    -- print(string.format('number of screens now: %s', screen_count))
    if screen_count ~= current_screen_count then
        -- print('layout changed')
        current_screen_count = screen_count
        update_clock_position()
    else
        -- print('layout did not change')
    end
end):start()
