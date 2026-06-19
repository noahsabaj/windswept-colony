--[[
    Flashlight

    A portable flashlight with a single battery slot.
    Accepts batteries of any charge level (0-100up).
    Drains ~0.083up per second when on (~20 minutes per full battery).

    Batteries not included when purchased.
]]--

ITEM.name = "Flashlight"
ITEM.description = "A portable flashlight. Can be used as a makeshift weapon."
ITEM.model = "models/shaky/weapons/flashlight/w_flashlight.mdl"
ITEM.base = "base_battery_device"
ITEM.width = 1
ITEM.height = 2
ITEM.category = "Equipment"
ITEM.noBusiness = true

-- Battery device configuration
ITEM.maxBatteries = 1
ITEM.weaponClass = "ix_flashlight"
ITEM.playerItemKey = "wsFlashlightItem"
ITEM.equipSound = "items/flashlight1.wav"
ITEM.notifyPrefix = "flashlight"
ITEM.hasLightToggle = true
