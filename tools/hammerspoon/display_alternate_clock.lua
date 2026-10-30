print('display alternate clock')

-- EST_time_command = "TZ='America/New_York'    date '+%a %b %e %H:%M:%S'"
-- PST_time_command = "TZ='America/Los_Angeles' date '+%a %b %e %H:%M:%S'"

EST_time_command = "TZ='America/New_York'    date '+%a %b %e %H:%M' | perl -pe 's/  / /'"
PST_time_command = "TZ='America/Los_Angeles' date '+%a %b %e %H:%M' | perl -pe 's/  / /'"

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
            x = x,
            y = clockTop(pair),
            h = h,
            w = w,
        })

        b:frame({
            x = x,
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

-- Build one clock row at `rowY`, calling `mouseCallbackFn` as the pointer enters or leaves it.
function newClockRow(rowY, mouseCallbackFn)
    local row = hs.canvas.new{
        x = x,
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

-- Return the top of `pair`'s first row: under the menu bar on a desktop, under the title bar on a full-screen Space.
function clockTop(pair)
    if pair.fullScreen then
        return FULL_SCREEN_CLOCK_TOP
    end
    return y
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

function update_clock_time()
    local pst_time = hs.execute(PST_time_command)
    local est_time = hs.execute(EST_time_command)

    pst_text = string.format(' Pacific: %s', pst_time)
    est_text = string.format(' Eastern: %s', est_time)

    eachClockPair(function(a, b)
        a[2].text = pst_text
        b[2].text = est_text
    end)
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
    pair.a = newClockRow(clockTop(pair), canvasAMouseCallbackFn)
    pair.b = newClockRow(clockTop(pair) + h, canvasBMouseCallbackFn)
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

-- t = hs.timer.doEvery(.1, update_clock_time) -- High CPU.
-- t = hs.timer.doEvery(1, update_clock_time) -- Acceptable CPU.
t = hs.timer.doEvery(10, function()
    update_clock_time()
end) -- Less CPU.

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
