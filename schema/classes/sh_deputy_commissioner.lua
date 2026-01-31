--[[
    SECURITY CLASS: Deputy Commissioner
    APPOINTED by the Commissioner.
    
    Second in command of Security Department.
]]--

CLASS.name = "Deputy Commissioner"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "The Commissioner's right hand. You command when they're absent."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed Deputy Commissioner.")
end

CLASS_DEPUTY_COMMISSIONER = CLASS.index