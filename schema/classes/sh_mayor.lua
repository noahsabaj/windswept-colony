--[[
    ADMINISTRATION CLASS: Mayor
    ELECTED political leader of the colony.
    
    This is one of the three elected positions in the colony.
    The Mayor:
    - Leads the redrock city government
    - Appoints all administrative positions
    - Sets laws and policies
    - Represents the colony to the Confederation
    
    Elected every 3 weeks by the workers.
    
    TECHNICALLY must obey the Head Foreman... but do they?
]]--

CLASS.name = "Mayor"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "The elected leader of the city. You make the laws. You answer to the people... and maybe the Foreman."

function CLASS:OnCanBe(client)
    return client:IsAdmin() -- Only set by admins after election
end

function CLASS:OnSet(client)
    client:ChatPrint("You are now the Mayor. Lead wisely - or don't. The choice is yours.")
end

CLASS_MAYOR = CLASS.index