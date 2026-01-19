--[[
    WORKER CLASS: Colonist
    The default class for all workers.
]]--

CLASS.name = "Colonist"
CLASS.faction = FACTION_CIVILIANS
CLASS.isDefault = true
CLASS.description = "A regular colonist of Zephyrus. You work, you survive, you vote."

function CLASS:OnSet(client)
    -- Called when a player becomes this class
end

CLASS_COLONIST = CLASS.index
