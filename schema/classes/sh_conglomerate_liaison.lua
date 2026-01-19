--[[
    CONGLOMERATE CLASS: Corporate Liaison
    APPOINTED by the Head Foreman.
    
    Handles communications between the Conglomerate and other factions.
]]--

CLASS.name = "Corporate Liaison"
CLASS.faction = FACTION_CONGLOMERATE
CLASS.isDefault = false
CLASS.description = "You represent corporate interests in negotiations with the government and union."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed Corporate Liaison.")
end

CLASS_CORPORATE_LIAISON = CLASS.index
