--[[
    WORKER CLASS: Merchant
    Business owners and traders.
]]--

CLASS.name = "Merchant"
CLASS.faction = FACTION_CIVILIANS
CLASS.isDefault = false
CLASS.description = "You run a business in the colony. Restaurants, shops, services - commerce keeps the colony alive."

function CLASS:OnSet(client)
    -- Called when a player becomes this class
end

function CLASS:OnCanBe(client)
    return true
end

CLASS_MERCHANT = CLASS.index
