--[[
    WORKER CLASS: Mechanic
    Keep the machines running.
]]--

CLASS.name = "Mechanic"
CLASS.faction = FACTION_CIVILIANS
CLASS.isDefault = false
CLASS.description = "You repair and maintain the colony's machinery. Without you, everything stops."

function CLASS:OnSet(client)
    -- Called when a player becomes this class
end

function CLASS:OnCanBe(client)
    return true
end

CLASS_MECHANIC = CLASS.index
