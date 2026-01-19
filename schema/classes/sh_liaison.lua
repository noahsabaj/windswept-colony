--[[
    Corporate Liaison - Appointed by Head Foreman
    Handles communications between the colony and the Conglomerate.
]]--

CLASS.name = "Corporate Liaison"
CLASS.faction = FACTION_CONGLOMERATE
CLASS.isDefault = false
CLASS.description = "Interface between the colony and corporate headquarters."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Head Foreman."
end

CLASS_LIAISON = CLASS.index
