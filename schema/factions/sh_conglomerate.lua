--[[
    CONGLOMERATE FACTION

    Eagle Extraction Conglomerate (EEC)
    
    Representatives of the mining corporation that holds the license to Zephyrus.
    
    The Head Foreman is APPOINTED by the Confederation (server owner).
    They are NOT elected. They have no term limit.
    They represent corporate interests above all else.
    
    The Head Foreman appoints:
    - Shift Supervisors
    - Corporate Liaisons
    - Resource Managers
    - Etc.
    
    TECHNICALLY, the Mayor and Commissioner must obey the Foreman.
    The Conglomerate holds the mining license. No Conglomerate = no colony.
    
    But the Confederation protects worker rights...
    And the workers have unions, votes, and numbers.
    
    How much power does the Foreman really have?
]]--

FACTION.name = "Conglomerate"
FACTION.description = "Corporate representatives. You serve the mining company. You're not elected. You answer only to the Confederation."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false

-- Conglomerate models (corporate appearance)
FACTION.models = {
    "models/player/breen.mdl",
    "models/player/magnusson.mdl",
    "models/player/kleiner.mdl"
}

-- Pay for conglomerate (highest, they're corporate)
FACTION.pay = 150

function FACTION:OnCharacterCreated(client, character)
    -- Starting equipment for conglomerate
    -- character:GetInventory():Add("corporate_id", 1)
    -- character:GetInventory():Add("datapad", 1)
end

FACTION_CONGLOMERATE = FACTION.index
