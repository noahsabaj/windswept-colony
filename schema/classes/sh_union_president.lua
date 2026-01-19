--[[
    Union President - ELECTED
    
    Leader of the Miners Union, elected by the Workers.
    Appoints all Union officials.
    3-week terms, unlimited re-election.
    
    The Union President must choose their battles:
    Fight the colonial administration, or fight the Conglomerate?
]]--

CLASS.name = "Union President"
CLASS.faction = FACTION_UNION
CLASS.isDefault = false
CLASS.description = "Elected leader of the Miners Union. Voice of the workers."

function CLASS:OnCanBe(client)
    return false, "This position must be assigned through election."
end

CLASS_UNION_PRESIDENT = CLASS.index
