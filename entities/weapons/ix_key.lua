--[[
    Key SWEP

    Controls:
    - LMB: Lock door (if keying matches and door is unlocked/closed)
    - RMB: Unlock door (if keying matches and door is locked)

    Works with Windswept managed doors (prop_door_rotating with ixIsWindsweptDoor marker).
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Key"
SWEP.Purpose = "Lock and unlock doors."
SWEP.Instructions = "LMB: Lock door | RMB: Unlock door"

SWEP.WorldModel = "models/props_c17/tools_wrench01a.mdl"

-- Maximum distance to interact with doors
SWEP.MaxUseDistance = 96

-- Time to lock/unlock
SWEP.ActionTime = 1

-- ============================================================================
-- NETWORKING
-- ============================================================================

-- Network strings registered in schema/sv_netstrings.lua

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Locking")
    self:NetworkVar("Bool", 1, "Unlocking")
    self:NetworkVar("Float", 0, "ActionStartTime")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Initialize()
    self.BaseClass.Initialize(self)
    self.nextActionAttempt = 0
    self:SetLocking(false)
    self:SetUnlocking(false)
end

function SWEP:Deploy()
    self.BaseClass.Deploy(self)
    self:CancelAction()
    return true
end

function SWEP:Holster()
    self:CancelAction()
    return true
end

function SWEP:OnRemove()
    self:CancelAction()
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function SWEP:GetKeying()
    local item = self.ixItem
    if not item then return nil end
    return item:GetData("keying", "")
end

function SWEP:GetTargetDoor()
    return ix.doors.GetTargetDoor(self:GetOwner(), self.MaxUseDistance)
end

function SWEP:CanKeyFitLock(door)
    local keying = self:GetKeying()
    if not keying or keying == "" then return false end

    -- Use centralized keying check
    return ix.doors.CheckKeying(door, keying)
end

function SWEP:IsPerformingAction()
    if not self.GetLocking then return false end
    return self:GetLocking() or self:GetUnlocking()
end

function SWEP:CancelAction()
    ix.constants.CancelSWEPAction(self, function() return self:IsPerformingAction() end, function()
        self:SetLocking(false)
        self:SetUnlocking(false)
        self.targetDoor = nil
    end)
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    ix.weapon.NetReceive("ixKeyStartLock", "ix_key", "StartLock")
    ix.weapon.NetReceive("ixKeyStartUnlock", "ix_key", "StartUnlock")
    ix.weapon.NetReceive("ixKeyCancel", "ix_key", "CancelAction")
end

-- ============================================================================
-- START LOCK
-- ============================================================================

function SWEP:StartLock()
    if CLIENT then return end
    if not self.SetLocking then return end
    if self:IsPerformingAction() then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("keyNoDoor")
        return
    end

    -- Check if door has a lock
    if not ix.doors.HasLock(door) then
        owner:NotifyLocalized("keyNoLock")
        return
    end

    -- Check if key fits
    if not self:CanKeyFitLock(door) then
        owner:NotifyLocalized("keyDoesntFit")
        owner:EmitSound("buttons/button11.wav", 50)
        return
    end

    -- Check if door is already locked
    if door:IsLocked() then
        owner:NotifyLocalized("keyAlreadyLocked")
        return
    end

    -- Check if door is open (can't lock an open door)
    if ix.doors.IsDoorOpen(door) then
        owner:NotifyLocalized("keyDoorOpen")
        return
    end

    -- Start locking
    self:SetLocking(true)
    self:SetActionStartTime(CurTime())
    self.targetDoor = door

    door:EmitSound("doors/door_latch2.wav", 60)
end

-- ============================================================================
-- START UNLOCK
-- ============================================================================

function SWEP:StartUnlock()
    if CLIENT then return end
    if not self.SetUnlocking then return end
    if self:IsPerformingAction() then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("keyNoDoor")
        return
    end

    -- Check if door has a lock
    if not ix.doors.HasLock(door) then
        owner:NotifyLocalized("keyNoLock")
        return
    end

    -- Check if key fits
    if not self:CanKeyFitLock(door) then
        owner:NotifyLocalized("keyDoesntFit")
        owner:EmitSound("buttons/button11.wav", 50)
        return
    end

    -- Check if door is already unlocked
    if not door:IsLocked() then
        owner:NotifyLocalized("keyAlreadyUnlocked")
        return
    end

    -- Start unlocking
    self:SetUnlocking(true)
    self:SetActionStartTime(CurTime())
    self.targetDoor = door

    door:EmitSound("doors/door_latch2.wav", 60)
end

-- ============================================================================
-- COMPLETE ACTIONS
-- ============================================================================

function SWEP:CompleteLock()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self.targetDoor

    if not IsValid(door) then
        self:CancelAction()
        return
    end

    -- Lock the door (syncs to partner for double doors)
    ix.doors.LockDoor(door)
    door:EmitSound("doors/door_latch3.wav", 70)  -- Heavier click for locking
    owner:NotifyLocalized("keyLocked")

    self:SetLocking(false)
    self.targetDoor = nil
end

function SWEP:CompleteUnlock()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self.targetDoor

    if not IsValid(door) then
        self:CancelAction()
        return
    end

    -- Unlock the door (syncs to partner for double doors)
    ix.doors.UnlockDoor(door)
    door:EmitSound("doors/door_latch1.wav", 70)  -- Lighter click for unlocking
    owner:NotifyLocalized("keyUnlocked")

    self:SetUnlocking(false)
    self.targetDoor = nil
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

function SWEP:DrawWorldModel()
    ix.constants.DrawWorldModelBone(self, {3, 1, -1}, {{"Forward", 90}, {"Up", 180}})
end

-- ============================================================================
-- THINK - Input Detection & Action Progress
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        local lmb, rmb = ix.constants.ProcessSWEPInput(self)

        if lmb and not self:IsPerformingAction() and CurTime() >= (self.nextActionAttempt or 0) then
            self.nextActionAttempt = CurTime() + 1
            net.Start("ixKeyStartLock")
            net.SendToServer()
        end

        if rmb and not self:IsPerformingAction() and CurTime() >= (self.nextActionAttempt or 0) then
            self.nextActionAttempt = CurTime() + 1
            net.Start("ixKeyStartUnlock")
            net.SendToServer()
        end
    end

    -- Action progress checks
    if self:IsPerformingAction() then
        if SERVER then
            local valid, reason = ix.weapon.IsTargetValid(owner, self:GetTargetDoor(), self.targetDoor, self.MaxUseDistance)
            if not valid then
                self:CancelAction()
                if reason == "looked_away" then owner:NotifyLocalized("keyLookedAway")
                elseif reason == "too_far" then owner:NotifyLocalized("keyTooFar") end
                return
            end
        end

        -- Check if action complete
        local elapsed = CurTime() - self:GetActionStartTime()
        if elapsed >= self.ActionTime then
            if SERVER then
                if self:GetLocking() then
                    self:CompleteLock()
                elseif self:GetUnlocking() then
                    self:CompleteUnlock()
                end
            end
        end
    end
end

-- ============================================================================
-- HUD - Action Progress
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        if not self:IsPerformingAction() then return end

        local progress = math.Clamp((CurTime() - self:GetActionStartTime()) / self.ActionTime, 0, 1)
        local label = self:GetLocking() and "Locking..." or "Unlocking..."
        ix.constants.DrawProgressBar(label, progress, Color(100, 150, 200))
    end
end
