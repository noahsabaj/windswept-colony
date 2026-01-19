--[[
    SECURITY CLASS: Deputy Security Chief
    APPOINTED by the Security Chief.
    
    Second in command of Colonial Security.
]]--

CLASS.name = "Deputy Security Chief"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "The Security Chief's right hand. You command when they're absent."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed Deputy Security Chief.")
end

CLASS_DEPUTY_SECURITY_CHIEF = CLASS.index
