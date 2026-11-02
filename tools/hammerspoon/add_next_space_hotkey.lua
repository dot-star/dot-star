-- Go to the Space most in need of you on Option+N, in the order a closing session follows (`showSpacePosition.hopOrder`).
require('follow_closed_full_screen_space')
require('show_space_position')

local function goToNextSpace()
    local focused = hs.spaces.focusedSpace()
    local screen = hs.screen.find(hs.spaces.spaceDisplay(focused)) or hs.screen.mainScreen()
    local spaces = hs.spaces.spacesForScreen(screen) or {}
    local next = showSpacePosition.hopOrder(spaces, focused)[1]
    if next == nil then
        print('goToNextSpace: no other session or full-screen Space beside ' .. tostring(focused))
        return
    end
    print('goToNextSpace: Space ' .. focused .. ' -> ' .. next.space .. ' (' .. next.pickedBy .. ')')
    followClosedFullScreenSpace.goTo(next.space, next.windowId)
end

hs.hotkey.bind({'option'}, 'n', goToNextSpace)
