--[[
    Key SWEP

    Controls:
    - LMB: Lock door (if keying matches and door is unlocked/closed)
    - RMB: Unlock door (if keying matches and door is locked)

    Works with Windswept managed doors (prop_door_rotating with ixIsWindsweptDoor marker).
]]--

AddCSLuaFile()

SWEP.PrintName = "Key"
SWEP.Author = "Windswept"
SWEP.Purpose = "Lock and unlock doors."
SWEP.Instructions = "LMB: Lock door | RMB: Unlock door"

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModelFOV = 54
SWEP.ViewModel = "models/weapons/c_arms.mdl"  -- Empty hands
SWEP.WorldModel = "models/props_c17/tools_wrench01a.mdl"  -- Placeholder key model
SWEP.UseHands = true
SWEP.HoldType = "normal"

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

-- Maximum distance to interact with doors
SWEP.MaxUseDistance = 96

-- Time to lock/unlock
SWEP.ActionTime = 1

-- ============================================================================
-- NETWORKING
-- ============================================================================

if SERVER then
    util.AddNetworkString("ixKeyStartLock")
    util.AddNetworkString("ixKeyStartUnlock")
    util.AddNetworkString("ixKeyCancel")
end

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
    self:SetHoldType(self.HoldType)
    self.wasLMBDown = false
    self.wasRMBDown = false
    self.nextActionAttempt = 0
    self:SetLocking(false)
    self:SetUnlocking(false)
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
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
    local owner = self:GetOwner()
    if not IsValid(owner) then return nil end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.MaxUseDistance,
        filter = owner
    })

    local ent = tr.Entity
    if not IsValid(ent) then return nil end

    -- Check if it's our managed door (prop_door_rotating with our marker)
    if ent.ixIsWindsweptDoor then
        return ent
    end

    return nil
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
    if not self:IsPerformingAction() then return end

    self:SetLocking(false)
    self:SetUnlocking(false)
    self.targetDoor = nil

    local owner = self:GetOwner()
    if IsValid(owner) and SERVER then
        owner:EmitSound("buttons/button10.wav", 50)
    end
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    net.Receive("ixKeyStartLock", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_key" then return end

        weapon:StartLock()
    end)

    net.Receive("ixKeyStartUnlock", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_key" then return end

        weapon:StartUnlock()
    end)

    net.Receive("ixKeyCancel", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_key" then return end

        weapon:CancelAction()
    end)
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
    local owner = self:GetOwner()
    if not IsValid(owner) then
        return self:DrawModel()
    end

    -- Position key in right hand
    local boneIndex = owner:LookupBone("ValveBiped.Bip01_R_Hand")
    if not boneIndex then
        return self:DrawModel()
    end

    local boneMatrix = owner:GetBoneMatrix(boneIndex)
    if not boneMatrix then
        return self:DrawModel()
    end

    local pos = boneMatrix:GetTranslation()
    local ang = boneMatrix:GetAngles()

    -- Offset to fit in hand
    pos = pos + ang:Forward() * 3 + ang:Right() * 1 + ang:Up() * -1
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Up(), 180)

    self:SetRenderOrigin(pos)
    self:SetRenderAngles(ang)
    self:DrawModel()
end

-- ============================================================================
-- THINK - Input Detection & Action Progress
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- Client-side input detection
    if CLIENT then
        -- Don't process input if a UI panel is open
        if vgui.CursorVisible() then
            self.wasLMBDown = false
            self.wasRMBDown = false
            return
        end

        local lmbDown = input.IsMouseDown(MOUSE_LEFT)
        local rmbDown = input.IsMouseDown(MOUSE_RIGHT)

        -- LMB pressed - start lock
        if lmbDown and not self.wasLMBDown then
            if not self:IsPerformingAction() and CurTime() >= (self.nextActionAttempt or 0) then
                self.nextActionAttempt = CurTime() + 1
                net.Start("ixKeyStartLock")
                net.SendToServer()
            end
        end

        -- RMB pressed - start unlock
        if rmbDown and not self.wasRMBDown then
            if not self:IsPerformingAction() and CurTime() >= (self.nextActionAttempt or 0) then
                self.nextActionAttempt = CurTime() + 1
                net.Start("ixKeyStartUnlock")
                net.SendToServer()
            end
        end

        self.wasLMBDown = lmbDown
        self.wasRMBDown = rmbDown
    end

    -- Action progress checks
    if self:IsPerformingAction() then
        if SERVER then
            -- Check if still looking at the same door
            local currentDoor = self:GetTargetDoor()
            if currentDoor ~= self.targetDoor then
                self:CancelAction()
                owner:NotifyLocalized("keyLookedAway")
                return
            end

            -- Check if door still valid
            if not IsValid(self.targetDoor) then
                self:CancelAction()
                return
            end

            -- Check distance
            local distance = owner:GetPos():Distance(self.targetDoor:GetPos())
            if distance > self.MaxUseDistance + 32 then
                self:CancelAction()
                owner:NotifyLocalized("keyTooFar")
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

        local elapsed = CurTime() - self:GetActionStartTime()
        local progress = math.Clamp(elapsed / self.ActionTime, 0, 1)

        local w, h = ScrW(), ScrH()
        local barW, barH = 200, 20
        local x, y = (w - barW) / 2, h * 0.6

        -- Background
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(x, y, barW, barH)

        -- Progress fill
        surface.SetDrawColor(100, 150, 200, 255)
        surface.DrawRect(x + 2, y + 2, (barW - 4) * progress, barH - 4)

        -- Border
        surface.SetDrawColor(200, 200, 200, 255)
        surface.DrawOutlinedRect(x, y, barW, barH, 2)

        -- Text
        local actionText = self:GetLocking() and "Locking..." or "Unlocking..."
        draw.SimpleText(actionText, "ixSmallFont", w / 2, y - 20, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
end
