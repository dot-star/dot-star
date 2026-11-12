-- top-left:
--   1x: top-left 50%x50%
--   2x: top-left 66%x50%
--   3x: top-left 33%x50%
-- top:
--   1x: top 100%x50%
--   2x: top 100%x66%
--   3x: top 100%x33%
-- top-right:
--   1x: top-right 50%x50%
--   2x: top-right 66%x50%
--   3x: top-right 33%x50%
-- left:
--   1x: left 50%x100%
--   2x: left 33%x100%
--   3x: left 66%x100%
-- fullscreen:
--   1x: fullscreen 100%
-- right:
--   1x: right 50%x100%
--   2x: right 33%x100%
--   3x: right 66%x100%
-- bottom-left:
--   1x: bottom-left 50%x50%
--   2x: bottom-left 66%x50%
--   3x: bottom-left 33%x50%
-- bottom:
--   1x: bottom 100%x50%
--   2x: bottom 100%x66%
--   3x: bottom 100%x33%
-- bottom-right:
--   1x: bottom-right 50%x50%
--   2x: bottom-right 66%x50%
--   3x: bottom-right 33%x50%
-- first-third:
--   1x: left 33%x100%
-- second-third:
--   1x: middle 33%x100%
-- third-third:
--   1x: right 33%x100%
-- first-two-thirds:
--   1x: left 66%x100%
-- last-two-thirds:
--   1x: right 66%x100%
-- middle-half:
--   1x: middle 50%x100%
-- middle-two-thirds:
--   1x: middle 66%x100%
-- left-third:
--   1x: 1/6 33%x100%
-- right-third:
--   1x: 3/6 33%x100%

-- Remember the most recent Terminal screen-fill target and the screen it was on
-- so the refill timer below can restore the window after opening a tab shrinks
-- and re-centers it. Terminal assigns a new window id to each tab, so the target
-- is tracked per screen rather than per window id.
terminal_fullscreen_target = nil
terminal_refill_screen_id = nil
terminal_last_refill_time = 0

-- Return whether `value` sits within `snap_buffer` of `target`.
local function is_within_snap_buffer(value, target, snap_buffer)
    return value >= target - snap_buffer and value <= target + snap_buffer
end

-- Return whether `frame` sits at `position` on every axis, within that axis's snap buffer.
local function is_at_position(frame, position, snap_buffers)
    for _, axis in ipairs({'x', 'y', 'w', 'h'}) do
        if not is_within_snap_buffer(frame[axis], position[axis], snap_buffers[axis]) then
            return false
        end
    end
    return true
end

-- Return the position after the one `frame` already sits at, wrapping back to
-- the first, or the first position when `frame` sits at none of them.
local function next_position_in_cycle(positions, frame, snap_buffers)
    for index, position in ipairs(positions) do
        -- print(string.format('position %d x:%s y:%s w:%s h:%s', index, position.x, position.y, position.w, position.h))
        if is_at_position(frame, position, snap_buffers) then
            return positions[index % #positions + 1]
        end
    end
    return positions[1]
end

-- Match y exactly for these directions instead of within the snap buffer.
local exact_y_directions = {
    ['left'] = true,
    ['right'] = true,
}

function move_to(dir)
    return function()
        -- print('--------------------------------------')
        -- print(string.format('move_to %s', dir))

        local focused_window = hs.window.focusedWindow()
        -- print(string.format('focused_window: %s', focused_window))
        if focused_window == nil then
            -- print('failed to get focused window');
            return
        end

        local focused_window_coords = focused_window:frame()
        -- print(string.format('focused_window_coords: %s', focused_window_coords))

        local focused_window_screen_coords = focused_window:screen():frame()
        -- print(string.format('focused_window_screen_coords: %s', focused_window_screen_coords))

        local local_focused_window_coords = focused_window:screen():absoluteToLocal(focused_window_coords)
        -- print(string.format('local_focused_window_coords: %s', local_focused_window_coords))

        local local_focused_window_screen_coords = focused_window:screen():absoluteToLocal(focused_window_screen_coords)
        -- print(string.format('local_focused_window_screen_coords: %s', local_focused_window_screen_coords))

        local window_snap_buffer = 20

        local screen_x = local_focused_window_screen_coords.x
        local screen_y = local_focused_window_screen_coords.y

        local full_screen_width = local_focused_window_screen_coords.w
        local one_third_screen_width = local_focused_window_screen_coords.w * 1/3
        local one_half_screen_width = local_focused_window_screen_coords.w * 1/2
        local two_thirds_screen_width = local_focused_window_screen_coords.w * 2/3
        local one_sixth_screen_width = local_focused_window_screen_coords.w * 1/6
        local one_fourth_screen_width = local_focused_window_screen_coords.w * 1/4

        local full_screen_height = local_focused_window_screen_coords.h
        local one_third_screen_height = local_focused_window_screen_coords.h * 1/3
        local one_half_screen_height = local_focused_window_screen_coords.h * 1/2
        local two_thirds_screen_height = local_focused_window_screen_coords.h * 2/3

        -- List each direction's positions in the order repeated presses cycle through them.
        local positions_by_direction = {
            ['fullscreen'] = {
                {x = screen_x, y = screen_y, w = full_screen_width, h = full_screen_height},
            },
            ['top'] = {
                {x = screen_x, y = screen_y, w = full_screen_width, h = one_half_screen_height},
                {x = screen_x, y = screen_y, w = full_screen_width, h = two_thirds_screen_height},
                {x = screen_x, y = screen_y, w = full_screen_width, h = one_third_screen_height},
            },
            ['bottom'] = {
                {x = screen_x, y = screen_y + one_half_screen_height, w = full_screen_width, h = one_half_screen_height},
                {x = screen_x, y = screen_y + one_third_screen_height, w = full_screen_width, h = two_thirds_screen_height},
                {x = screen_x, y = screen_y + two_thirds_screen_height, w = full_screen_width, h = one_third_screen_height},
            },
            ['left'] = {
                {x = screen_x, y = screen_y, w = one_half_screen_width, h = full_screen_height},
                {x = screen_x, y = screen_y, w = one_third_screen_width, h = full_screen_height},
                {x = screen_x, y = screen_y, w = two_thirds_screen_width, h = full_screen_height},
            },
            ['right'] = {
                {x = one_half_screen_width, y = screen_y, w = one_half_screen_width, h = full_screen_height},
                {x = two_thirds_screen_width, y = screen_y, w = one_third_screen_width, h = full_screen_height},
                {x = one_third_screen_width, y = screen_y, w = two_thirds_screen_width, h = full_screen_height},
            },
            ['top-left'] = {
                {x = screen_x, y = screen_y, w = one_half_screen_width, h = one_half_screen_height},
                {x = screen_x, y = screen_y, w = two_thirds_screen_width, h = one_half_screen_height},
                {x = screen_x, y = screen_y, w = one_third_screen_width, h = one_half_screen_height},
            },
            ['top-right'] = {
                {x = one_half_screen_width, y = screen_y, w = one_half_screen_width, h = one_half_screen_height},
                {x = one_third_screen_width, y = screen_y, w = two_thirds_screen_width, h = one_half_screen_height},
                {x = two_thirds_screen_width, y = screen_y, w = one_third_screen_width, h = one_half_screen_height},
            },
            ['bottom-left'] = {
                {x = screen_x, y = screen_y + one_half_screen_height, w = one_half_screen_width, h = one_half_screen_height},
                {x = screen_x, y = screen_y + one_half_screen_height, w = two_thirds_screen_width, h = one_half_screen_height},
                {x = screen_x, y = screen_y + one_half_screen_height, w = one_third_screen_width, h = one_half_screen_height},
            },
            ['bottom-right'] = {
                {x = one_half_screen_width, y = screen_y + one_half_screen_height, w = one_half_screen_width, h = one_half_screen_height},
                {x = one_third_screen_width, y = screen_y + one_half_screen_height, w = two_thirds_screen_width, h = one_half_screen_height},
                {x = two_thirds_screen_width, y = screen_y + one_half_screen_height, w = one_third_screen_width, h = one_half_screen_height},
            },
            ['first-third'] = {
                {x = 0, y = 0, w = one_third_screen_width, h = full_screen_height},
            },
            ['second-third'] = {
                {x = one_third_screen_width, y = 0, w = one_third_screen_width, h = full_screen_height},
            },
            ['third-third'] = {
                {x = two_thirds_screen_width, y = 0, w = one_third_screen_width, h = full_screen_height},
            },
            ['first-two-thirds'] = {
                {x = 0, y = 0, w = two_thirds_screen_width, h = full_screen_height},
            },
            ['last-two-thirds'] = {
                {x = one_third_screen_width, y = 0, w = two_thirds_screen_width, h = full_screen_height},
            },
            ['middle-half'] = {
                {x = one_fourth_screen_width, y = 0, w = one_half_screen_width, h = full_screen_height},
            },
            ['middle-two-thirds'] = {
                {x = one_sixth_screen_width, y = 0, w = two_thirds_screen_width, h = full_screen_height},
            },
            ['left-third'] = {
                {x = one_sixth_screen_width, y = 0, w = one_third_screen_width, h = full_screen_height},
            },
            ['right-third'] = {
                {x = one_half_screen_width, y = 0, w = one_third_screen_width, h = full_screen_height},
            },
        }

        local positions = positions_by_direction[dir]
        if positions == nil then
            -- print(string.format('unknown direction: %s', dir))
            return
        end

        local y_snap_buffer = window_snap_buffer
        if exact_y_directions[dir] then
            y_snap_buffer = 0
        end
        local snap_buffers = {
            x = window_snap_buffer,
            y = y_snap_buffer,
            w = window_snap_buffer,
            h = window_snap_buffer,
        }
        local next_position = next_position_in_cycle(positions, local_focused_window_coords, snap_buffers)

        local_focused_window_coords.x = next_position.x
        local_focused_window_coords.y = next_position.y
        local_focused_window_coords.w = next_position.w
        local_focused_window_coords.h = next_position.h
        -- print(string.format('moving to position x:%s y:%s w:%s h:%s', next_position.x, next_position.y, next_position.w, next_position.h))

        local absolute_focused_window_coords = focused_window:screen():localToAbsolute(local_focused_window_coords)
        focused_window:setFrame(absolute_focused_window_coords)

        -- Track this fullscreened Terminal window so the refill timer can
        -- re-fill it after opening a tab shrinks and re-centers it. Untrack on
        -- any other move so the timer stops pinning a window the user has
        -- since repositioned elsewhere.
        if focused_window:application():name() == 'Terminal' then
            if dir == 'fullscreen' then
                terminal_fullscreen_target = absolute_focused_window_coords
                terminal_refill_screen_id = focused_window:screen():id()
                terminal_refill_timer:start()
            else
                terminal_fullscreen_target = nil
                terminal_refill_timer:stop()
            end
        end
    end
end

hs.hotkey.bind({'ctrl', 'cmd'}, 'q',     move_to('top-left'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'w',     move_to('top'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'e',     move_to('top-right'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'a',     move_to('left'))
hs.hotkey.bind({'ctrl', 'cmd'}, 's',     move_to('fullscreen'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'd',     move_to('right'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'z',     move_to('bottom-left'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'x',     move_to('bottom'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'c',     move_to('bottom-right'))

hs.hotkey.bind({'ctrl', 'cmd'}, 'left',  move_to('left'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'right', move_to('right'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'up',    move_to('top'))
hs.hotkey.bind({'ctrl', 'cmd'}, 'down',  move_to('bottom'))

-- Option + 1 = first third
-- Option + 2 = second third
-- Option + 3 = third third
hs.hotkey.bind({'option'}, '1', move_to('first-third'))
hs.hotkey.bind({'option'}, '2', move_to('second-third'))
hs.hotkey.bind({'option'}, '3', move_to('third-third'))
hs.hotkey.bind({'option'}, '4', move_to('first-two-thirds'))
hs.hotkey.bind({'option'}, '5', move_to('last-two-thirds'))
hs.hotkey.bind({'option'}, '6', move_to('middle-half'))
hs.hotkey.bind({'option'}, '7', move_to('middle-two-thirds'))
hs.hotkey.bind({'option'}, '8', move_to('left-third'))
hs.hotkey.bind({'option'}, '9', move_to('right-third'))

function send_current_window_to_previous_monitor()
    local focused_window = hs.window.focusedWindow()
    local next_screen = focused_window:screen():previous()
    focused_window:moveToScreen(next_screen)
end

function send_current_window_to_next_monitor()
    local focused_window = hs.window.focusedWindow()
    local next_screen = focused_window:screen():next()
    focused_window:moveToScreen(next_screen)
end

hs.hotkey.bind({'ctrl', 'option', 'cmd'}, 'left', send_current_window_to_previous_monitor)
hs.hotkey.bind({'ctrl', 'option', 'cmd'}, 'right', send_current_window_to_next_monitor)

-- Map each app's bundle ID to the menu path of its "Move Tab to New Window" item.
local move_tab_menu_paths = {
    ['com.apple.Safari'] = {'Window', 'Move Tab to New Window'},
    ['com.google.Chrome'] = {'Tab', 'Move Tab to New Window'},
    ['com.mitchellh.ghostty'] = {'Window', 'Move Tab to New Window'},
}

function move_current_tab_to_new_window()
    local app = hs.application.frontmostApplication()
    local menu_path = move_tab_menu_paths[app:bundleID()]
    if menu_path == nil then
        hs.alert.show('No tab menu path known for ' .. app:name())
    elseif not app:selectMenuItem(menu_path) then
        hs.alert.show('No "' .. menu_path[#menu_path] .. '" menu item in ' .. app:name())
    end
end

hs.hotkey.bind({'ctrl', 'option', 'cmd'}, 'n', move_current_tab_to_new_window)

-- Disabled window animations since this seems to cause windows to not move to
-- their desired destination.
-- hs.window.animationDuration = 0.2
--
-- UPDATE(1/3/2022): Re-enabled animation to a small value as using 0 caused
-- delays for some unknown reason. Using 0.1 seems to fix the delay from hotkey
-- press until the window is finally moved.
-- hs.window.animationDuration = 0
-- hs.window.animationDuration = 0.1
-- hs.window.animationDuration = 0.001
hs.window.animationDuration = 0

-- Dump the focused window's actual pixel frame against the expected screen-fill
-- frame (plus the per-edge overflow and, for Terminal, the cell grid), then copy
-- the report to the clipboard so it can be pasted. Press to debug why a window
-- over- or undershoots its target.
function debug_window_dimensions()
    local focused_window = hs.window.focusedWindow()
    if focused_window == nil then
        hs.alert.show('no focused window')
        return
    end

    local app_name = focused_window:application():name()
    local frame = focused_window:frame()
    local screen_frame = focused_window:screen():frame()

    local lines = {}
    lines[#lines + 1] = string.format('app: %s', app_name)
    lines[#lines + 1] = string.format('actual:   x=%d y=%d w=%d h=%d', frame.x, frame.y, frame.w, frame.h)
    lines[#lines + 1] = string.format('expected: x=%d y=%d w=%d h=%d  (screen fill)', screen_frame.x, screen_frame.y, screen_frame.w, screen_frame.h)
    lines[#lines + 1] = string.format('delta:    w=%+d h=%+d  (actual - expected)', frame.w - screen_frame.w, frame.h - screen_frame.h)
    lines[#lines + 1] = string.format('overflow: right=%+d bottom=%+d  (actual edge - screen edge)', (frame.x + frame.w) - (screen_frame.x + screen_frame.w), (frame.y + frame.h) - (screen_frame.y + screen_frame.h))

    if app_name == 'Terminal' then
        local ok, dims = hs.osascript.applescript([[
            tell application "Terminal"
                set frontWindow to front window
                return (number of columns of frontWindow as string) & "," & (number of rows of frontWindow as string)
            end tell
        ]])
        if ok then
            local columns, rows = string.match(dims, '(%d+),(%d+)')
            columns = tonumber(columns)
            rows = tonumber(rows)
            lines[#lines + 1] = string.format('cells:    %dx%d  (approx cell w=%.1f h=%.1f)', columns, rows, frame.w / columns, frame.h / rows)
        end
    end

    local report = table.concat(lines, '\n')
    -- print(report)
    hs.pasteboard.setContents(report)
    hs.alert.show('window dims copied to clipboard')
end

hs.hotkey.bind({'ctrl', 'cmd'}, 'g', debug_window_dimensions)

-- Re-fill a fullscreened Terminal window whenever opening a tab shrinks it.
-- Terminal re-fits the window to a narrower whole-cell width and re-centers it
-- on tab creation, assigning the window a fresh id each time, so match on the
-- shrink signature (near-full but narrower than the fill) across the screen's
-- windows rather than tracking an id. Poll instead of subscribing to resize
-- events, which proved unreliable for these app-driven resizes. Rate-limit the
-- re-fill so a window Terminal insists on shrinking can't flicker rapidly.
-- Run the poll only while a target is tracked, since each tick wakes the CPU
-- and an always-on poll keeps the laptop from idling.
terminal_refill_timer = hs.timer.new(0.1, function()
    local app = hs.application.get('Terminal')
    if app == nil then
        -- Drop the target once Terminal quits, since its windows went with it.
        terminal_fullscreen_target = nil
        terminal_refill_timer:stop()
        return
    end

    local target = terminal_fullscreen_target
    local now = hs.timer.secondsSinceEpoch()
    for _, window in ipairs(app:allWindows()) do
        local frame = window:frame()
        if
            window:screen():id() == terminal_refill_screen_id and
            frame.w < target.w - 2 and
            frame.w > target.w * 0.8 and
            now - terminal_last_refill_time > 0.5
        then
            window:setFrame(target)
            terminal_last_refill_time = now
        end
    end
end)
