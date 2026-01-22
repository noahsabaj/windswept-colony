--[[
    CORRECTIONS FACTION
    
    Colonial Corrections - the prison guards at Skarn Prison.

    The leader of corrections is the Prison Director.
    The Prison director reports to and is appointed by the Security Chief.
    The Director then appoints all guards below them.

    They maintain order among the prisoners and ensure security protocols are followed.
    They report to the Security Chief and work closely with Colonial Security.

    They also ensure the prison can function as a labor source for the colony,
    overseeing prisoner work details and coordinating with civilian supervisors.
]]--

FACTION.name = "Corrections"
FACTION.description = "Colonial Corrections. You maintain order at Skarn Prison. Your Director is appointed by the Security Chief."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false

-- Corrections models (more uniformed appearance)
FACTION.models = {
    "models/player/police.mdl",
    "models/player/police_fem.mdl"
}

-- Pay for corrections (if using salary system)
FACTION.pay = 60

function FACTION:OnCharacterCreated(client, character)
    -- Starting equipment for corrections
    -- character:GetInventory():Add("corrections_uniform", 1)
    -- character:GetInventory():Add("radio", 1)
end

FACTION_CORRECTIONS = FACTION.index