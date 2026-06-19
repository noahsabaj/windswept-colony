--[[
    Defibrillator

    Medical device that significantly improves revival chances.
    Has 4 battery slots - each shock consumes 1 entire battery.
    ONLY accepts fully charged batteries (100up).
]]--

ITEM.name = "Defibrillator"
ITEM.description = "A portable automated external defibrillator (AED)."
ITEM.model = "models/props_lab/reciever01a.mdl"
ITEM.base = "base_battery_device"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Medical"
ITEM.noBusiness = true

-- Battery device configuration
ITEM.maxBatteries = 4
ITEM.weaponClass = "ix_defibrillator"
ITEM.playerItemKey = "wsDefibItem"
ITEM.equipSound = "defibl/deploy.wav"
ITEM.notifyPrefix = "defib"
ITEM.requireFullBattery = true
ITEM.hasLightToggle = false

-- ============================================================================
-- DEFIBRILLATOR-SPECIFIC FUNCTIONS
-- ============================================================================

-- Check Battery Status (defibrillator-specific utility function)
ITEM.functions.CheckCharge = {
    name = "Check Batteries",
    tip = "Check the defibrillator's battery status.",
    icon = "icon16/lightning.png",
    OnRun = function(item)
        local client = item.player
        local batteries = item:GetBatteries()

        if #batteries == 0 then
            client:Notify("The defibrillator has no batteries loaded.")
        else
            local fullCount, partialCount, depletedCount = 0, 0, 0
            for _, charge in ipairs(batteries) do
                if charge == 100 then fullCount = fullCount + 1
                elseif charge > 0 then partialCount = partialCount + 1
                else depletedCount = depletedCount + 1 end
            end

            client:Notify(string.format("Batteries: %d full, %d partial, %d depleted (%d shocks available).",
                fullCount, partialCount, depletedCount, fullCount))
        end

        return false
    end
}
