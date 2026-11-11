function toggleWifiEnabled()
    return function()
        print('toggleWifiEnabled')
        local details = hs.wifi.interfaceDetails()
        if details == nil then
            print('toggleWifiEnabled: no Wi-Fi interface found')
            return
        end
        local power = not details.power
        print(string.format('toggleWifiEnabled: power %s', tostring(power)))
        hs.wifi.setPower(power)
        if power then
            hs.alert.show('Wi-Fi on')
        else
            hs.alert.show('Wi-Fi off')
        end
    end
end
hs.hotkey.bind({'option'}, 'w', toggleWifiEnabled())
