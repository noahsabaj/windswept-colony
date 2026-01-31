--[[
    Colonial Judge - Appointed by Mayor
    Interprets and enforces colonial law, presides over trials.
]]--

CLASS.name = "Judge"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.isAnchor = false  -- Not a leader class
CLASS.rank = 200        -- Appointed position (not in succession line)
CLASS.description = "The arbiter of colonial law. Justice on Zephyrus."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Mayor."
end

CLASS_JUDGE = CLASS.index
