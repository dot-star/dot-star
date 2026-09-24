-- Keep open() global so a per-machine sibling module can bind its own apps with it.
function open(name)
   return function()
      -- Use launchOrFocus first. activate() never opens a window for an app that has none.
      if not hs.application.launchOrFocus(name) then
         -- Focus a running process that has no app bundle, which launchOrFocus can't find by name.
         local app = hs.application.get(name)
         if app then
            app:activate()
         end
      end
   end
end

hs.hotkey.bind({'option'}, 'c', open('Google Chrome.app'))
hs.hotkey.bind({'option'}, 'f', open('Firefox Developer Edition.app'))
hs.hotkey.bind({'option'}, 'g', open('wish'))
hs.hotkey.bind({'option'}, 'k', open('Slack'))
hs.hotkey.bind({'option'}, 'm', open('VLC.app'))
hs.hotkey.bind({'option'}, 'o', open('Finder.app'))
hs.hotkey.bind({'option'}, 'p', open('Preview.app'))
hs.hotkey.bind({'option'}, 's', open('Activity Monitor.app'))
hs.hotkey.bind({'option'}, 't', open('iTunes.app'))
hs.hotkey.bind({'option'}, 'v', open('MacVim'))
hs.hotkey.bind({'option'}, 'y', open('Visual Studio Code.app'))
hs.hotkey.bind({'option'}, 'z', open('zoom.us.app'))
