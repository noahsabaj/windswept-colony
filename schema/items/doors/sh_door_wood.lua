--[[
    Wood Door

    A wooden door with 100 HP and low battering ram resistance.
]]--

ITEM.name = "Wood Door"
ITEM.description = "A standard wooden door. Provides basic security."
ITEM.model = "models/props_c17/door01_left.mdl"
ITEM.base = "base_doors"

-- Wood door stats
ITEM.doorType = "wood"
ITEM.maxHealth = 100
ITEM.ramResistance = 1.0  -- Takes full damage from battering ram
ITEM.fistDamageable = true  -- Can be damaged by fists
