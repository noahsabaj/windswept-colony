--[[
    Lantern

    A portable lantern with ambient light.
    - Single battery slot, accepts any charge (0-100up)
    - Drains ~0.167up per second when on (~10 minutes per full battery)
    - Can be placed on the ground (RMB when equipped)
    - Placed lanterns continue to drain and emit light
    - Pick up placed lanterns by holding E

    Batteries not included.
]]--

ITEM.name = "Lantern"
ITEM.description = "A portable lantern providing ambient light. Can be placed on the ground."
ITEM.model = "models/weapons/cof/w_lantern.mdl"
ITEM.base = "base_battery_device"
ITEM.width = 1
ITEM.height = 2
ITEM.category = "Equipment"
ITEM.noBusiness = true

-- Lantern model: Cry of Fear Lantern (provides models/weapons/cof/*)
-- https://steamcommunity.com/sharedfiles/filedetails/?id=132470017
if SERVER then
    resource.AddWorkshop("132470017")
end

-- Battery device configuration
ITEM.maxBatteries = 1
ITEM.weaponClass = "ws_lantern"
ITEM.playerItemKey = "wsLanternItem"
ITEM.equipSound = "physics/metal/metal_canister_impact_soft1.wav"
ITEM.notifyPrefix = "lantern"
ITEM.hasLightToggle = true
