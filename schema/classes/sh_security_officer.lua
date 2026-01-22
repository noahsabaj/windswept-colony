--[[
    SECURITY CLASS: Security Officer
    APPOINTED by the Commissioner or Deputy Commissioner.
    
    The rank and file of Colonial Security.
]]--

CLASS.name = "Security Officer"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = true
CLASS.description = "A City Security officer. You keep the peace under the Commissioner's command."

function CLASS:OnCanBe(client)
    return true
end

function CLASS:OnSet(client)
    client:ChatPrint("You are now a Security Officer.")
end

CLASS_SECURITY_OFFICER = CLASS.index
