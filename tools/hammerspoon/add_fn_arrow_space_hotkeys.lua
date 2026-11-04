-- Make Fn+Left/Right switch Spaces the way Ctrl+Left/Right does, giving up their Home/End meaning.
-- Re-post the press as Ctrl+arrow rather than switching here, so macOS keeps its slide animation and the wrapping tap still handles the edges.

local function arrowFor(keyCode)
    if keyCode == hs.keycodes.map.home then
        return 'left'
    elseif keyCode == hs.keycodes.map['end'] then
        return 'right'
    end
    return nil
end

-- Match Fn alone; leave Shift+Fn (select to line start/end) and other chords alone.
local function isFnOnly(flags)
    if not flags.fn then
        return false
    elseif flags.alt or flags.cmd or flags.ctrl or flags.shift then
        return false
    end
    return true
end

-- Post both halves with the fn flag set, since macOS ignores a synthetic Ctrl+arrow for Space switching without it.
local function postCtrlArrow(arrow)
    local flags = {'ctrl', 'fn'}
    hs.eventtap.event.newKeyEvent(flags, arrow, true):post()
    hs.eventtap.event.newKeyEvent(flags, arrow, false):post()
end

-- Keep the tap global so garbage collection doesn't stop it.
fnArrowSpaceHotkeysTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local arrow = arrowFor(event:getKeyCode())
    if arrow == nil then
        return false
    elseif not isFnOnly(event:getFlags()) then
        return false
    end
    print('fnArrowSpaceHotkeys: Fn+' .. arrow .. ' -> Ctrl+' .. arrow)
    postCtrlArrow(arrow)
    return true
end)
fnArrowSpaceHotkeysTap:start()
