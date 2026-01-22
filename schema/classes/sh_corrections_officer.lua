--[[
    Corrections Officer - Default class for Corrections faction

    Guards at Skarn Prison.
    Appointed by the Warden.
]]--

CLASS.name = "Corrections Officer"
CLASS.faction = FACTION_CORRECTIONS
CLASS.isDefault = true
CLASS.description = "You maintain order at Skarn Prison. Guard the prisoners and enforce the rules."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Warden."
end

CLASS_CORRECTIONS_OFFICER = CLASS.index
