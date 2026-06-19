--[[
    Lock SWEP

    Controls:
    - RMB while looking at door: Install lock (requires toolkit in inventory)

    Works with Windswept managed doors (prop_door_rotating with wsIsWindsweptDoor marker).
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Lock"
SWEP.Purpose = "Install locks on doors."
SWEP.Instructions = "RMB on door: Install lock"

SWEP.WorldModel = "models/props_c17/tools_pliers01a.mdl"

-- Maximum distance to interact with doors
SWEP.MaxUseDistance = 96

-- Time to install lock (modified by toolkit)
SWEP.BaseInstallTime = 6  -- 6 seconds base, toolkit reduces this

-- ============================================================================
-- NETWORKING
-- ============================================================================

-- Network strings registered in schema/sv_netstrings.lua

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Installing")
    self:NetworkVar("Float", 0, "InstallStartTime")
    self:NetworkVar("Float", 1, "InstallDuration")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Initialize()
    self.BaseClass.Initialize(self)
    self:SetInstalling(false)
    self.nextInstallAttempt = 0
end

function SWEP:Deploy()
    self.BaseClass.Deploy(self)
    self:SetInstalling(false)
    return true
end

function SWEP:Holster()
    self:CancelInstall()
    return true
end

function SWEP:OnRemove()
    self:CancelInstall()
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function SWEP:GetTargetDoor()
    return ws.doors.GetTargetDoor(self:GetOwner(), self.MaxUseDistance)
end

function SWEP:HasToolkit()
    return ws.constants.FindBestToolkit(self:GetOwner())
end

function SWEP:GetInstallTime()
    local hasToolkit, toolkit = self:HasToolkit()
    if not hasToolkit then
        return self.BaseInstallTime
    end

    -- Toolkit speeds up installation
    local multiplier = toolkit.installSpeedMultiplier or 1
    return self.BaseInstallTime * multiplier
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    ws.weapon.NetReceive("wsLockInstall", "ix_lock", "StartInstall")
    ws.weapon.NetReceive("wsLockCancel", "ix_lock", "CancelInstall")
end

function SWEP:StartInstall()
    if CLIENT then return end

    local owner = self:GetOwner()

    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("lockNoDoor")
        return
    end

    -- Check if door already has a lock
    if ws.doors.HasLock(door) then
        owner:NotifyLocalized("lockAlreadyHasLock")
        return
    end

    -- Check for toolkit
    local hasToolkit, toolkit = self:HasToolkit()
    if not hasToolkit then
        owner:NotifyLocalized("lockNeedToolkit")
        return
    end

    -- Start installation
    local installTime = self:GetInstallTime()
    self:SetInstalling(true)
    self:SetInstallStartTime(CurTime())
    self:SetInstallDuration(installTime)
    self.targetDoor = door
    self.installingToolkit = toolkit

    owner:EmitSound("physics/metal/metal_box_scrape1.wav", 50)
end

function SWEP:CancelInstall()
    ws.constants.CancelSWEPAction(self, function() return self:GetInstalling() end, function()
        self:SetInstalling(false)
        self.targetDoor = nil
        self.installingToolkit = nil
    end)
end

function SWEP:CompleteInstall()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self.targetDoor
    local item = self.wsItem

    if not IsValid(door) or not item then
        self:CancelInstall()
        return
    end

    -- Get lock data from item
    local lockData = {
        keyings = item:GetData("keyings", {}),
        durability = item:GetData("durability", 100),
        name = item:GetData("lockName", "")
    }

    -- Install lock on door using centralized function
    ws.doors.InstallLock(door, lockData)

    -- Damage toolkit slightly
    local toolkit = self.installingToolkit
    if toolkit and toolkit.TakeDurabilityDamage then
        toolkit:TakeDurabilityDamage(1)
    end

    -- Remove lock from inventory
    local _, inventory = ws.constants.GetCharacterInventory(owner)
    if inventory then
        inventory:Remove(item:GetID())
    end

    -- Strip weapon and clean up
    owner:StripWeapon("ix_lock")
    owner.wsLockItem = nil

    owner:EmitSound("buttons/button14.wav", 60)
    owner:NotifyLocalized("lockInstalled")

    self:SetInstalling(false)
    self.targetDoor = nil
    self.installingToolkit = nil
end

-- ============================================================================
-- THINK - Input Detection & Installation Progress
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        local lmb, rmb = ws.constants.ProcessSWEPInput(self)

        if rmb and not self:GetInstalling() and CurTime() >= (self.nextInstallAttempt or 0) then
            self.nextInstallAttempt = CurTime() + 0.5
            net.Start("wsLockInstall")
            net.SendToServer()
        end

        if lmb and self:GetInstalling() then
            net.Start("wsLockCancel")
            net.SendToServer()
        end
    end

    -- Installation progress checks (server only)
    if self:GetInstalling() then
        if SERVER then
            local valid, reason = ws.weapon.IsTargetValid(owner, self:GetTargetDoor(), self.targetDoor, self.MaxUseDistance)
            if not valid then
                self:CancelInstall()
                if reason == "looked_away" then owner:NotifyLocalized("lockLookedAway")
                elseif reason == "too_far" then owner:NotifyLocalized("lockTooFar") end
                return
            end
        end

        -- Check if installation complete
        local elapsed = CurTime() - self:GetInstallStartTime()
        if elapsed >= self:GetInstallDuration() then
            if SERVER then
                self:CompleteInstall()
            end
        end
    end
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

function SWEP:DrawWorldModel()
    ws.constants.DrawWorldModelBone(self, {4, 1, -2}, {{"Forward", 90}})
end

-- ============================================================================
-- HUD - Installation Progress
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        if not self:GetInstalling() then return end

        local progress = math.Clamp((CurTime() - self:GetInstallStartTime()) / self:GetInstallDuration(), 0, 1)
        ws.constants.DrawProgressBar("Installing Lock...", progress, Color(100, 150, 200), "LMB to cancel")
    end
end
