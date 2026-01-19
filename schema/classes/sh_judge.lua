--[[
    Colonial Judge - Appointed by Governor
    Interprets and enforces colonial law, presides over trials.
]]--

CLASS.name = "Colonial Judge"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "The arbiter of colonial law. Justice on Zephyrus."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Governor."
end

CLASS_JUDGE = CLASS.index
