function toggleBluetoothEnabled()
    return function()
        print('toggleBluetoothEnabled')
        -- Run in the background so the headphone connect retries don't freeze Hammerspoon.
        hs.task.new(os.getenv('HOME') .. '/.dot-star/tools/hammerspoon/toggle_bluetooth.sh', function(exitCode, stdOut, stdErr)
            print(stdOut, stdErr)
        end):start()
    end
end
hs.hotkey.bind({'option'}, 'b', toggleBluetoothEnabled())
