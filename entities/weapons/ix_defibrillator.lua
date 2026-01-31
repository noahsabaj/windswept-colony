--[[
    Defibrillator SWEP

    A medical device for reviving knocked players or incapacitating alive ones.
    - Right-click: Start charging (5 second charge time with progress bar)
    - After charging: 10 second window to use before it discharges
    - Left-click while ready: Shock target (consumes battery)
      - Knocked player: Instant revival roll
      - Alive player: Instantly knocks them out
    - Cannot shock yourself
    - Battery consumed even on miss
]]--

AddCSLuaFile()

if CLIENT then
    SWEP.PrintName = "Defibrillator"
    SWEP.Slot = 0
    SWEP.SlotPos = 3
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = true
end

SWEP.Author = "Windswept"
SWEP.Instructions = "Right-click: Charge | Left-click: Shock"
SWEP.Purpose = "Revive knocked players or incapacitate the living."
SWEP.Drop = false

SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.ViewModelFOV = 75
SWEP.ViewModelFlip = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.ViewModel = Model("models/weapons/defib/v_defibrillator.mdl")
SWEP.WorldModel = Model("models/weapons/defib/w_eq_defibrillator_paddles.mdl")

SWEP.UseHands = true
SWEP.HoldType = "duel"

-- Timing configuration
SWEP.ChargeDuration = 5    -- 5 seconds to charge
SWEP.ReadyDuration = 10    -- 10 seconds to use once charged

-- Shock range (melee)
SWEP.ShockRange = 60

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Ready")           -- Fully charged and ready to shock
    self:NetworkVar("Bool", 1, "Charging")        -- Currently in charging phase
    self:NetworkVar("Float", 0, "ReadyEndTime")   -- When ready state expires
    self:NetworkVar("Float", 1, "ChargeStartTime") -- When charging started
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:ResetState()
end

function SWEP:ResetState()
    self:SetReady(false)
    self:SetCharging(false)
    self:SetReadyEndTime(0)
    self:SetChargeStartTime(0)
end

function SWEP:Deploy()
    self:ResetState()

    if SERVER then
        self:EmitSound("defibl/deploy.wav", 60)
    end

    local vm = self:GetOwner():GetViewModel()
    if IsValid(vm) then
        vm:SendViewModelMatchingSequence(vm:LookupSequence("deploy"))
    end

    return true
end

function SWEP:Holster()
    self:ExitAllStates()
    return true
end

function SWEP:OnRemove()
    self:ExitAllStates()

    if CLIENT then
        self:RemoveGlow()
    end
end

-- ============================================================================
-- PRIMARY ATTACK (Left-click) - Shock
-- ============================================================================

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.5)

    -- Still charging? Can't shock yet
    if self:GetCharging() then
        if SERVER then
            self:GetOwner():EmitSound("HL2Player.UseDeny")
            self:GetOwner():NotifyLocalized("defibStillCharging")
        end
        return
    end

    -- Not ready? Can't shock
    if not self:GetReady() then
        if SERVER then
            self:GetOwner():EmitSound("HL2Player.UseDeny")
            self:GetOwner():NotifyLocalized("defibNotReady")
        end
        return
    end

    -- Must have battery
    local item = self.ixItem
    if not item then
        self:ExitAllStates()
        return
    end

    local batteries = item:GetData("batteries", {})
    if #batteries == 0 then
        if SERVER then
            self:GetOwner():NotifyLocalized("defibNoBattery")
        end
        self:ExitAllStates()
        return
    end

    if SERVER then
        self:DoShock()
    end

    -- Exit ready state after shock
    self:ExitAllStates()
end

-- ============================================================================
-- SECONDARY ATTACK (Right-click) - Start Charging
-- ============================================================================

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)

    -- Already charging or ready? Do nothing
    if self:GetCharging() or self:GetReady() then
        return
    end

    -- Check battery
    local item = self.ixItem
    if not item then return end

    local batteries = item:GetData("batteries", {})
    if #batteries == 0 then
        if SERVER then
            self:GetOwner():NotifyLocalized("defibNoBattery")
        end
        return
    end

    -- Enter charging state
    self:EnterChargingState()
end

-- ============================================================================
-- THINK
-- ============================================================================

function SWEP:Think()
    -- Charging -> Ready transition
    if self:GetCharging() then
        if CurTime() >= self:GetChargeStartTime() + self.ChargeDuration then
            self:CompleteCharging()
        end
    end

    -- Ready state timeout
    if self:GetReady() and CurTime() > self:GetReadyEndTime() then
        if SERVER then
            self:GetOwner():NotifyLocalized("defibDischarged")
        end
        self:ExitAllStates()
    end

    -- Update glow position on client
    if CLIENT and (self:GetReady() or self:GetCharging()) then
        self:UpdateGlow()
    end
end

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

function SWEP:EnterChargingState()
    self:SetCharging(true)
    self:SetReady(false)
    self:SetChargeStartTime(CurTime())

    if SERVER then
        -- Play charging sound
        self:EmitSound("defibl/warmup.wav", 75)

        -- Create glow light (dim during charging)
        self:CreateServerGlow(false)

        -- Notify player
        self:GetOwner():NotifyLocalized("defibCharging")
    end

    if CLIENT then
        self:CreateGlow()
    end
end

function SWEP:CompleteCharging()
    -- Transition from charging to ready
    self:SetCharging(false)
    self:SetReady(true)
    self:SetReadyEndTime(CurTime() + self.ReadyDuration)

    if SERVER then
        -- Stop charging sound
        self:StopSound("defibl/warmup.wav")

        -- Play ready beep
        self:EmitSound("buttons/button17.wav", 70, 120)

        -- Brighten the glow
        self:RemoveServerGlow()
        self:CreateServerGlow(true)

        -- Notify player
        self:GetOwner():NotifyLocalized("defibCharged")
    end
end

function SWEP:ExitAllStates()
    local wasCharging = self:GetCharging()
    local wasReady = self:GetReady()

    if not wasCharging and not wasReady then return end

    self:SetCharging(false)
    self:SetReady(false)
    self:SetChargeStartTime(0)
    self:SetReadyEndTime(0)

    if SERVER then
        -- Stop charging sound
        self:StopSound("defibl/warmup.wav")

        -- Remove glow
        self:RemoveServerGlow()
    end

    if CLIENT then
        self:RemoveGlow()
    end
end

-- ============================================================================
-- SERVER: SHOCK LOGIC
-- ============================================================================

if SERVER then
    function SWEP:DoShock()
        local owner = self:GetOwner()
        local item = self.ixItem

        -- Consume battery first (even on miss)
        local permadeathPlugin = ix.plugin.Get("permadeath")
        if permadeathPlugin and permadeathPlugin.ConsumeDefibCharge then
            permadeathPlugin:ConsumeDefibCharge(item, owner)
        end

        -- Trace for target
        local tr = util.TraceLine({
            start = owner:GetShootPos(),
            endpos = owner:GetShootPos() + owner:GetAimVector() * self.ShockRange,
            filter = owner,
            mask = MASK_SHOT_HULL,
        })

        -- If no hit, try hull trace (more forgiving)
        if not IsValid(tr.Entity) then
            tr = util.TraceHull({
                start = owner:GetShootPos(),
                endpos = owner:GetShootPos() + owner:GetAimVector() * self.ShockRange,
                filter = owner,
                mins = Vector(-20, -20, -10),
                maxs = Vector(20, 20, 10),
                mask = MASK_SHOT_HULL,
            })
        end

        local target = tr.Entity

        -- Play shock effects regardless of hit
        self:PlayShockEffects(tr.HitPos)

        -- Check what we hit
        if not IsValid(target) then
            -- Missed
            owner:NotifyLocalized("defibMissed")
            return
        end

        -- Handle knocked entity (ix_knocked) - direct hit
        if target:GetClass() == "ix_knocked" then
            self:ShockKnockedPlayer(target)
            return
        end

        -- Handle prop_ragdoll linked to ix_knocked (the visible body)
        if target:GetClass() == "prop_ragdoll" and IsValid(target.ixKnockedEntity) then
            self:ShockKnockedPlayer(target.ixKnockedEntity)
            return
        end

        -- Handle alive player
        if target:IsPlayer() and target:Alive() then
            -- Can't shock self
            if target == owner then
                owner:NotifyLocalized("defibCantShockSelf")
                return
            end

            self:ShockAlivePlayer(target)
            return
        end

        -- Hit something else (wall, prop, etc.)
        owner:NotifyLocalized("defibMissed")
    end

    function SWEP:ShockKnockedPlayer(knockedEntity)
        local owner = self:GetOwner()
        local permadeathPlugin = ix.plugin.Get("permadeath")

        if not permadeathPlugin then return end

        -- Check if already permadead
        if knockedEntity:GetPermadead() then
            owner:NotifyLocalized("knockedAlreadyDead")
            return
        end

        -- Check if owner is online (can't revive disconnected)
        if not IsValid(knockedEntity.ixOwner) then
            owner:NotifyLocalized("knockedPlayerDisconnected")
            return
        end

        -- Calculate revival chance (45-95% with defib)
        local success = permadeathPlugin:CalculateRevivalChance(true)

        if success then
            -- Revival succeeded - use existing revival logic
            permadeathPlugin:RevivePlayer(knockedEntity, owner, false, nil)
        else
            -- Revival failed
            owner:NotifyLocalized("revivalFailed")
        end
    end

    function SWEP:ShockAlivePlayer(target)
        local owner = self:GetOwner()
        local permadeathPlugin = ix.plugin.Get("permadeath")

        if not permadeathPlugin then return end

        local character = target:GetCharacter()
        if not character then return end

        -- Create knockout state on the alive player
        -- We need a damage info for the knockout system
        local dmgInfo = DamageInfo()
        dmgInfo:SetAttacker(owner)
        dmgInfo:SetInflictor(self)
        dmgInfo:SetDamage(0)
        dmgInfo:SetDamageType(DMG_SHOCK)

        -- Call the knockout creation
        permadeathPlugin:CreateKnockout(target, character, dmgInfo)

        -- Notify
        owner:NotifyLocalized("defibShockedAlive", target:GetCharacter():GetName())

        -- Visual effect on victim
        target:ScreenFade(SCREENFADE.IN, Color(255, 255, 255), 0.7, 0.03)
        target:ViewPunch(Angle(20, 0, 20))

        -- Log
        ix.log.Add(owner, "defibKnockout", target:GetCharacter():GetName())
    end

    function SWEP:PlayShockEffects(hitPos)
        local owner = self:GetOwner()

        -- Play zap sound
        self:EmitSound("defibl/defibrillator_use.wav", 75)
        self:EmitSound("weapons/empgun/arc" .. math.random(1, 2) .. ".wav", 75, 100, 0.8)

        -- View punch
        owner:ViewPunch(Angle(-10, 0, 0))

        -- Spark effect
        local spark = ents.Create("env_spark")
        if IsValid(spark) then
            spark:SetPos(hitPos)
            spark:SetKeyValue("spawnflags", "192")
            spark:SetKeyValue("traillength", "1")
            spark:SetKeyValue("magnitude", "2")
            spark:Spawn()
            spark:Fire("SparkOnce", "", 0.05)
            spark:Fire("kill", "", 0.1)
        end

        -- Light flash
        local light = ents.Create("light_dynamic")
        if IsValid(light) then
            light:SetKeyValue("brightness", "4")
            light:SetKeyValue("distance", "160")
            light:SetPos(hitPos)
            light:Fire("Color", "60 150 255")
            light:Spawn()
            light:Activate()
            light:Fire("TurnOn", "", 0)
            light:Fire("Kill", "", 0.1)
        end
    end

    function SWEP:CreateServerGlow(bright)
        if IsValid(self.serverGlow) then return end

        self.serverGlow = ents.Create("light_dynamic")
        if IsValid(self.serverGlow) then
            self.serverGlow:SetKeyValue("brightness", bright and "2" or "1")
            self.serverGlow:SetKeyValue("distance", bright and "100" or "60")
            self.serverGlow:SetPos(self:GetPos())
            self.serverGlow:SetParent(self)
            self.serverGlow:Fire("Color", "60 150 255")
            self.serverGlow:Spawn()
            self.serverGlow:Activate()
            self.serverGlow:Fire("TurnOn", "", 0)
        end
    end

    function SWEP:RemoveServerGlow()
        if IsValid(self.serverGlow) then
            self.serverGlow:Remove()
            self.serverGlow = nil
        end
    end
end

-- ============================================================================
-- CLIENT: GLOW EFFECTS AND HUD
-- ============================================================================

if CLIENT then
    function SWEP:CreateGlow()
        -- Client-side glow could use dlight for local player
        -- For now, server handles the light_dynamic
    end

    function SWEP:UpdateGlow()
        -- Update position if needed
    end

    function SWEP:RemoveGlow()
        -- Cleanup
    end

    -- Draw charging progress bar on HUD
    function SWEP:DrawHUD()
        if not self:GetCharging() then return end

        local progress = math.Clamp((CurTime() - self:GetChargeStartTime()) / self.ChargeDuration, 0, 1)

        if progress <= 0 or progress >= 1 then return end

        local scrW, scrH = ScrW(), ScrH()

        -- Bar dimensions (similar to looting progress bar)
        local barWidth = 200
        local barHeight = 12
        local barX = (scrW - barWidth) / 2
        local barY = scrH * 0.6  -- Below center of screen

        -- Background
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(barX, barY, barWidth, barHeight)

        -- Progress fill (blue for defibrillator)
        surface.SetDrawColor(60, 150, 255, 255)
        surface.DrawRect(barX + 1, barY + 1, (barWidth - 2) * progress, barHeight - 2)

        -- Border
        surface.SetDrawColor(255, 255, 255, 100)
        surface.DrawOutlinedRect(barX, barY, barWidth, barHeight)

        -- Label
        draw.SimpleText("CHARGING", "DermaDefault", scrW / 2, barY - 5, Color(255, 255, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
end

-- ============================================================================
-- HOOKS
-- ============================================================================

-- Handle player death/knockout - exit all states
hook.Add("PlayerDeath", "ixDefibDeath", function(client)
    local weapon = client:GetWeapon("ix_defibrillator")
    if IsValid(weapon) and weapon.ExitAllStates then
        weapon:ExitAllStates()
    end
end)

hook.Add("ixPlayerKnockedOut", "ixDefibKnockout", function(client)
    local weapon = client:GetWeapon("ix_defibrillator")
    if IsValid(weapon) and weapon.ExitAllStates then
        weapon:ExitAllStates()
    end
end)
