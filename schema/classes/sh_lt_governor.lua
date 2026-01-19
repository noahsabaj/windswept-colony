--[[
    Lieutenant Governor - Appointed by Governor
    Second in command, handles day-to-day administration.
]]--

CLASS.name = "Lieutenant Governor"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "Second in command of colonial administration."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Governor."
end

CLASS_LT_GOVERNOR = CLASS.index
