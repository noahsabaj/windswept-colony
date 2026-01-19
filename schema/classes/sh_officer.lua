--[[
    Officer - Appointed by Security leadership
    Standard security personnel.
]]--

CLASS.name = "Officer"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "A Colonial Security officer. Serve and protect."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by Security leadership."
end

CLASS_OFFICER = CLASS.index
