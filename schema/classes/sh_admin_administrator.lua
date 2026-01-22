--[[
    ADMINISTRATION CLASS: Administrator
    APPOINTED by the Mayor.
    
    Default class for administration faction members.
]]--

CLASS.name = "Administrator"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = true
CLASS.description = "A colonial administrator. You handle the paperwork that keeps the colony running."

function CLASS:OnCanBe(client)
    return true
end

function CLASS:OnSet(client)
    client:ChatPrint("You are now an Administrator.")
end

CLASS_ADMINISTRATOR = CLASS.index
