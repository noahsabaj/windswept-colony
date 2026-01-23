--[[
    Windswept Colony RP - Client Schema
]]--

-- ============================================================================
-- RADIO FREQUENCY DIALOG
-- ============================================================================

-- Receive frequency dialog request from server
netstream.Hook("ixRadioFrequency", function(currentFreq)
    -- Remove existing panel if open
    if IsValid(ix.gui.radioFrequency) then
        ix.gui.radioFrequency:Remove()
    end

    ix.gui.radioFrequency = vgui.Create("ixRadioFrequency")
    ix.gui.radioFrequency:SetFrequency(currentFreq)
end)
