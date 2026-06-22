--[[
    Flashlight SWEP - Hybrid Implementation

    Inherits from shaky_flashlight (Workshop ID: 2947598424) and adds battery support.
    The base class handles all light rendering, animation timing, and projected textures.
    We only intercept SetLight() to validate battery before allowing turn-on.

    - Animation + sound always play (button click feedback)
    - Light only turns on if battery has charge
    - Server-authoritative: server decides if light turns on
]]--

AddCSLuaFile()

SWEP.Base = "shaky_flashlight"

SWEP.PrintName = "Flashlight"
SWEP.Spawnable = false
SWEP.Drop = false

-- Battery drain rate: 100up / 1200 seconds = ~0.083up per second (20 minutes per full battery)
-- Canonical value defined in schema/sh_constants.lua as DRAIN_FLASHLIGHT
SWEP.DrainRate = 100 / 1200

-- Network string registered in schema/sv_netstrings.lua as wsFlashlightSetLight

-- ============================================================================
-- SETUP DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    -- Call base class to set up FlashlightOn NetworkVar
    self.BaseClass.SetupDataTables(self)

    -- Client listens for server's decision on light state
    if CLIENT then
        self:NetworkVarNotify("FlashlightOn", function(ent, name, old, new)
            if new and not old then
                -- Server approved turn-on
                self:SetSkin(1)
                if IsValid(self.light) then
                    self.light:SetBrightness(GetConVar("shaky_flashlight_brightness"):GetFloat())
                end
            elseif old and not new then
                -- Server turned off light (e.g., battery ejected, death, knockout)
                self:SetSkin(0)
                if IsValid(self.light) then
                    self.light:SetBrightness(0)
                end
            end
        end)
    end
end

-- ============================================================================
-- OVERRIDE Deploy - Prevent Auto-On
-- ============================================================================

function SWEP:Deploy()
    -- Call base class (plays draw animation, sets up idle states)
    local result = self.BaseClass.Deploy(self)

    -- Kill the auto-on timer that base class creates on CLIENT
    if CLIENT then
        timer.Remove("createlight" .. self:EntIndex())
    end

    -- Ensure light is OFF on deploy
    self:SetFlashlightOn(false)
    self:SetSkin(0)
    if CLIENT and IsValid(self.light) then
        self.light:SetBrightness(0)
    end

    return result
end

-- ============================================================================
-- OVERRIDE SetLight - Server-Authoritative Battery Check
-- ============================================================================

function SWEP:SetLight(value)
    if CLIENT then
        -- Always play toggle sound (button click feedback)
        self:EmitSound("shaky_flashlight_toggle")

        -- Send request to server
        net.Start("wsFlashlightSetLight")
        net.WriteBool(value)
        net.SendToServer()

        -- If turning OFF, do it immediately (always allowed)
        if not value then
            self:SetFlashlightOn(false)
            self:SetSkin(0)
            if IsValid(self.light) then
                self.light:SetBrightness(0)
            end
        end
        -- If turning ON, wait for server confirmation (NetworkVarNotify handles visual)

    else
        -- SERVER handles the decision
        if value then
            -- Guard the owner before notifying: SetLight is also called from cleanup
            -- hooks (death/knockout) where GetOwner() may be invalid. (sc-weapons-tools-6)
            local owner = self:GetOwner()

            -- Check battery before allowing turn-on
            local item = self.wsItem
            if not item then
                if IsValid(owner) then owner:NotifyLocalized("flashlightNoBattery") end
                return
            end

            local batteries = item:GetData("batteries", {})
            if #batteries == 0 then
                if IsValid(owner) then owner:NotifyLocalized("flashlightNoBattery") end
                return
            end

            if batteries[1] <= 0 then
                if IsValid(owner) then owner:NotifyLocalized("flashlightNoCharge") end
                return
            end
        end

        -- Battery OK or turning off - set the NetworkVar (syncs to client)
        self:SetFlashlightOn(value)
        self:SetSkin(value and 1 or 0)
    end
end

-- ============================================================================
-- SERVER: Receive Toggle Requests
-- ============================================================================

if SERVER then
    -- The toggle acts only on the flashlight the player currently holds, rate-limited to 0.2s.
    -- ws.weapon.NetReceive supplies the active-weapon class check + rate limit, then calls
    -- SetLight(value) (the server branch does the battery check). (sc-weapons-tools-6)
    ws.weapon.NetReceive("wsFlashlightSetLight", "ws_flashlight", "SetLight", {
        rateLimit = 0.2,
        read = function() return net.ReadBool() end,
    })
end

-- ============================================================================
-- OVERRIDE Think - Battery Drain (Server-Side)
-- ============================================================================

function SWEP:Think()
    -- Call base class Think (handles animations, idle states, melee charging)
    self.BaseClass.Think(self)

    -- Battery drain is server-side only
    if not SERVER then return end
    if not self:GetFlashlightOn() then return end

    -- Accumulate drain (once per second)
    self.drainAccumulator = (self.drainAccumulator or 0) + FrameTime()
    if self.drainAccumulator < 1 then return end
    self.drainAccumulator = self.drainAccumulator - 1

    -- Drain battery
    local item = self.wsItem
    if not item then
        self:SetLight(false)
        return
    end

    local batteries = item:GetData("batteries", {})
    if #batteries == 0 then
        self:SetLight(false)
        return
    end

    batteries[1] = batteries[1] - self.DrainRate
    if batteries[1] <= 0 then
        batteries[1] = 0
        item:SetData("batteries", batteries)
        self:SetLight(false)

        -- Guard the owner before notify/option lookups (sc-weapons-tools-6)
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("flashlightBatteryDead")

            -- Auto-eject depleted battery if enabled
            if ws.option.Get(owner, "batteryAutoEject", true) then
                item:AutoEjectDepleted(owner)
            end
            -- Auto-load new battery from inventory if enabled
            if ws.option.Get(owner, "batteryAutoLoad", true) then
                item:AutoLoadFromInventory(owner)
            end
        end
    else
        item:SetData("batteries", batteries)
    end
end

-- ============================================================================
-- HOOKS - Turn Off Light on Death/Knockout
-- ============================================================================

ws.weapon.RegisterCleanupHooks("ws_flashlight", "wsFlashlight", function(weapon)
    if weapon.SetLight then weapon:SetLight(false) end
end)
