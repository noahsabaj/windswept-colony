--[[
    SECURITY CLASS: Commissioner
    ELECTED commander of Security Department.
    
    This is one of the three elected positions in the colony.
    The Commissioner:
    - Commands all security personnel
    - Appoints officers and deputies
    - Enforces (or doesn't enforce) the law
    - Must balance: worker votes, Mayor's orders, Foreman's demands
    
    Elected every 3 weeks by the workers.
]]--

CLASS.name = "Commissioner"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "The elected commander of Security Department. You have the guns. Who do you serve?"

function CLASS:OnCanBe(client)
    return client:IsAdmin() -- Only set by admins after election
end

function CLASS:OnSet(client)
    client:ChatPrint("You are now the Commissioner. The colony's safety - and its oppression - is in your hands.")
end

CLASS_COMMISSIONER = CLASS.index