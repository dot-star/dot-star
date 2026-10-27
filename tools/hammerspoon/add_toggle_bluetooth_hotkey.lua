function toggleBluetoothEnabled()
    return function()
        print('toggleBluetoothEnabled')
        print(hs.execute(os.getenv('HOME') .. '/.dot-star/tools/hammerspoon/toggle_bluetooth.sh'))
    end
end
hs.hotkey.bind({'option'}, 'b', toggleBluetoothEnabled())
