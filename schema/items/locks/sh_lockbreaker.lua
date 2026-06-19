--[[
    Lockbreaker

    A large saw-like tool that destroys locks through brute force.
    - RMB on lock: 20-second loud destruction
    - Creaking metal sound during operation
    - Loud SNAP when complete
    - Destroys lock completely (removed from door)
    - Door becomes lockless

    This is a loud, obvious method - not stealthy like lockpicking.
]]--

ITEM.name = "Lockbreaker"
ITEM.description = "A heavy-duty tool for destroying locks. Very loud."
ITEM.model = "models/weapons/w_crowbar.mdl"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Tools"
ITEM.noBusiness = true
ITEM.class = "ix_lockbreaker"
ITEM.weaponCategory = "lockbreaker"
ITEM.base = "base_equippable"

-- Equippable configuration
ITEM.equipWeaponClass = "ix_lockbreaker"
ITEM.equipPlayerKey = "wsLockbreakerItem"
ITEM.equipNotifyKey = "lockbreakerEquipped"
ITEM.equipSound = "physics/metal/metal_box_impact_hard1.wav"
ITEM.equipTip = "Hold the lockbreaker to destroy locks."
ITEM.unequipTip = "Put the lockbreaker away."
