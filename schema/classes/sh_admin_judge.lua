--[[
    ADMINISTRATION CLASS: City Judge
    APPOINTED by the Mayor.
    
    Handles legal matters in the city.
]]--

CLASS.name = "City Judge"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "The arbiter of city law. You judge disputes, crimes, and conflicts."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed Colonial Judge.")
end

CLASS_JUDGE = CLASS.index
