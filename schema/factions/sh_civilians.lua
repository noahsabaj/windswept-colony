--[[
    CIVILIANS
    
    The backbone of the colony. Every colonist starts here.
    Civilians perform the labor that keeps Zephyrus running - mining,
    maintenance, food service, medicine, and everything else.
    
    Workers elect the three pillars of colonial government:
    - Governor
    - Security Chief  
    - Union President (only Miners)
    
    They are represented by the Miners Union (workers that are miners) and protected (in theory)
    by the Confederation of Earthly Governments.
]]--

FACTION.name = "Civilians"
FACTION.description = "The residents of Redrock City, Zephyrus. "
FACTION.color = Color(180, 150, 100)
FACTION.isDefault = true

-- Default models for workers
FACTION.models = {
    "models/player/group01/male_01.mdl",
    "models/player/group01/male_02.mdl",
    "models/player/group01/male_03.mdl",
    "models/player/group01/male_04.mdl",
    "models/player/group01/male_05.mdl",
    "models/player/group01/male_06.mdl",
    "models/player/group01/male_07.mdl",
    "models/player/group01/male_08.mdl",
    "models/player/group01/male_09.mdl",
    "models/player/group01/female_01.mdl",
    "models/player/group01/female_02.mdl",
    "models/player/group01/female_03.mdl",
    "models/player/group01/female_04.mdl",
    "models/player/group01/female_05.mdl",
    "models/player/group01/female_06.mdl"
}

-- Called when a player creates a character in this faction
function FACTION:OnCharacterCreated(client, character)
    -- Starting equipment or actions can go here
end

-- Store the faction index globally
FACTION_CIVILIANS = FACTION.index
