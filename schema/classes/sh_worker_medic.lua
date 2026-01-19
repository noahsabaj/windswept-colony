--[[
    WORKER CLASS: Medic
    Colony healthcare workers.
]]--

CLASS.name = "Medic"
CLASS.faction = FACTION_CIVILIANS
CLASS.isDefault = false
CLASS.description = "You provide medical care to the colonists. In a place this dangerous, you're never short on patients."

function CLASS:OnSet(client)
    -- Called when a player becomes this class
end

function CLASS:OnCanBe(client)
    return true
end

CLASS_MEDIC = CLASS.index
