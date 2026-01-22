--[[
    ADMINISTRATION FACTION
    
    The city government of Zephyrus.
    
    The Mayor is ELECTED by the workers every 3 weeks.
    The Mayor then APPOINTS all administrative positions:
    - Deputy Mayor
    - Judge
    - Quartermaster
    - Medical Officer
    - Communications Officer
    - Etc.
    
    They make the laws, manage resources, and represent the colony.
    But they must balance worker demands, corporate pressure, and security concerns.
]]--

FACTION.name = "Administration"
FACTION.description = "The city government. You manage, legislate, and administrate. Your Mayor is elected by the people."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false

-- Administration models (more formal appearance)
FACTION.models = {
    "models/player/breen.mdl",
    "models/player/group01/male_01.mdl",
    "models/player/group01/male_02.mdl",
    "models/player/group01/female_01.mdl",
    "models/player/group01/female_02.mdl"
}

-- Pay for administration
FACTION.pay = 75

function FACTION:OnCharacterCreated(client, character)
    -- Starting equipment for administration
    -- character:GetInventory():Add("clipboard", 1)
    -- character:GetInventory():Add("id_badge", 1)
end

FACTION_ADMINISTRATION = FACTION.index
