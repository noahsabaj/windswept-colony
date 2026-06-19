--[[
    Battering Ram

    A heavy breaching tool used by Security to execute warrants and force entry.
    Can be illegally procured for unauthorized use.
]]--

ITEM.name = "Battering Ram"
ITEM.description = "A heavy steel breaching tool used to force entry through locked doors. Standard issue for Security personnel executing warrants."
ITEM.model = "models/props_c17/tools/toolbox01.mdl"
ITEM.class = "ix_batteringram"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Equipment"
ITEM.base = "base_equippable"

-- Equippable configuration
ITEM.equipWeaponClass = "ix_batteringram"
ITEM.equipPlayerKey = "wsBatteringRamItem"
ITEM.equipNotifyKey = "batteringRamEquipped"
ITEM.equipTip = "Hold the battering ram in your hands."
ITEM.unequipTip = "Put the battering ram away."
