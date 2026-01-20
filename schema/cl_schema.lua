--[[
    Windswept Colony RP - Client Schema
]]--

-- ============================================================================
-- RADIO FREQUENCY DIALOG
-- ============================================================================

-- Receive frequency dialog request from server
netstream.Hook("ixRadioFrequency", function(currentFreq)
    Derma_StringRequest(
        "Set Frequency",
        "Enter frequency (format: ###.#)",
        currentFreq,
        function(text)
            ix.command.Send("SetFreq", text)
        end
    )
end)
