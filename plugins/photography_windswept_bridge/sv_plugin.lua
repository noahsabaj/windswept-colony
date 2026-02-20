local PLUGIN = PLUGIN

hook.Add("ixCameraCanTakePhoto", "WindsweptBatteryHook", function(client, cameraItem, bDrain)
    -- This hook is called right before taking a photo
    -- In Windswept, cameras use batteries.

    local batteries = cameraItem:GetData("batteries", {})
    if #batteries == 0 then
        client:NotifyLocalized("cameraNoBattery")
        return false -- Block photo
    end

    local drain = cameraItem.batteryDrainPerPhoto or 2
    if batteries[1] < drain then
        client:NotifyLocalized("cameraNoCharge")
        return false -- Block photo
    end

    if bDrain then
        -- Drain the battery
        batteries[1] = batteries[1] - drain
        cameraItem:SetData("batteries", batteries)

        -- Auto-eject depleted
        if batteries[1] <= 0 then
            if cameraItem.AutoEjectDepleted then
                cameraItem:AutoEjectDepleted(client)
            end
            if cameraItem.AutoLoadFromInventory then
                cameraItem:AutoLoadFromInventory(client)
            end
        end
    end
end)
