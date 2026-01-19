--[[
    WORKER CLASS: Union President
    ELECTED leader of the Workers' Union.
    
    This is one of the three elected positions in the colony.
    The Union President:
    - Speaks for the workers
    - Can call strikes
    - Negotiates with Administration and the Conglomerate
    - Appoints union officials (Shop Stewards)
    
    Elected every 3 weeks by the workers.
]]--

CLASS.name = "Union President"
CLASS.faction = FACTION_CIVILIANS
CLASS.isDefault = false
CLASS.description = "The elected voice of the workers. You represent their interests against corporate greed and government overreach."

-- This class should only be set by admins/election system
function CLASS:OnCanBe(client)
    return client:IsAdmin() -- Only admins can set this (after election)
end

function CLASS:OnSet(client)
    client:ChatPrint("You are now the Union President. The workers are counting on you.")
end

CLASS_UNION_PRESIDENT = CLASS.index
