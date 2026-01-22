--[[
    Warden - Head of Corrections

    Appointed by the Commissioner.
    Oversees Skarn Prison and all corrections staff.
]]--

CLASS.name = "Warden"
CLASS.faction = FACTION_CORRECTIONS
CLASS.isDefault = false
CLASS.description = "You oversee Skarn Prison and manage all corrections staff. Appointed by the Commissioner."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Commissioner."
end

CLASS_WARDEN = CLASS.index
