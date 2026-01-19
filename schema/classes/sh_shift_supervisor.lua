--[[
    Shift Supervisor - Appointed by Head Foreman
    Manages mining shifts and work crews.
]]--

CLASS.name = "Shift Supervisor"
CLASS.faction = FACTION_CONGLOMERATE
CLASS.isDefault = false
CLASS.description = "Oversees mining shifts and work crews."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Head Foreman."
end

CLASS_SHIFT_SUPERVISOR = CLASS.index
