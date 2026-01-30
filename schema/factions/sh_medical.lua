--[[
    MEDICAL FACTION
    
    Redrock City Medical Department - the medical staff at Redrock City, working at the hospital.

    The Hospital is Redrock City General Hospital.

    The leader of the hospital is the Chief Medical Officer.
    The Chief Medical Officer reports to and is appointed by the Mayor.
    The Chief Medical Officer then appoints all medical staff below them.

    They provide medical care to all patients and residents of Redrock City.
    They report to the Mayor and work closely with Redrock City Security.
    They also ensure the hospital can function as a medical resource for the colony,
    overseeing patient care and coordinating with civilian supervisors.
]]--

FACTION.name = "Medical"
FACTION.description = "Redrock City Medical Department. You provide medical care at Redrock City. Your Chief Medical Officer is appointed by the Mayor."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false

-- Medical models (more uniformed appearance)
FACTION.models = {
    "models/player/kleiner.mdl",
    "models/player/alyx.mdl"
}

-- Pay for medical (if using salary system)
FACTION.pay = 70

function FACTION:OnCharacterCreated(client, character)
    -- Starting equipment for medical
    -- character:GetInventory():Add("medical_uniform", 1)
    -- character:GetInventory():Add("radio", 1)
end

FACTION_MEDICAL = FACTION.index