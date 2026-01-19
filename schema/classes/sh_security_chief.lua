--[[
    SECURITY CLASS: Security Chief
    ELECTED commander of Colonial Security.
    
    This is one of the three elected positions in the colony.
    The Security Chief:
    - Commands all security personnel
    - Appoints officers and deputies
    - Enforces (or doesn't enforce) the law
    - Must balance: worker votes, Governor's orders, Foreman's demands
    
    Elected every 3 weeks by the workers.
]]--

CLASS.name = "Security Chief"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "The elected commander of Colonial Security. You have the guns. Who do you serve?"

function CLASS:OnCanBe(client)
    return client:IsAdmin() -- Only set by admins after election
end

function CLASS:OnSet(client)
    client:ChatPrint("You are now the Security Chief. The colony's safety - and its oppression - is in your hands.")
end

CLASS_SECURITY_CHIEF = CLASS.index
