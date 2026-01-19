--[[
    Deputy Chief - Appointed by Security Chief
    Second in command of Security.
]]--

CLASS.name = "Deputy Chief"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "Second in command of Colonial Security. Appointed by the Chief."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Security Chief."
end

CLASS_DEPUTY_CHIEF = CLASS.index
