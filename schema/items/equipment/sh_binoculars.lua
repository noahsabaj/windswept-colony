--[[
    Binoculars Item

    Used to see far distances.
    Equip to use as a SWEP.
]]--

ITEM.name = "Binoculars"
ITEM.description = "A pair of binoculars for seeing far distances."
ITEM.model = Model("models/weapons/w_binocularsbp.mdl")
ITEM.width = 2
ITEM.height = 1
ITEM.price = 75
ITEM.category = "Equipment"
ITEM.base = "base_equippable"

-- Equippable configuration
ITEM.equipWeaponClass = "ix_binoculars"
ITEM.equipPlayerKey = "wsBinocularsItem"
ITEM.equipNotifyKey = "binocularsEquipped"
ITEM.equipTip = "Hold the binoculars in your hands."
ITEM.unequipTip = "Put the binoculars away."
