--[[
    WORKER CLASS: Miner
    The backbone of the colony's economy.
]]--

CLASS.name = "Miner"
CLASS.faction = FACTION_CIVILIANS
CLASS.isDefault = false
CLASS.description = "You extract resources from the depths of Zephyrus. Dangerous work, essential work."

function CLASS:OnSet(client)
    -- Called when a player becomes this class
end

function CLASS:OnCanBe(client)
    -- Anyone in the worker faction can be a miner
    return true
end

CLASS_MINER = CLASS.index
