--[[
    Windswept Colony RP - Client Schema
]]--

-- The currency split dialog is handled by the framework (ws.currency / sh_currency.lua's
-- CLIENT net.Receive("wsCurrencySplit"), which routes the confirm through ws.action). Do NOT
-- re-register it here -- the schema loads after the framework, so a duplicate handler would
-- silently override the canonical one.

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
