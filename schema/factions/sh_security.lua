--[[
    SECURITY FACTION
    
    Redrock City Security Department - the police force of Zephyrus.
    
    The Commissioner is ELECTED by the workers every 3 weeks.
    The Commissioner appoints the Deputy Commissioner, who is electorally attached to the Commissioner.
    The Commissioner then APPOINTS all officers below them.
    
    They answer to the people... in theory.
    The Head Foreman and Mayor may have other ideas.
    
    Key tensions:
    - Do they serve the workers who elected their Commissioner?
    - Do they obey the Mayor's laws?
    - Do they enforce the Foreman's corporate directives?
    - Or do they serve themselves?
]]--

FACTION.name = "Security"
FACTION.description = "Redrock City Security Department. You keep the peace. Your Commissioner is elected. Your loyalty is... complicated."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false
FACTION.subordinateOf = "confederation"  -- CEG oversees security

-- Security models (more uniformed appearance)
FACTION.models = {
    "models/player/police.mdl",
    "models/player/police_fem.mdl"
}

-- Pay for security (if using salary system)
FACTION.pay = 50

FACTION_SECURITY = FACTION.index
