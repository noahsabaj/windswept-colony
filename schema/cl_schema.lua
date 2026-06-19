--[[
    Windswept Colony RP - Client Schema
]]--

-- ============================================================================
-- CURRENCY SPLIT DIALOG
-- ============================================================================

-- Receive split dialog request from server
net.Receive("wsCurrencySplit", function()
    local itemID = net.ReadUInt(32)
    local maxQuantity = net.ReadUInt(16)
    local itemType = net.ReadString()

    local unitName = itemType == "cash" and "dollars" or "cents"
    local defaultSplit = math.floor(maxQuantity / 2)

    Derma_StringRequest(
        "Split Stack",
        "How many " .. unitName .. " do you want to split off?\n(Max: " .. (maxQuantity - 1) .. ")",
        tostring(defaultSplit),
        function(text)
            local amount = tonumber(text)
            if not amount or amount <= 0 then
                LocalPlayer():Notify("Invalid amount.")
                return
            end

            if amount >= maxQuantity then
                LocalPlayer():Notify("Cannot split off the entire stack.")
                return
            end

            net.Start("wsCurrencySplitConfirm")
                net.WriteUInt(itemID, 32)
                net.WriteUInt(math.floor(amount), 16)
            net.SendToServer()
        end,
        nil,
        "Split",
        "Cancel"
    )
end)

-- ============================================================================
-- RADIO FREQUENCY DIALOG
-- ============================================================================

-- Receive frequency dialog request from server
netstream.Hook("wsRadioFrequency", function(currentFreq)
    -- Remove existing panel if open
    if IsValid(ws.gui.radioFrequency) then
        ws.gui.radioFrequency:Remove()
    end

    ws.gui.radioFrequency = vgui.Create("wsRadioFrequency")
    ws.gui.radioFrequency:SetFrequency(currentFreq)
end)
