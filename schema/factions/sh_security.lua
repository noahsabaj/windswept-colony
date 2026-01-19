--[[
    SECURITY FACTION
    
    Colonial Security - the police force of Zephyrus.
    
    The Security Chief is ELECTED by the workers every 3 weeks.
    The Chief then APPOINTS all officers below them.
    
    They answer to the people... in theory.
    The Head Foreman and Governor may have other ideas.
    
    Key tensions:
    - Do they serve the workers who elected their Chief?
    - Do they obey the Governor's laws?
    - Do they enforce the Foreman's corporate directives?
    - Or do they serve themselves?
]]--

FACTION.name = "Security"
FACTION.description = "Colonial Security. You keep the peace. Your Chief is elected. Your loyalty is... complicated."
FACTION.color = Color(70, 130, 180) -- Steel blue
FACTION.isDefault = false

-- Security models (more uniformed appearance)
FACTION.models = {
    "models/player/police.mdl",
    "models/player/police_fem.mdl"
}

-- Pay for security (if using salary system)
FACTION.pay = 50

function FACTION:OnCharacterCreated(client, character)
    -- Starting equipment for security
    -- character:GetInventory():Add("security_uniform", 1)
    -- character:GetInventory():Add("radio", 1)
end

FACTION_SECURITY = FACTION.index
