--[[
    Sergeant - Appointed by Security leadership
    Supervises officers, leads patrols.
]]--

CLASS.name = "Sergeant"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "A non-commissioned officer in Colonial Security."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by Security leadership."
end

CLASS_SERGEANT = CLASS.index
