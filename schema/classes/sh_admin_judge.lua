--[[
    ADMINISTRATION CLASS: Colonial Judge
    APPOINTED by the Governor.
    
    Handles legal matters in the colony.
]]--

CLASS.name = "Colonial Judge"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "The arbiter of colonial law. You judge disputes, crimes, and conflicts."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed Colonial Judge.")
end

CLASS_JUDGE = CLASS.index
