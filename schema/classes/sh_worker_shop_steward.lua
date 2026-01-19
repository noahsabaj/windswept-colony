--[[
    WORKER CLASS: Shop Steward
    APPOINTED by the Union President.
    
    Union officials who help manage union affairs and represent
    workers in specific areas or departments.
]]--

CLASS.name = "Shop Steward"
CLASS.faction = FACTION_CIVILIANS
CLASS.isDefault = false
CLASS.description = "A union official appointed by the Union President. You help organize and represent workers in your area."

function CLASS:OnCanBe(client)
    -- Should be set by Union President or admin
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed as a Shop Steward.")
end

CLASS_SHOP_STEWARD = CLASS.index
