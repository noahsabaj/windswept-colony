--[[
    ADMINISTRATION CLASS: Governor
    ELECTED political leader of the colony.
    
    This is one of the three elected positions in the colony.
    The Governor:
    - Leads the colonial government
    - Appoints all administrative positions
    - Sets laws and policies
    - Represents the colony to the Confederation
    
    Elected every 3 weeks by the workers.
    
    TECHNICALLY must obey the Head Foreman... but do they?
]]--

CLASS.name = "Governor"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "The elected leader of the colony. You make the laws. You answer to the people... and maybe the Foreman."

function CLASS:OnCanBe(client)
    return client:IsAdmin() -- Only set by admins after election
end

function CLASS:OnSet(client)
    client:ChatPrint("You are now the Governor. Lead wisely - or don't. The choice is yours.")
end

CLASS_GOVERNOR = CLASS.index
