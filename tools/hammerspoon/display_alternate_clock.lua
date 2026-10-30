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

    a:frame({
        x = x,
        y = y,
        h = h,
        w = w,
    })

    b:frame({
        x = x,
        y = y + h,
        h = h,
        w = w,
    })
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
-- Join every Space, full-screen ones included; without it the clock stays on whichever Space Hammerspoon loaded on.
CLOCK_CANVAS_BEHAVIOR = {
    'canJoinAllSpaces',
    'fullScreenAuxiliary',
    'stationary',
}

a = hs.canvas.new{
    x = x,
    y = y,
    h = h,
    w = w,
}
a[1] = {
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
a[2] = {
    type = 'text',
    text = '--',
    textAlignment = textAlignment,
    textSize = textSize,
    textFont = textFont,
}
a:behavior(CLOCK_CANVAS_BEHAVIOR)
a:show()

b = hs.canvas.new{
    x = x,
    y = y + h,
    h = h,
    w = w,
}
b[1] = {
    -- Prod:
    -- action = 'build',
    -- type = 'rectangle',

    -- Prod semi-transparent.
    action = 'fill',
    type = 'rectangle',
    fillColor = MOUSEEXIT_CANVAS_FILLCOLOR_STATE,

    -- Dev:
    -- action = 'fill',
    -- type = 'rectangle',
    -- fillColor = { alpha = 0.5, red = 1.0  },
}
b[2] = {
    type = 'text',
    text = '--',
    textAlignment = textAlignment,
    textSize = textSize,
    textFont = textFont,
}
b:behavior(CLOCK_CANVAS_BEHAVIOR)
b:show()

aMouseEnter = false
bMouseEnter = false

function updateCanvasOnHoverStateChange()
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
a:canvasMouseEvents(trackMouseEventsDown, trackMouseEventsUp, trackMouseEventsEnterExit, trackMouseEventsMove)
b:canvasMouseEvents(trackMouseEventsDown, trackMouseEventsUp, trackMouseEventsEnterExit, trackMouseEventsMove)

-- hs.canvas:mouseCallback(mouseCallbackFn) -> canvasObject
a:mouseCallback(canvasAMouseCallbackFn)
b:mouseCallback(canvasBMouseCallbackFn)

pst_text = ''
est_text = ''

function update_clock_time()
    local pst_time = hs.execute(PST_time_command)
    local est_time = hs.execute(EST_time_command)

    pst_text = string.format(' Pacific: %s', pst_time)
    est_text = string.format(' Eastern: %s', est_time)

    a[2].text = pst_text
    b[2].text = est_text
end

update_clock_position()
update_clock_time()

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
