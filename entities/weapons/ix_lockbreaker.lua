--[[
    Lockbreaker SWEP

    Controls:
    - RMB on locked door: Start breaking lock (20 seconds, very loud)
    - LMB: Cancel

    Destroys the lock completely, making the door lockless.
]]--

AddCSLuaFile()

SWEP.PrintName = "Lockbreaker"
SWEP.Author = "Windswept"
SWEP.Purpose = "Destroy locks through brute force."
SWEP.Instructions = "RMB on door: Break lock (20s, loud)"

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModelFOV = 54
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"
SWEP.UseHands = true
SWEP.HoldType = "melee2"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.MaxUseDistance = 64
SWEP.BreakTime = 20  -- 20 seconds to break lock
SWEP.SoundInterval = 2  -- Play sound every 2 seconds

-- ============================================================================
-- NETWORKING
-- ============================================================================

-- Network strings registered in schema/sv_netstrings.lua

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Breaking")
    self:NetworkVar("Float", 0, "BreakStartTime")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self.wasLMBDown = false
    self.wasRMBDown = false
    self.nextBreakAttempt = 0

    if self.SetBreaking then
        self:SetBreaking(false)
    end
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    if self.SetBreaking then
        self:SetBreaking(false)
    end
    return true
end

function SWEP:IsBreaking()
    if not self.GetBreaking then return false end
    return self:GetBreaking()
end

function SWEP:Holster()
    self:CancelBreaking()
    return true
end

function SWEP:OnRemove()
    self:CancelBreaking()
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function SWEP:GetTargetDoor()
    return ix.doors.GetTargetDoor(self:GetOwner(), self.MaxUseDistance)
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    ix.weapon.NetReceive("ixLockbreakerStart", "ix_lockbreaker", "StartBreaking")
    ix.weapon.NetReceive("ixLockbreakerCancel", "ix_lockbreaker", "CancelBreaking")
end

function SWEP:StartBreaking()
    if CLIENT then return end
    if not self.SetBreaking then return end
    if self:IsBreaking() then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("lockbreakerNoDoor")
        return
    end

    -- Check if door has a lock
    if not ix.doors.HasLock(door) then
        owner:NotifyLocalized("lockbreakerNoLock")
        return
    end

    -- Start breaking
    self:SetBreaking(true)
    self:SetBreakStartTime(CurTime())
    self.targetDoor = door
    self.lastSoundTime = 0

    -- Initial loud sound
    owner:EmitSound("physics/metal/metal_box_scrape1.wav", 80)

    -- Broadcast to nearby players that someone is breaking a lock
    for _, ply in ipairs(player.GetAll()) do
        if ix.constants.WithinRange(ply, owner, ix.constants.RANGE_SOUND_FAR) then
            ply:NotifyLocalized("lockbreakerHeard")
        end
    end
end

function SWEP:CancelBreaking()
    ix.constants.CancelSWEPAction(self, function() return self:IsBreaking() end, function()
        self:SetBreaking(false)
        self.targetDoor = nil
    end)
end

function SWEP:CompleteBreaking()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self.targetDoor

    if not IsValid(door) then
        self:CancelBreaking()
        return
    end

    -- Destroy the lock completely
    ix.doors.RemoveLock(door)
    door:Fire("unlock")

    -- Loud snap sound
    owner:EmitSound("physics/metal/metal_sheet_impact_hard8.wav", 90)

    -- Secondary destruction sound
    timer.Simple(0.1, function()
        if IsValid(owner) then
            owner:EmitSound("physics/metal/metal_box_break1.wav", 80)
        end
    end)

    owner:NotifyLocalized("lockbreakerSuccess")

    self:SetBreaking(false)
    self.targetDoor = nil

    -- Save persistence
    if ix.doors and ix.doors.Save then
        ix.doors.Save()
    end
end

-- ============================================================================
-- THINK - Input Detection & Breaking Progress
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        local lmb, rmb = ix.constants.ProcessSWEPInput(self)

        if rmb and not self:IsBreaking() and CurTime() >= (self.nextBreakAttempt or 0) then
            self.nextBreakAttempt = CurTime() + 0.5
            net.Start("ixLockbreakerStart")
            net.SendToServer()
        end

        if lmb and self:IsBreaking() then
            net.Start("ixLockbreakerCancel")
            net.SendToServer()
        end
    end

    -- Breaking progress checks
    if self:IsBreaking() then
        if SERVER then
            -- Check if still looking at the same door
            local currentDoor = self:GetTargetDoor()
            if currentDoor ~= self.targetDoor then
                self:CancelBreaking()
                owner:NotifyLocalized("lockbreakerLookedAway")
                return
            end

            -- Check distance
            if not IsValid(self.targetDoor) then
                self:CancelBreaking()
                return
            end

            local distance = owner:GetPos():Distance(self.targetDoor:GetPos())
            if distance > self.MaxUseDistance + 16 then
                self:CancelBreaking()
                owner:NotifyLocalized("lockbreakerTooFar")
                return
            end

            -- Play periodic sounds
            local elapsed = CurTime() - self:GetBreakStartTime()
            local soundIndex = math.floor(elapsed / self.SoundInterval)

            if soundIndex > self.lastSoundTime then
                self.lastSoundTime = soundIndex

                -- Alternating scraping/grinding sounds
                local sounds = {
                    "physics/metal/metal_box_scrape2.wav",
                    "physics/metal/metal_sheet_impact_soft2.wav",
                    "physics/metal/metal_box_scrape1.wav",
                    "physics/metal/metal_computer_impact_hard2.wav"
                }

                local sound = sounds[(soundIndex % #sounds) + 1]
                owner:EmitSound(sound, 70 + math.random(0, 10))
            end
        end

        -- Check if breaking complete
        local elapsed = CurTime() - self:GetBreakStartTime()
        if elapsed >= self.BreakTime then
            if SERVER then
                self:CompleteBreaking()
            end
        end
    end
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

function SWEP:DrawWorldModel()
    ix.constants.DrawWorldModelBone(self, {5, 2, -3}, {{"Right", -90}, {"Forward", 180}})
end

-- ============================================================================
-- HUD - Breaking Progress
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        if not self:IsBreaking() then return end

        local progress = math.Clamp((CurTime() - self:GetBreakStartTime()) / self.BreakTime, 0, 1)
        ix.constants.DrawProgressBar("Breaking Lock...", progress, Color(200, 100, 50), "LMB to cancel", Color(255, 150, 100))
    end
end
