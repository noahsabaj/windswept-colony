--[[
    ADMINISTRATION CLASS: Quartermaster
    APPOINTED by the Mayor.
    
    Manages city resources and supplies.
]]--

CLASS.name = "Quartermaster"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "You manage the city's resources, supplies, and distribution."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed Quartermaster.")
end

CLASS_QUARTERMASTER = CLASS.index
