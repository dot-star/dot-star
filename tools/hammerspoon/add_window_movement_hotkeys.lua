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
--   2x: left 66%x100%
--   3x: left 33%x100%
-- fullscreen:
--   1x: fullscreen 100%
-- right:
--   1x: right 50%x100%
--   2x: right 66%x100%
--   3x: right 33%x100%
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

function move_to(dir)
    return function()
        print('--------------------------------------')
        print(string.format('move_to %s', dir))

        local focused_window = hs.window.focusedWindow()
        print(string.format('focused_window: %s', focused_window))
        if focused_window == nil then
            print('failed to get focused window');
            return
        end

        local focused_window_coords = focused_window:frame()
        print(string.format('focused_window_coords: %s', focused_window_coords))

        local focused_window_screen_coords = focused_window:screen():frame()
        print(string.format('focused_window_screen_coords: %s', focused_window_screen_coords))

        local local_focused_window_coords = focused_window:screen():absoluteToLocal(focused_window_coords)
        print(string.format('local_focused_window_coords: %s', local_focused_window_coords))

        local local_focused_window_screen_coords = focused_window:screen():absoluteToLocal(focused_window_screen_coords)
        print(string.format('local_focused_window_screen_coords: %s', local_focused_window_screen_coords))

        window_snap_buffer = 20

              full_screen_width = local_focused_window_screen_coords.w
         one_third_screen_width = local_focused_window_screen_coords.w * 1/3
          one_half_screen_width = local_focused_window_screen_coords.w * 1/2
        two_thirds_screen_width = local_focused_window_screen_coords.w * 2/3
         one_sixth_screen_width = local_focused_window_screen_coords.w * 1/6
        one_fourth_screen_width = local_focused_window_screen_coords.w * 1/4

              full_screen_height = local_focused_window_screen_coords.h
         one_third_screen_height = local_focused_window_screen_coords.h * 1/3
          one_half_screen_height = local_focused_window_screen_coords.h * 1/2
        two_thirds_screen_height = local_focused_window_screen_coords.h * 2/3

        if dir == 'fullscreen' then
            next_position_x = local_focused_window_screen_coords.x
            next_position_y = local_focused_window_screen_coords.y
            next_position_w = full_screen_width
            next_position_h = full_screen_height
        elseif dir == 'top' then
            position_1_x = local_focused_window_screen_coords.x
            position_1_y = local_focused_window_screen_coords.y
            position_1_w = full_screen_width
            position_1_h = one_half_screen_height
            print(string.format('top position 1 x:%s y:%s w:%s h:%s', position_1_x, position_1_y, position_1_w, position_1_h))

            position_2_x = local_focused_window_screen_coords.x
            position_2_y = local_focused_window_screen_coords.y
            position_2_w = full_screen_width
            position_2_h = two_thirds_screen_height
            print(string.format('top position 2 x:%s y:%s w:%s h:%s', position_2_x, position_2_y, position_2_w, position_2_h))

            position_3_x = local_focused_window_screen_coords.x
            position_3_y = local_focused_window_screen_coords.y
            position_3_w = full_screen_width
            position_3_h = one_third_screen_height
            print(string.format('top position 3 x:%s y:%s w:%s h:%s', position_3_x, position_3_y, position_3_w, position_3_h))

            -- if at position 1, go to position 2.
            if
                (
                    -- local_focused_window_coords.x ~= position_1_x
                    local_focused_window_coords.x >= position_1_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_1_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_1_y
                    local_focused_window_coords.y >= position_1_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_1_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_1_w
                    local_focused_window_coords.w >= position_1_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_1_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_1_h
                    local_focused_window_coords.h >= position_1_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_1_h + window_snap_buffer
                ) then
                print('at top position 1')
                print('moving to position 2')
                next_position_x = position_2_x
                next_position_y = position_2_y
                next_position_w = position_2_w
                next_position_h = position_2_h
            -- if at position 2, go to position 3.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_2_x
                    local_focused_window_coords.x >= position_2_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_2_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_2_y
                    local_focused_window_coords.y >= position_2_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_2_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_2_w
                    local_focused_window_coords.w >= position_2_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_2_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_2_h
                    local_focused_window_coords.h >= position_2_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_2_h + window_snap_buffer
                ) then
                print('at top position 2')
                print('moving to position 3')
                next_position_x = position_3_x
                next_position_y = position_3_y
                next_position_w = position_3_w
                next_position_h = position_3_h
            -- if at position 3, go to position 1.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_3_x
                    local_focused_window_coords.x >= position_3_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_3_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_3_y
                    local_focused_window_coords.y >= position_3_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_3_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_3_w
                    local_focused_window_coords.w >= position_3_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_3_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_3_h
                    local_focused_window_coords.h >= position_3_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_3_h + window_snap_buffer
                ) then
                print('at top position 3')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            -- if at some other position, go to position 1.
            else
                print('at some other position')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            end
        elseif dir == 'bottom' then
            next_position_x = local_focused_window_screen_coords.x
            next_position_y = local_focused_window_screen_coords.y + one_half_screen_height
            next_position_w = full_screen_width
            next_position_h = one_half_screen_height

            position_1_x = local_focused_window_screen_coords.x
            position_1_y = local_focused_window_screen_coords.y + one_half_screen_height
            position_1_w = full_screen_width
            position_1_h = one_half_screen_height
            print(string.format('bottom position 1 x:%s y:%s w:%s h:%s', position_1_x, position_1_y, position_1_w, position_1_h))

            position_2_x = local_focused_window_screen_coords.x
            position_2_y = local_focused_window_screen_coords.y + one_third_screen_height
            position_2_w = full_screen_width
            position_2_h = two_thirds_screen_height
            print(string.format('bottom position 2 x:%s y:%s w:%s h:%s', position_2_x, position_2_y, position_2_w, position_2_h))

            position_3_x = local_focused_window_screen_coords.x
            position_3_y = local_focused_window_screen_coords.y + two_thirds_screen_height
            position_3_w = full_screen_width
            position_3_h = one_third_screen_height
            print(string.format('bottom position 3 x:%s y:%s w:%s h:%s', position_3_x, position_3_y, position_3_w, position_3_h))

            -- if at position 1, go to position 2.
            if
                (
                    -- local_focused_window_coords.x ~= position_1_x
                    local_focused_window_coords.x >= position_1_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_1_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_1_y
                    local_focused_window_coords.y >= position_1_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_1_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_1_w
                    local_focused_window_coords.w >= position_1_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_1_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_1_h
                    local_focused_window_coords.h >= position_1_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_1_h + window_snap_buffer
                ) then
                print('at bottom position 1')
                print('moving to position 2')
                next_position_x = position_2_x
                next_position_y = position_2_y
                next_position_w = position_2_w
                next_position_h = position_2_h
            -- if at position 2, go to position 3.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_2_x
                    local_focused_window_coords.x >= position_2_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_2_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_2_y
                    local_focused_window_coords.y >= position_2_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_2_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_2_w
                    local_focused_window_coords.w >= position_2_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_2_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_2_h
                    local_focused_window_coords.h >= position_2_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_2_h + window_snap_buffer
                ) then
                print('at bottom position 2')
                print('moving to position 3')
                next_position_x = position_3_x
                next_position_y = position_3_y
                next_position_w = position_3_w
                next_position_h = position_3_h
            -- if at position 3, go to position 1.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_3_x
                    local_focused_window_coords.x >= position_3_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_3_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_3_y
                    local_focused_window_coords.y >= position_3_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_3_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_3_w
                    local_focused_window_coords.w >= position_3_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_3_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_3_h
                    local_focused_window_coords.h >= position_3_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_3_h + window_snap_buffer
                ) then
                print('at bottom position 3')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            -- if at some other position, go to position 1.
            else
                print('at some other position')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            end
        elseif dir == 'left' then
            position_1_x = local_focused_window_screen_coords.x
            position_1_y = local_focused_window_screen_coords.y
            position_1_w = one_half_screen_width
            position_1_h = full_screen_height
            print(string.format('left position 1 x:%s y:%s w:%s h:%s', position_1_x, position_1_y, position_1_w, position_1_h))

            position_2_x = local_focused_window_screen_coords.x
            position_2_y = local_focused_window_screen_coords.y
            position_2_w = one_third_screen_width
            position_2_h = full_screen_height
            print(string.format('left position 2 x:%s y:%s w:%s h:%s', position_2_x, position_2_y, position_2_w, position_2_h))

            position_3_x = local_focused_window_screen_coords.x
            position_3_y = local_focused_window_screen_coords.y
            position_3_w = two_thirds_screen_width
            position_3_h = full_screen_height
            print(string.format('left position 3 x:%s y:%s w:%s h:%s', position_3_x, position_3_y, position_3_w, position_3_h))

            -- if at position 1, go to position 2.
            if
                (
                    -- local_focused_window_coords.x ~= position_1_x
                    local_focused_window_coords.x >= position_1_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_1_x + window_snap_buffer
                ) and
                local_focused_window_coords.y == position_1_y and
                (
                    -- local_focused_window_coords.w ~= position_1_w
                    local_focused_window_coords.w >= position_1_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_1_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_1_h
                    local_focused_window_coords.h >= position_1_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_1_h + window_snap_buffer
                ) then
                print('at left position 1')
                print('moving to position 2')
                next_position_x = position_2_x
                next_position_y = position_2_y
                next_position_w = position_2_w
                next_position_h = position_2_h
            -- if at position 2, go to position 3.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_2_x
                    local_focused_window_coords.x >= position_2_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_2_x + window_snap_buffer
                ) and
                local_focused_window_coords.y == position_2_y and
                (
                    -- local_focused_window_coords.w ~= position_2_w
                    local_focused_window_coords.w >= position_2_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_2_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_2_h
                    local_focused_window_coords.h >= position_2_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_2_h + window_snap_buffer
                ) then
                print('at left position 2')
                print('moving to position 3')
                next_position_x = position_3_x
                next_position_y = position_3_y
                next_position_w = position_3_w
                next_position_h = position_3_h
            -- if at position 3, go to position 1.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_3_x
                    local_focused_window_coords.x >= position_3_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_3_x + window_snap_buffer
                ) and
                local_focused_window_coords.y == position_3_y and
                (
                    -- local_focused_window_coords.w ~= position_3_w
                    local_focused_window_coords.w >= position_3_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_3_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_3_h
                    local_focused_window_coords.h >= position_3_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_3_h + window_snap_buffer
                ) then
                print('at left position 3')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            -- if at some other position, go to position 1.
            else
                print('at some other position')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            end
        elseif dir == 'right' then
            position_1_x = one_half_screen_width
            position_1_y = local_focused_window_screen_coords.y
            position_1_w = one_half_screen_width
            position_1_h = full_screen_height
            print(string.format('right position 1 x:%s y:%s w:%s h:%s', position_1_x, position_1_y, position_1_w, position_1_h))

            position_2_x = two_thirds_screen_width
            position_2_y = local_focused_window_screen_coords.y
            position_2_w = one_third_screen_width
            position_2_h = full_screen_height
            print(string.format('right position 2 x:%s y:%s w:%s h:%s', position_2_x, position_2_y, position_2_w, position_2_h))

            position_3_x = one_third_screen_width
            position_3_y = local_focused_window_screen_coords.y
            position_3_w = two_thirds_screen_width
            position_3_h = full_screen_height
            print(string.format('right position 3 x:%s y:%s w:%s h:%s', position_3_x, position_3_y, position_3_w, position_3_h))

            -- if at position 1, go to position 2.
            if
                (
                    -- local_focused_window_coords.x ~= position_1_x
                    local_focused_window_coords.x >= position_1_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_1_x + window_snap_buffer
                ) and
                local_focused_window_coords.y == position_1_y and
                (
                    -- local_focused_window_coords.w ~= position_1_w
                    local_focused_window_coords.w >= position_1_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_1_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_1_h
                    local_focused_window_coords.h >= position_1_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_1_h + window_snap_buffer
                ) then
                print('at right position 1')
                print('moving to position 2')
                next_position_x = position_2_x
                next_position_y = position_2_y
                next_position_w = position_2_w
                next_position_h = position_2_h
            -- if at position 2, go to position 3.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_2_x
                    local_focused_window_coords.x >= position_2_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_2_x + window_snap_buffer
                ) and
                local_focused_window_coords.y == position_2_y and
                (
                    -- local_focused_window_coords.w ~= position_2_w
                    local_focused_window_coords.w >= position_2_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_2_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_2_h
                    local_focused_window_coords.h >= position_2_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_2_h + window_snap_buffer
                ) then
                print('at right position 2')
                print('moving to position 3')
                next_position_x = position_3_x
                next_position_y = position_3_y
                next_position_w = position_3_w
                next_position_h = position_3_h
            -- if at position 3, go to position 1.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_3_x
                    local_focused_window_coords.x >= position_3_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_3_x + window_snap_buffer
                ) and
                local_focused_window_coords.y == position_3_y and
                (
                    -- local_focused_window_coords.w ~= position_3_w
                    local_focused_window_coords.w >= position_3_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_3_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_3_h
                    local_focused_window_coords.h >= position_3_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_3_h + window_snap_buffer
                ) then
                print('at right position 3')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            -- if at some other position, go to position 1.
            else
                print('at some other position')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            end
        elseif dir == 'top-left' then
            position_1_x = local_focused_window_screen_coords.x
            position_1_y = local_focused_window_screen_coords.y
            position_1_w = one_half_screen_width
            position_1_h = one_half_screen_height
            print(string.format('top-left position 1 x:%s y:%s w:%s h:%s', position_1_x, position_1_y, position_1_w, position_1_h))

            position_2_x = local_focused_window_screen_coords.x
            position_2_y = local_focused_window_screen_coords.y
            position_2_w = two_thirds_screen_width
            position_2_h = one_half_screen_height
            print(string.format('top-left position 2 x:%s y:%s w:%s h:%s', position_2_x, position_2_y, position_2_w, position_2_h))

            position_3_x = local_focused_window_screen_coords.x
            position_3_y = local_focused_window_screen_coords.y
            position_3_w = one_third_screen_width
            position_3_h = one_half_screen_height
            print(string.format('top-left position 3 x:%s y:%s w:%s h:%s', position_3_x, position_3_y, position_3_w, position_3_h))

            -- if at position 1, go to position 2.
            if
                (
                    -- local_focused_window_coords.x ~= position_1_x
                    local_focused_window_coords.x >= position_1_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_1_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_1_y
                    local_focused_window_coords.y >= position_1_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_1_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_1_w
                    local_focused_window_coords.w >= position_1_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_1_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_1_h
                    local_focused_window_coords.h >= position_1_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_1_h + window_snap_buffer
                ) then
                print('at top-left position 1')
                print('moving to position 2')
                next_position_x = position_2_x
                next_position_y = position_2_y
                next_position_w = position_2_w
                next_position_h = position_2_h
            -- if at position 2, go to position 3.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_2_x
                    local_focused_window_coords.x >= position_2_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_2_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_2_y
                    local_focused_window_coords.y >= position_2_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_2_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_2_w
                    local_focused_window_coords.w >= position_2_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_2_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_2_h
                    local_focused_window_coords.h >= position_2_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_2_h + window_snap_buffer
                ) then
                print('at top-left position 2')
                print('moving to position 3')
                next_position_x = position_3_x
                next_position_y = position_3_y
                next_position_w = position_3_w
                next_position_h = position_3_h
            -- if at position 3, go to position 1.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_3_x
                    local_focused_window_coords.x >= position_3_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_3_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_3_y
                    local_focused_window_coords.y >= position_3_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_3_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_3_w
                    local_focused_window_coords.w >= position_3_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_3_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_3_h
                    local_focused_window_coords.h >= position_3_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_3_h + window_snap_buffer
                ) then
                print('at top-left position 3')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            -- if at some other position, go to position 1.
            else
                print('at some other position')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            end
        elseif dir == 'top-right' then
            position_1_x = one_half_screen_width
            position_1_y = local_focused_window_screen_coords.y
            position_1_w = one_half_screen_width
            position_1_h = one_half_screen_height
            print(string.format('top-right position 1 x:%s y:%s w:%s h:%s', position_1_x, position_1_y, position_1_w, position_1_h))

            position_2_x = one_third_screen_width
            position_2_y = local_focused_window_screen_coords.y
            position_2_w = two_thirds_screen_width
            position_2_h = one_half_screen_height
            print(string.format('top-right position 2 x:%s y:%s w:%s h:%s', position_2_x, position_2_y, position_2_w, position_2_h))

            position_3_x = two_thirds_screen_width
            position_3_y = local_focused_window_screen_coords.y
            position_3_w = one_third_screen_width
            position_3_h = one_half_screen_height
            print(string.format('top-right position 3 x:%s y:%s w:%s h:%s', position_3_x, position_3_y, position_3_w, position_3_h))

            -- if at position 1, go to position 2.
            if
                (
                    -- local_focused_window_coords.x ~= position_1_x
                    local_focused_window_coords.x >= position_1_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_1_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_1_y
                    local_focused_window_coords.y >= position_1_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_1_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_1_w
                    local_focused_window_coords.w >= position_1_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_1_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_1_h
                    local_focused_window_coords.h >= position_1_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_1_h + window_snap_buffer
                ) then
                print('at top-right position 1')
                print('moving to position 2')
                next_position_x = position_2_x
                next_position_y = position_2_y
                next_position_w = position_2_w
                next_position_h = position_2_h
            -- if at position 2, go to position 3.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_2_x
                    local_focused_window_coords.x >= position_2_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_2_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_2_y
                    local_focused_window_coords.y >= position_2_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_2_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_2_w
                    local_focused_window_coords.w >= position_2_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_2_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_2_h
                    local_focused_window_coords.h >= position_2_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_2_h + window_snap_buffer
                ) then
                print('at top-right position 2')
                print('moving to position 3')
                next_position_x = position_3_x
                next_position_y = position_3_y
                next_position_w = position_3_w
                next_position_h = position_3_h
            -- if at position 3, go to position 1.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_3_x
                    local_focused_window_coords.x >= position_3_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_3_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_3_y
                    local_focused_window_coords.y >= position_3_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_3_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_3_w
                    local_focused_window_coords.w >= position_3_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_3_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_3_h
                    local_focused_window_coords.h >= position_3_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_3_h + window_snap_buffer
                ) then
                print('at top-right position 3')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            -- if at some other position, go to position 1.
            else
                print('at some other position')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            end
        elseif dir == 'bottom-left' then
            position_1_x = local_focused_window_screen_coords.x
            position_1_y = local_focused_window_screen_coords.y + one_half_screen_height
            position_1_w = one_half_screen_width
            position_1_h = one_half_screen_height
            print(string.format('bottom-left position 1 x:%s y:%s w:%s h:%s', position_1_x, position_1_y, position_1_w, position_1_h))

            position_2_x = local_focused_window_screen_coords.x
            position_2_y = local_focused_window_screen_coords.y + one_half_screen_height
            position_2_w = two_thirds_screen_width
            position_2_h = one_half_screen_height
            print(string.format('bottom-left position 2 x:%s y:%s w:%s h:%s', position_2_x, position_2_y, position_2_w, position_2_h))

            position_3_x = local_focused_window_screen_coords.x
            position_3_y = local_focused_window_screen_coords.y + one_half_screen_height
            position_3_w = one_third_screen_width
            position_3_h = one_half_screen_height
            print(string.format('bottom-left position 3 x:%s y:%s w:%s h:%s', position_3_x, position_3_y, position_3_w, position_3_h))

            -- if at position 1, go to position 2.
            if
                (
                    -- local_focused_window_coords.x ~= position_1_x
                    local_focused_window_coords.x >= position_1_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_1_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_1_y
                    local_focused_window_coords.y >= position_1_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_1_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_1_w
                    local_focused_window_coords.w >= position_1_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_1_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_1_h
                    local_focused_window_coords.h >= position_1_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_1_h + window_snap_buffer
                ) then
                print('at bottom-left position 1')
                print('moving to position 2')
                next_position_x = position_2_x
                next_position_y = position_2_y
                next_position_w = position_2_w
                next_position_h = position_2_h
            -- if at position 2, go to position 3.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_2_x
                    local_focused_window_coords.x >= position_2_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_2_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_2_y
                    local_focused_window_coords.y >= position_2_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_2_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_2_w
                    local_focused_window_coords.w >= position_2_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_2_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_2_h
                    local_focused_window_coords.h >= position_2_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_2_h + window_snap_buffer
                ) then
                print('at bottom-left position 2')
                print('moving to position 3')
                next_position_x = position_3_x
                next_position_y = position_3_y
                next_position_w = position_3_w
                next_position_h = position_3_h
            -- if at position 3, go to position 1.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_3_x
                    local_focused_window_coords.x >= position_3_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_3_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_3_y
                    local_focused_window_coords.y >= position_3_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_3_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_3_w
                    local_focused_window_coords.w >= position_3_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_3_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_3_h
                    local_focused_window_coords.h >= position_3_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_3_h + window_snap_buffer
                ) then
                print('at bottom-left position 3')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            -- if at some other position, go to position 1.
            else
                print('at some other position')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            end
        elseif dir == 'bottom-right' then
            position_1_x = one_half_screen_width
            position_1_y = local_focused_window_screen_coords.y + one_half_screen_height
            position_1_w = one_half_screen_width
            position_1_h = one_half_screen_height
            print(string.format('bottom-right position 1 x:%s y:%s w:%s h:%s', position_1_x, position_1_y, position_1_w, position_1_h))

            position_2_x = one_third_screen_width
            position_2_y = local_focused_window_screen_coords.y + one_half_screen_height
            position_2_w = two_thirds_screen_width
            position_2_h = one_half_screen_height
            print(string.format('bottom-right position 2 x:%s y:%s w:%s h:%s', position_2_x, position_2_y, position_2_w, position_2_h))

            position_3_x = two_thirds_screen_width
            position_3_y = local_focused_window_screen_coords.y + one_half_screen_height
            position_3_w = one_third_screen_width
            position_3_h = one_half_screen_height
            print(string.format('bottom-right position 3 x:%s y:%s w:%s h:%s', position_3_x, position_3_y, position_3_w, position_3_h))

            -- if at position 1, go to position 2.
            if
                (
                    -- local_focused_window_coords.x ~= position_1_x
                    local_focused_window_coords.x >= position_1_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_1_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_1_y
                    local_focused_window_coords.y >= position_1_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_1_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_1_w
                    local_focused_window_coords.w >= position_1_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_1_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_1_h
                    local_focused_window_coords.h >= position_1_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_1_h + window_snap_buffer
                ) then
                print('at bottom-right position 1')
                print('moving to position 2')
                next_position_x = position_2_x
                next_position_y = position_2_y
                next_position_w = position_2_w
                next_position_h = position_2_h
            -- if at position 2, go to position 3.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_2_x
                    local_focused_window_coords.x >= position_2_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_2_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_2_y
                    local_focused_window_coords.y >= position_2_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_2_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_2_w
                    local_focused_window_coords.w >= position_2_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_2_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_2_h
                    local_focused_window_coords.h >= position_2_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_2_h + window_snap_buffer
                ) then
                print('at bottom-right position 2')
                print('moving to position 3')
                next_position_x = position_3_x
                next_position_y = position_3_y
                next_position_w = position_3_w
                next_position_h = position_3_h
            -- if at position 3, go to position 1.
            elseif
                (
                    -- local_focused_window_coords.x ~= position_3_x
                    local_focused_window_coords.x >= position_3_x - window_snap_buffer and
                    local_focused_window_coords.x <= position_3_x + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.y ~= position_3_y
                    local_focused_window_coords.y >= position_3_y - window_snap_buffer and
                    local_focused_window_coords.y <= position_3_y + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.w ~= position_3_w
                    local_focused_window_coords.w >= position_3_w - window_snap_buffer and
                    local_focused_window_coords.w <= position_3_w + window_snap_buffer
                ) and
                (
                    -- local_focused_window_coords.h ~= position_3_h
                    local_focused_window_coords.h >= position_3_h - window_snap_buffer and
                    local_focused_window_coords.h <= position_3_h + window_snap_buffer
                ) then
                print('at bottom-right position 3')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            -- if at some other position, go to position 1.
            else
                print('at some other position')
                print('moving to position 1')
                next_position_x = position_1_x
                next_position_y = position_1_y
                next_position_w = position_1_w
                next_position_h = position_1_h
            end
        elseif dir == 'first-third' then
            next_position_x = 0
            next_position_y = 0
            next_position_w = one_third_screen_width
            next_position_h = full_screen_height
        elseif dir == 'second-third' then
            next_position_x = one_third_screen_width
            next_position_y = 0
            next_position_w = one_third_screen_width
            next_position_h = full_screen_height
        elseif dir == 'third-third' then
            next_position_x = two_thirds_screen_width
            next_position_y = 0
            next_position_w = one_third_screen_width
            next_position_h = full_screen_height
        elseif dir == 'first-two-thirds' then
            next_position_x = 0
            next_position_y = 0
            next_position_w = two_thirds_screen_width
            next_position_h = full_screen_height
        elseif dir == 'last-two-thirds' then
            next_position_x = one_third_screen_width
            next_position_y = 0
            next_position_w = two_thirds_screen_width
            next_position_h = full_screen_height
        elseif dir == 'middle-half' then
            next_position_x = one_fourth_screen_width
            next_position_y = 0
            next_position_w = one_half_screen_width
            next_position_h = full_screen_height
        elseif dir == 'middle-two-thirds' then
            next_position_x = one_sixth_screen_width
            next_position_y = 0
            next_position_w = two_thirds_screen_width
            next_position_h = full_screen_height
        elseif dir == 'left-third' then
            next_position_x = one_sixth_screen_width
            next_position_y = 0
            next_position_w = one_third_screen_width
            next_position_h = full_screen_height
        elseif dir == 'right-third' then
            next_position_x = one_half_screen_width
            next_position_y = 0
            next_position_w = one_third_screen_width
            next_position_h = full_screen_height
        else
            print(string.format('unknown direction: %s', dir))
            return
        end

        local_focused_window_coords.x = next_position_x
        local_focused_window_coords.y = next_position_y
        local_focused_window_coords.w = next_position_w
        local_focused_window_coords.h = next_position_h
        print(string.format('moving to position x:%s y:%s w:%s h:%s', next_position_x, next_position_y, next_position_w, next_position_h))

        absolute_focused_window_coords = focused_window:screen():localToAbsolute(local_focused_window_coords)
        focused_window:setFrame(absolute_focused_window_coords)

        -- Track this fullscreened Terminal window so the refill timer can
        -- re-fill it after opening a tab shrinks and re-centers it. Untrack on
        -- any other move so the timer stops pinning a window the user has
        -- since repositioned elsewhere.
        if focused_window:application():name() == 'Terminal' then
            if dir == 'fullscreen' then
                terminal_fullscreen_target = absolute_focused_window_coords
                terminal_refill_screen_id = focused_window:screen():id()
            else
                terminal_fullscreen_target = nil
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
    print(report)
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
terminal_refill_timer = hs.timer.doEvery(0.1, function()
    if terminal_fullscreen_target == nil then
        return
    end

    local app = hs.application.get('Terminal')
    if app == nil then
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
