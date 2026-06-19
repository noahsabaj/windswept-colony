--[[
    Portable Ladder

    A collapsible aluminum ladder. Deploy it to climb surfaces,
    pick it back up when done.

    Controls (when equipped):
    - LMB: Deploy full ladder
    - RMB: Deploy short ladder
    - Hold E on deployed ladder: Pick it back up
]]--

ITEM.name = "Portable Ladder"
ITEM.model = Model("models/weapons/w_ladder.mdl")
ITEM.description = "A collapsible aluminum ladder. Deploy with LMB (full) or RMB (short). Hold E on a deployed ladder to pick it up."
ITEM.width = 4
ITEM.height = 4
ITEM.category = "Equipment"
ITEM.base = "base_equippable"

-- Ladder SWEP: https://steamcommunity.com/sharedfiles/filedetails/?id=3411066267
if SERVER then
    resource.AddWorkshop("3411066267")
end

-- Equippable configuration
ITEM.equipWeaponClass = "weapon_ladder_yl"
ITEM.equipPlayerKey = "wsLadderItem"
ITEM.equipNotifyKey = "ladderEquipped"
ITEM.equipTip = "Hold the ladder in your hands."
ITEM.unequipTip = "Put the ladder away."
