--[[
    Metal Door

    A reinforced metal door with 250 HP and high battering ram resistance.
]]--

ITEM.name = "Metal Door"
ITEM.description = "A reinforced metal door. Provides superior security."
ITEM.model = "models/props_doors/door03_slotted_left.mdl"
ITEM.base = "base_doors"

-- Metal door stats
ITEM.doorType = "metal"
ITEM.maxHealth = 250
ITEM.ramResistance = 0.4  -- Takes 40% damage from battering ram (high resistance)
ITEM.fistDamageable = false  -- Cannot be damaged by fists
