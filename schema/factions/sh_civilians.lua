--[[
    CIVILIANS

    All the workers and residents and inhabitants of Redrock City.
    
    The backbone of the colony. Every colonist starts here.
    Civilians perform the labor that keeps Zephyrus running - mining,
    maintenance, food service, medicine, and everything else.
    
    Workers elect the three pillars of colonial government:
    - Mayor
    - Commissioner  
    - Union President (only Miners)
    
    They are represented by the Miners Union (workers that are miners) and protected (in theory)
    by the Confederation of Earthly Governments.
]]--

FACTION.name = "Civilians"
FACTION.description = "The residents of Redrock City, Zephyrus. "
FACTION.color = Color(200, 200, 200) -- Light gray
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

-- Pay for civilians (if using salary system)
FACTION.pay = 0

-- Called when a player creates a character in this faction
function FACTION:OnCharacterCreated(client, character)
    -- Generate a unique 5-digit ID number
    local id = string.format("%05d", math.random(1, 99999))
    local inventory = character:GetInventory()

    -- Store the ID on the character for reference
    character:SetData("personalID", id)

    -- Get physical data stored during character creation
    local physical = character:GetData("physical", {})

    -- Give them their Personal ID card with physical attributes
    inventory:Add("personal_id", 1, {
        ownerName = character:GetName(),
        id = id,
        physical = physical
    })
end

-- Store the faction index globally
FACTION_CIVILIANS = FACTION.index
