--[[
    Windswept Doors (Colony bridge)

    The physical door/lock/key ENGINE now lives in the framework `doors` plugin. This
    Colony bridge enables that engine and wires in the Colony content through the
    engine's seams (which weapons damage doors, which SWEP reveals empty frames). It
    also carries the Colony-only door admin/test commands (sv) and the door SWEP UI (cl).
]]--

local PLUGIN = PLUGIN

PLUGIN.name = "Windswept Doors"
PLUGIN.author = "Windswept"
PLUGIN.description = "Colony door content: enables the framework door engine and wires in Colony doors, locks, and keys."

ws.util.Include("sv_plugin.lua")
ws.util.Include("cl_plugin.lua")

-- Register the Colony's door-damage sources with the framework engine (which carries no
-- weapon class names of its own): fists do 1 HP gated by the door's fistDamageable, and
-- the battering ram does damage scaled by the door's ramResistance.
ws.doors.RegisterDamageSource("ws_hands", { fist = true })
ws.doors.RegisterDamageSource("ws_batteringram", { ram = true })

-- The door-install SWEP whose empty-frame pulse the engine draws.
ws.doors.installToolClass = "ws_door"

-- Enable the physical door system for Colony RP (the framework ships it off by default).
-- InitializedConfig fires during config load (before the engine's InitPostEntity) and
-- re-fires after the saved config loads, so this both lands in time and wins over any
-- persisted value -- the same timing the old doorCost override relied on. (layer-doors)
hook.Add("InitializedConfig", "wsColonyEnableDoors", function()
    ws.config.Set("doorsEnabled", true)
end)
