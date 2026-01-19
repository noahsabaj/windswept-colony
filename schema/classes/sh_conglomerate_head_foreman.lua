--[[
    CONGLOMERATE CLASS: Head Foreman
    APPOINTED by the Confederation (server owner).
    
    The corporate representative. NOT elected. NO term limit.
    
    The Head Foreman:
    - Oversees the mining operation
    - Represents the Conglomerate's interests
    - Appoints corporate staff
    - TECHNICALLY the Governor and Security Chief must obey them
    
    But the Confederation protects worker rights...
    And the workers have votes, unions, and numbers...
    
    How much power does the Foreman really have?
]]--

CLASS.name = "Head Foreman"
CLASS.faction = FACTION_CONGLOMERATE
CLASS.isDefault = false
CLASS.description = "The Conglomerate's representative. You're not elected. You answer only to the corporation and the Confederation."

function CLASS:OnCanBe(client)
    return client:IsSuperAdmin() -- Only superadmins/owner can set this
end

function CLASS:OnSet(client)
    client:ChatPrint("You are the Head Foreman. The Conglomerate's will is your command. Make this operation profitable.")
end

CLASS_HEAD_FOREMAN = CLASS.index
