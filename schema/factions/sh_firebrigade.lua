--[[
    FIRE BRIGADE FACTION
    
    Redrock City Fire Brigade - the firefighting and rescue personnel at Redrock City.

    The leader of the fire brigade is the Fire Chief.
    The Fire Chief reports to and is appointed by the Mayor.
    The Fire Chief then appoints all fire brigade personnel below them.

    They provide firefighting and rescue services to all residents of Redrock City.
    They report to the Mayor and work closely with Colonial Security.

    They also ensure the fire brigade can function as an emergency response resource for the colony,
    overseeing rescue operations and coordinating with civilian supervisors.
]]--

FACTION.name = "Fire Brigade"
FACTION.description = "Redrock City Fire Brigade. You provide firefighting and rescue services at Redrock City. Your Fire Chief is appointed by the Mayor."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false
FACTION.subordinateOf = "administration"  -- Mayor appoints Fire Chief

-- Fire Brigade models (more uniformed appearance)
FACTION.models = {
    "models/player/kleiner.mdl",
    "models/player/alyx.mdl"
}

-- Pay for fire brigade (if using salary system)
FACTION.pay = 40

function FACTION:OnCharacterCreated(client, character)
    -- Starting equipment for fire brigade
    -- character:GetInventory():Add("firebrigade_uniform", 1)
    -- character:GetInventory():Add("radio", 1)
end

FACTION_FIREBRIGADE = FACTION.index