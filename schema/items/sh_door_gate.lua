--[[
    Metal Gate

    A metal gate with 175 HP and medium battering ram resistance.
    See-through design.
]]--

ITEM.name = "Metal Gate"
ITEM.description = "A metal security gate. See-through but sturdy."
ITEM.model = "models/props_c17/gate_door01a.mdl"
ITEM.base = "base_doors"

-- Metal gate stats
ITEM.doorType = "gate"
ITEM.maxHealth = 175
ITEM.ramResistance = 0.65  -- Takes 65% damage from battering ram (medium resistance)
ITEM.fistDamageable = false  -- Cannot be damaged by fists
