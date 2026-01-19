--[[
    Governor - ELECTED
    
    Political leader of the colony, elected by the Workers.
    Appoints all Administration personnel.
    3-week terms, unlimited re-election.
    
    The Governor sets policy, but must navigate between the demands
    of the workers, the Conglomerate, and the Security apparatus.
]]--

CLASS.name = "Governor"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "Elected leader of the colony. The people's representative."

function CLASS:OnCanBe(client)
    return false, "This position must be assigned through election."
end

CLASS_GOVERNOR = CLASS.index
