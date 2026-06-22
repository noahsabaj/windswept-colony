--[[
    Radio (Colony bridge) - Server

    The handheld radio volume action. Kept on the Colony side because its ws.action
    item-guard is bound to the Colony "handheld_radio" uniqueID at register time.
]]--

-- Set radio volume. ws.action: item = "handheld_radio" + access = "owned" reproduces the
-- original ownership check (uniqueID == handheld_radio + held in the main inventory).
ws.action.Register("wsRadioVolumeSet", {
    item = "handheld_radio",
    access = "owned",
    read = function() return net.ReadUInt(7) end,  -- volume (UInt7 wire; clamped in run)
    run = function(client, ctx)
        ctx.item:SetData("volume", math.Clamp(ctx.data, 0, 100))
        client:NotifyLocalized("radioVolumeSet", ctx.data)
    end
})
