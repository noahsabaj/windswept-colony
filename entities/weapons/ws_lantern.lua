--[[
    Lantern SWEP

    Controls:
    - LMB: Toggle light on/off
    - RMB: Place lantern on ground (creates world entity)

    Battery drain: ~0.167up per second (10 minutes per full battery)

    Model: https://steamcommunity.com/sharedfiles/filedetails/?id=3354246770
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Lantern"
SWEP.Purpose = "Portable ambient light source."
SWEP.Instructions = "LMB: Toggle light | RMB: Place on ground"

SWEP.ViewModelFOV = 85
SWEP.ViewModel = "models/weapons/cof/v_lantern.mdl"
SWEP.WorldModel = "models/weapons/cof/w_lantern.mdl"
SWEP.UseHands = false -- This viewmodel has arms baked in
SWEP.HoldType = "pistol"
SWEP.DrawCrosshair = false

-- Battery drain rate: 100up / 600 seconds = ~0.167up per second (10 minutes per full battery)
-- Canonical value defined in schema/sh_constants.lua as DRAIN_LANTERN
SWEP.DrainRate = 100 / 600

-- Light properties (bluish-white like the original addon)
SWEP.LightColor = Color(170, 240, 250)
SWEP.LightBrightness = 0.05
SWEP.LightSize = 430
SWEP.LightStyle = 12 -- Flickering style

-- Worldmodel positioning (from original addon)
SWEP.Offset = {
    Pos = {
        Right = 1,
        Forward = -1,
        Up = -16,
    },
    Ang = {
        Right = 0,
        Forward = -5,
        Up = 78,
    },
}

-- ============================================================================
-- NETWORKING
-- ============================================================================

-- Network strings registered in schema/sv_netstrings.lua

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "LanternOn")
    self:SetLanternOn(false)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Deploy()
    self.BaseClass.Deploy(self)
    self:SendWeaponAnim(ACT_VM_DRAW)
    self:EmitSound("weapons/cof/sleeve_generic" .. math.random(1, 3) .. ".wav")

    return true
end

function SWEP:Holster()
    if SERVER then
        self:SetLanternOn(false)
    end

    return true
end

function SWEP:OnRemove()
    -- Light cleanup handled automatically by DynamicLight DieTime
end

-- ============================================================================
-- LIGHT MANAGEMENT (CLIENT)
-- ============================================================================

if CLIENT then
    function SWEP:UpdateLight()
        if not self:GetLanternOn() then return end

        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local bone = owner:LookupBone("ValveBiped.Bip01_Spine4")
        if not bone then return end

        local pos = owner:GetBonePosition(bone)

        local dlight = DynamicLight(self:EntIndex())
        if dlight then
            dlight.Pos = pos
            dlight.r = self.LightColor.r
            dlight.g = self.LightColor.g
            dlight.b = self.LightColor.b
            dlight.Brightness = self.LightBrightness
            dlight.Size = self.LightSize
            dlight.DieTime = CurTime() + 0.1
            dlight.Style = self.LightStyle
            dlight.nomodel = true
        end
    end
end

-- ============================================================================
-- TOGGLE LIGHT
-- ============================================================================

function SWEP:SetLight(value)
    if CLIENT then
        -- Request server
        net.Start("wsLanternSetLight")
        net.WriteBool(value)
        net.SendToServer()
        return
    end

    -- SERVER
    if value then
        -- Check battery
        local item = self.wsItem
        if not item then
            self:GetOwner():NotifyLocalized("lanternNoBattery")
            return
        end

        local batteries = item:GetData("batteries", {})
        if #batteries == 0 then
            self:GetOwner():NotifyLocalized("lanternNoBattery")
            return
        end

        if batteries[1] <= 0 then
            self:GetOwner():NotifyLocalized("lanternNoCharge")
            return
        end
    end

    self:SetLanternOn(value)
    self:GetOwner():EmitSound(value and "buttons/lightswitch2.wav" or "buttons/lightswitch2.wav", 50, value and 100 or 90)
end

if SERVER then
    -- Acts on the player's lantern (GetWeapon, not active — it stays lit while holstered),
    -- rate-limited to 0.2s; SetLight's server branch does the battery check. (lookup = owned)
    ws.weapon.NetReceive("wsLanternSetLight", "ws_lantern", "SetLight", {
        lookup = "owned",
        rateLimit = 0.2,
        read = function() return net.ReadBool() end,
    })
end

-- PrimaryAttack/SecondaryAttack not used - input handled in Think() for Windswept compatibility

if SERVER then
    -- RMB-hold place: acts on the player's lantern (GetWeapon), rate-limited to 0.2s.
    -- PlaceLantern has its own wsPlacing idempotency guard. (lookup = owned)
    ws.weapon.NetReceive("wsLanternPlace", "ws_lantern", "PlaceLantern", {
        lookup = "owned",
        rateLimit = 0.2,
    })

    function SWEP:PlaceLantern()
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        -- Idempotency guard: StripWeapon / inventory:Remove only take effect next
        -- tick, so without this a duplicate wsLanternPlace in the same batch would
        -- spawn a second dropped lantern from one item (a dupe).
        if self.wsPlacing then return end

        -- Get item data
        local item = self.wsItem
        if not item then return end

        -- Trace to find placement position
        local tr = util.TraceLine({
            start = owner:GetShootPos(),
            endpos = owner:GetShootPos() + owner:GetAimVector() * 100,
            filter = owner
        })

        if not tr.Hit then
            owner:NotifyLocalized("lanternCantPlace")
            return
        end

        -- Commit: from here the item is consumed; block re-entry.
        self.wsPlacing = true

        local batteries = item:GetData("batteries", {})
        local charge = batteries[1] or 0
        local wasOn = self:GetLanternOn()

        -- Create world entity (using distinct name to avoid conflict with weapon class)
        local ent = ents.Create("ws_lantern_dropped")
        if not IsValid(ent) then self.wsPlacing = nil return end

        ent:SetPos(tr.HitPos + tr.HitNormal * 2)
        ent:SetAngles(Angle(0, owner:EyeAngles().y, 0))
        ent:Spawn()
        ent:Activate()

        -- Transfer state
        ent:SetBatteryCharge(charge)
        ent:SetLanternOn(wasOn)
        ent.OwnerPlayer = owner

        -- Remove item from inventory
        local _, inventory = ws.constants.GetCharacterInventory(owner)
        if inventory then
            inventory:Remove(item:GetID())
        end

        -- Strip weapon
        self.wsItem = nil
        owner:StripWeapon("ws_lantern")
        owner.wsLanternItem = nil

        owner:EmitSound("weapons/slam/throw.wav", 60)
    end
end

-- ============================================================================
-- THINK - Battery Drain, Light Update & RMB Hold Detection
-- ============================================================================

function SWEP:Think()
    if CLIENT then
        self:UpdateLight()

        -- Don't process input if a UI panel is open
        if vgui.CursorVisible() then
            self.wasLMBDown = false
            self.wasRMBDown = false
            self.rmbStartTime = nil
            return
        end

        local owner = self:GetOwner()
        if IsValid(owner) then
            -- LMB edge detection via shared helper
            local lmb = ws.constants.ProcessSWEPInput(self)

            if lmb then
                net.Start("wsLanternSetLight")
                net.WriteBool(not self:GetLanternOn())
                net.SendToServer()
            end

            -- RMB hold detection for placement (manual - hold pattern differs from edge detection)
            local rmbDown = input.IsMouseDown(MOUSE_RIGHT)
            if rmbDown then
                if not self.rmbStartTime then
                    self.rmbStartTime = CurTime()
                elseif CurTime() - self.rmbStartTime >= 0.5 then
                    self.rmbStartTime = nil
                    net.Start("wsLanternPlace")
                    net.SendToServer()
                end
            else
                self.rmbStartTime = nil
            end
        end

        return
    end

    -- SERVER: Battery drain
    if not self:GetLanternOn() then return end

    self.drainAccumulator = (self.drainAccumulator or 0) + FrameTime()
    if self.drainAccumulator < 1 then return end
    self.drainAccumulator = self.drainAccumulator - 1

    local item = self.wsItem
    if not item then
        self:SetLanternOn(false)
        return
    end

    local batteries = item:GetData("batteries", {})
    if #batteries == 0 then
        self:SetLanternOn(false)
        return
    end

    batteries[1] = batteries[1] - self.DrainRate
    if batteries[1] <= 0 then
        batteries[1] = 0
        item:SetData("batteries", batteries)
        self:SetLanternOn(false)
        self:GetOwner():NotifyLocalized("lanternBatteryDead")

        local owner = self:GetOwner()
        if ws.option.Get(owner, "batteryAutoEject", true) then
            item:AutoEjectDepleted(owner)
        end
        if ws.option.Get(owner, "batteryAutoLoad", true) then
            item:AutoLoadFromInventory(owner)
        end
    else
        item:SetData("batteries", batteries)
    end
end

-- ============================================================================
-- WORLD MODEL RENDERING (adapted from original addon)
-- ============================================================================

function SWEP:DrawWorldModel()
    if not IsValid(self:GetOwner()) then
        return self:DrawModel()
    end

    self.Hand2 = self.Hand2 or self:GetOwner():LookupAttachment("anim_attachment_rh")

    local hand = self:GetOwner():GetAttachment(self.Hand2)

    if not hand then
        return self:DrawModel()
    end

    local offset = hand.Ang:Right() * self.Offset.Pos.Right +
                   hand.Ang:Forward() * self.Offset.Pos.Forward +
                   hand.Ang:Up() * self.Offset.Pos.Up

    hand.Ang:RotateAroundAxis(hand.Ang:Right(), self.Offset.Ang.Right)
    hand.Ang:RotateAroundAxis(hand.Ang:Forward(), self.Offset.Ang.Forward)
    hand.Ang:RotateAroundAxis(hand.Ang:Up(), self.Offset.Ang.Up)

    self:SetRenderOrigin(hand.Pos + offset)
    self:SetRenderAngles(hand.Ang)

    self:DrawModel()
end

-- ============================================================================
-- HOOKS - Turn Off Light on Death/Knockout
-- ============================================================================

ws.weapon.RegisterCleanupHooks("ws_lantern", "wsLantern", function(weapon)
    if weapon.SetLight then weapon:SetLight(false) end
end)
