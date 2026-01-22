--[[
    Deputy Commissioner - Appointed by Commissioner
    Second in command of Security.
]]--

CLASS.name = "Deputy Commissioner"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "Second in command of Security Department. Appointed by the Commissioner."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Commissioner."
end

CLASS_DEPUTY_COMMISSIONER = CLASS.index