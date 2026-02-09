--[[
    Door SWEP

    Controls:
    - RMB while looking at empty frame: Install door (requires toolkit in inventory)

    Works with the ix.doors frame system.
]]--

AddCSLuaFile()

SWEP.PrintName = "Door"
SWEP.Author = "Windswept"
SWEP.Purpose = "Install doors in frames."
SWEP.Instructions = "RMB on frame: Install door"

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModelFOV = 54
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = "models/props_c17/door01_left.mdl"
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

-- Maximum distance to interact with frames
SWEP.MaxUseDistance = 240

-- Base installation time (modified by toolkit)
SWEP.BaseInstallTime = 20  -- 20 seconds base for door

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
    self:SetHoldType(self.HoldType)
    self.wasLMBDown = false
    self.wasRMBDown = false
    self.nextInstallAttempt = 0

    if self.SetInstalling then
        self:SetInstalling(false)
    end
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    if self.SetInstalling then
        self:SetInstalling(false)
    end
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

function SWEP:GetTargetFrame()
    local owner = self:GetOwner()
    if not IsValid(owner) then return nil end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.MaxUseDistance,
        filter = owner
    })

    -- Check if we hit an empty frame
    -- Frames are stored in ix.doors.frames
    if not ix or not ix.doors or not ix.doors.frames then return nil end

    local hitPos = tr.HitPos

    -- Find nearest frame within range
    local nearestFrame = nil
    local nearestDist = 64  -- Max distance from frame center

    for mapID, frameData in pairs(ix.doors.frames) do
        if not frameData.disabled and not frameData.hasDoor then
            local dist = hitPos:Distance(frameData.pos)
            if dist < nearestDist then
                nearestDist = dist
                nearestFrame = {
                    mapID = mapID,
                    data = frameData
                }
            end
        end
    end

    return nearestFrame
end

function SWEP:HasToolkit()
    local owner = self:GetOwner()
    if not IsValid(owner) then return false, nil end

    local character, inventory = ix.constants.GetCharacterInventory(owner)
    if not character or not inventory then return false, nil end

    -- Find best toolkit in inventory
    local bestToolkit = nil
    local bestSpeed = 0

    for _, item in pairs(inventory:GetItems()) do
        if item.uniqueID and string.find(item.uniqueID, "toolkit") then
            local speed = item.installSpeed or 1
            if speed > bestSpeed then
                bestSpeed = speed
                bestToolkit = item
            end
        end
    end

    return bestToolkit ~= nil, bestToolkit
end

function SWEP:IsInstalling()
    if not self.GetInstalling then return false end
    return self:GetInstalling()
end

function SWEP:GetInstallTime()
    local hasToolkit, toolkit = self:HasToolkit()
    if not hasToolkit then
        return self.BaseInstallTime
    end

    local multiplier = toolkit.doorInstallMultiplier or 1
    return self.BaseInstallTime * multiplier
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    ix.weapon.NetReceive("ixDoorInstall", "ix_door", "StartInstall")
    ix.weapon.NetReceive("ixDoorCancel", "ix_door", "CancelInstall")
end

function SWEP:StartInstall()
    if CLIENT then return end
    if not self.SetInstalling then return end
    if self:IsInstalling() then return end

    local owner = self:GetOwner()
    local frame = self:GetTargetFrame()

    if not frame then
        owner:NotifyLocalized("doorNoFrame")
        return
    end

    -- Check for toolkit
    local hasToolkit, toolkit = self:HasToolkit()
    if not hasToolkit then
        owner:NotifyLocalized("doorNeedToolkit")
        return
    end

    -- Start installation
    local installTime = self:GetInstallTime()
    self:SetInstalling(true)
    self:SetInstallStartTime(CurTime())
    self:SetInstallDuration(installTime)
    self.targetFrame = frame
    self.installingToolkit = toolkit

    owner:EmitSound("physics/wood/wood_crate_impact_hard2.wav", 50)
end

function SWEP:CancelInstall()
    ix.constants.CancelSWEPAction(self, function() return self:IsInstalling() end, function()
        self:SetInstalling(false)
        self.targetFrame = nil
        self.installingToolkit = nil
    end)
end

function SWEP:CompleteInstall()
    if CLIENT then return end

    local owner = self:GetOwner()
    local frame = self.targetFrame
    local item = self.ixItem

    if not frame or not item then
        self:CancelInstall()
        return
    end

    -- Build door data from item
    local doorData = {
        type = item.doorType or "wood",
        health = item:GetData("health", item.maxHealth),
        lockData = item:GetData("lockData")
    }

    -- Spawn door using centralized function (uses prop_door_rotating)
    local door = ix.doors.SpawnDoor(frame.mapID, doorData)
    if not IsValid(door) then
        self:CancelInstall()
        owner:NotifyLocalized("doorInstallFailed")
        return
    end

    -- Damage toolkit slightly
    local toolkit = self.installingToolkit
    if toolkit and toolkit.TakeDurabilityDamage then
        toolkit:TakeDurabilityDamage(2)
    end

    -- Remove door from inventory
    local character = owner:GetCharacter()
    if character then
        local inventory = character:GetInventory()
        if inventory then
            inventory:Remove(item:GetID())
        end
    end

    -- Strip weapon and clean up
    owner:StripWeapon("ix_door")
    owner.ixDoorItem = nil

    owner:EmitSound("physics/wood/wood_plank_impact_hard1.wav", 70)
    owner:NotifyLocalized("doorInstalled")

    self:SetInstalling(false)
    self.targetFrame = nil
    self.installingToolkit = nil

    -- Save persistence
    if ix.doors and ix.doors.Save then
        ix.doors.Save()
    end
end

-- ============================================================================
-- THINK - Input Detection & Installation Progress
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        local lmb, rmb = ix.constants.ProcessSWEPInput(self)

        if rmb and not self:IsInstalling() and CurTime() >= (self.nextInstallAttempt or 0) then
            self.nextInstallAttempt = CurTime() + 0.5
            net.Start("ixDoorInstall")
            net.SendToServer()
        end

        if lmb and self:IsInstalling() then
            net.Start("ixDoorCancel")
            net.SendToServer()
        end
    end

    -- Installation progress checks (server only)
    if self:IsInstalling() then
        if SERVER then
            -- Check if still looking at the same frame
            local currentFrame = self:GetTargetFrame()
            if not currentFrame or currentFrame.mapID ~= self.targetFrame.mapID then
                self:CancelInstall()
                owner:NotifyLocalized("doorLookedAway")
                return
            end

            -- Check if owner moved too far
            local distance = owner:GetPos():Distance(self.targetFrame.data.pos)
            if distance > self.MaxUseDistance + 32 then
                self:CancelInstall()
                owner:NotifyLocalized("doorTooFar")
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
    -- Don't draw a door in third person (too big)
    -- Instead show empty hands
end

-- ============================================================================
-- HUD - Installation Progress
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        if not self:IsInstalling() then return end

        local progress = math.Clamp((CurTime() - self:GetInstallStartTime()) / self:GetInstallDuration(), 0, 1)
        ix.constants.DrawProgressBar("Installing Door...", progress, Color(150, 100, 50), "LMB to cancel")
    end
end
