--[[
    Rations - Basic food item
]]--

ITEM.name = "Rations"
ITEM.description = "Standard colony rations. Not tasty, but it keeps you alive."
ITEM.model = "models/props_junk/garbage_takeoutcarton001a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Food"

-- Functions for consumable items
ITEM.functions = {
    Eat = {
        OnRun = function(item)
            local client = item.player
            -- Add hunger restoration here when you implement a hunger system
            client:notify("You eat the bland rations.")
            return true -- Removes item after use
        end
    }
}
