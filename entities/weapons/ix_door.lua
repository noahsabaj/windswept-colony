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

    local character = owner:GetCharacter()
    if not character then return false, nil end

    local inventory = character:GetInventory()
    if not inventory then return false, nil end

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
    net.Receive("ixDoorInstall", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_door" then return end

        weapon:StartInstall()
    end)

    net.Receive("ixDoorCancel", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_door" then return end

        weapon:CancelInstall()
    end)
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
    if not self:IsInstalling() then return end

    self:SetInstalling(false)
    self.targetFrame = nil
    self.installingToolkit = nil

    local owner = self:GetOwner()
    if IsValid(owner) and SERVER then
        owner:EmitSound("buttons/button10.wav", 50)
    end
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

    -- Client-side input detection (Helix doesn't call PrimaryAttack/SecondaryAttack on client)
    if CLIENT then
        -- Don't process input if a UI panel is open
        if vgui.CursorVisible() then
            self.wasLMBDown = false
            self.wasRMBDown = false
            return
        end

        local rmbDown = input.IsMouseDown(MOUSE_RIGHT)
        local lmbDown = input.IsMouseDown(MOUSE_LEFT)

        -- RMB pressed - start install
        if rmbDown and not self.wasRMBDown then
            if not self:IsInstalling() and CurTime() >= (self.nextInstallAttempt or 0) then
                self.nextInstallAttempt = CurTime() + 0.5
                net.Start("ixDoorInstall")
                net.SendToServer()
            end
        end

        -- LMB pressed - cancel install
        if lmbDown and not self.wasLMBDown then
            if self:IsInstalling() then
                net.Start("ixDoorCancel")
                net.SendToServer()
            end
        end

        self.wasRMBDown = rmbDown
        self.wasLMBDown = lmbDown
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

        local elapsed = CurTime() - self:GetInstallStartTime()
        local duration = self:GetInstallDuration()
        local progress = math.Clamp(elapsed / duration, 0, 1)

        local w, h = ScrW(), ScrH()
        local barW, barH = 200, 20
        local x, y = (w - barW) / 2, h * 0.6

        -- Background
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(x, y, barW, barH)

        -- Progress fill
        surface.SetDrawColor(150, 100, 50, 255)
        surface.DrawRect(x + 2, y + 2, (barW - 4) * progress, barH - 4)

        -- Border
        surface.SetDrawColor(200, 200, 200, 255)
        surface.DrawOutlinedRect(x, y, barW, barH, 2)

        -- Text
        draw.SimpleText("Installing Door...", "ixSmallFont", w / 2, y - 20, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        draw.SimpleText("LMB to cancel", "ixSmallFont", w / 2, y + barH + 10, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end
