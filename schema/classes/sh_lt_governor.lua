--[[
    Deputy Mayor - Appointed by Mayor
    Second in command, handles day-to-day administration.
]]--

CLASS.name = "Deputy Mayor"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "Second in command of colonial administration."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Mayor."
end

CLASS_DEPUTY_MAYOR = CLASS.index