--[[
    Photography Windswept Bridge Plugin
    
    This plugin hooks into the standalone "photography" plugin
    and natively injects windswept's battery mechanics into the camera.
]]--

local PLUGIN = PLUGIN

PLUGIN.name = "Photography - Windswept Bridge"
PLUGIN.author = "Antigravity"
PLUGIN.description = "Injects Windswept battery dependencies into the standalone photography plugin."
PLUGIN.dependencies = {"photography"}

ws.util.Include("sv_plugin.lua")

-- We must wait for items to load before mutating the camera item
function PLUGIN:InitializedPlugins()
    local ITEM = ws.item.list["camera"]
    -- Fail loudly: the standalone camera must be loaded before this bridge can
    -- inject battery mechanics. (sc-photography-10)
    if not ITEM then
        ErrorNoHalt("[photography bridge] camera item not found; battery injection skipped.\n")
        return
    end

    -- 1. Inject Battery Base properties
    ITEM.base = "base_battery_device"
    ITEM.maxBatteries = 1
    ITEM.playerItemKey = "wsCameraItem"
    ITEM.batteryDrainPerPhoto = 2
    ITEM.hasLightToggle = false

    -- 2. Steal functions from the battery base and insert them into the camera
    -- (We have to do this manually because ws.item.Register has already run)
    local batteryBase = ws.item.base["base_battery_device"]
    -- Fail loudly rather than leaving the camera in a half-injected state (base set
    -- to base_battery_device but with no battery methods). (sc-photography-10)
    if not batteryBase then
        ErrorNoHalt("[photography bridge] base_battery_device missing; camera battery methods not injected.\n")
        return
    end

    if batteryBase then
        -- Copy over battery functions
        ITEM.GetBatteries = batteryBase.GetBatteries
        ITEM.SetBatteries = batteryBase.SetBatteries
        ITEM.GetBatteryCount = batteryBase.GetBatteryCount
        ITEM.HasBattery = batteryBase.HasBattery
        ITEM.HasUsableCharge = batteryBase.HasUsableCharge
        ITEM.GetFirstBatteryCharge = batteryBase.GetFirstBatteryCharge
        ITEM.FindBestBatteryInInventory = batteryBase.FindBestBatteryInInventory
        ITEM.FindFullBatteryInInventory = batteryBase.FindFullBatteryInInventory
        ITEM.AutoEjectDepleted = batteryBase.AutoEjectDepleted
        ITEM.AutoLoadFromInventory = batteryBase.AutoLoadFromInventory

        -- Copy over the Load/Eject battery inventory actions
        ITEM.functions.LoadBattery = batteryBase.functions.LoadBattery
        ITEM.functions.EjectBattery = batteryBase.functions.EjectBattery
        
        -- Override the old equip functions we gave the standalone camera
        -- with the battery-aware ones from the base
        ITEM.functions.Equip = batteryBase.functions.Equip
        ITEM.functions.Unequip = batteryBase.functions.Unequip
        
        ITEM.postHooks.drop = batteryBase.postHooks.drop
        ITEM.OnTransferred = batteryBase.OnTransferred
        ITEM.CanTransfer = batteryBase.CanTransfer
        ITEM.OnLoadout = batteryBase.OnLoadout
    end
end
