--[[
    Radio (Colony bridge)

    The radio voice ENGINE lives in the framework `radio` plugin. This bridge enables it
    and wires the Colony radio content into the engine's seams. The handheld and
    stationary radio items + the frequency UI stay as Colony content and call the (now
    framework) ws.radio.* API.
]]--

local PLUGIN = PLUGIN

PLUGIN.name = "Windswept Radio"
PLUGIN.author = "Windswept"
PLUGIN.description = "Colony radio content: enables the framework radio engine and registers the Colony radios."

ws.util.Include("sv_plugin.lua")

-- Wire the Colony radio content into the framework voice engine.
ws.radio.itemID = "handheld_radio"
ws.radio.stationaryClass = "ws_stationary_radio"
ws.radio.eavesdropBase = ws.constants.RANGE_EAVESDROP_BASE

-- Enable the physical radio voice system for Colony RP (off in the framework by default).
-- InitializedConfig fires during config load and re-fires after the saved config, so it
-- both lands before any voice query and wins over a persisted value.
hook.Add("InitializedConfig", "wsColonyEnableRadio", function()
    ws.config.Set("radioEnabled", true)
end)
