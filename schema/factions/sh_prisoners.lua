--[[
    PRISONERS FACTION
    
    You are a prisoner on Zephyrus.

    You have no rights, no votes, and no representation.
    You exist solely to serve your sentence.
]]--

FACTION.name = "Prisoners"
FACTION.description = "You are a prisoner."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false

-- Prisoner Playermodels (Workshop ID: 3582530445)
FACTION.models = {
    -- Male prisoners
    "models/player/aperture_science/male_01.mdl",
    "models/player/aperture_science/male_02.mdl",
    "models/player/aperture_science/male_03.mdl",
    "models/player/aperture_science/male_04.mdl",
    "models/player/aperture_science/male_05.mdl",
    "models/player/aperture_science/male_06.mdl",
    "models/player/aperture_science/male_07.mdl",
    "models/player/aperture_science/male_08.mdl",
    "models/player/aperture_science/male_09.mdl",
    -- Female prisoners
    "models/humans/testsubject_pm/female_01.mdl",
    "models/humans/testsubject_pm/female_02.mdl",
    "models/humans/testsubject_pm/female_03.mdl",
    "models/humans/testsubject_pm/female_04.mdl",
    "models/humans/testsubject_pm/female_06.mdl",
    "models/humans/testsubject_pm/female_07.mdl",
}

FACTION.pay = 0

-- Prevent selection during character creation - players are transferred here by judges
function FACTION:OnCanBe(client)
    return false, "You cannot choose to be a prisoner."
end

FACTION_PRISONERS = FACTION.index
