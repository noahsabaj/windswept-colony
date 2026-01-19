--[[
    Civilian - Default class for the Workers faction
    The basic colonist. Can specialize into other roles.
]]--

CLASS.name = "Civilian"
CLASS.faction = FACTION_CIVILIANS
CLASS.isDefault = true
CLASS.description = "A general laborer of the colony."

function CLASS:OnSet(client)
    -- Called when a player becomes this class
end

CLASS_WORKER = CLASS.index
