--[[
    Lock SWEP

    Controls:
    - RMB while looking at door: Install lock (requires toolkit in inventory)

    Works with Windswept managed doors (prop_door_rotating with ixIsWindsweptDoor marker).
]]--

AddCSLuaFile()

SWEP.PrintName = "Lock"
SWEP.Author = "Windswept"
SWEP.Purpose = "Install locks on doors."
SWEP.Instructions = "RMB on door: Install lock"

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModelFOV = 54
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = "models/props_c17/tools_pliers01a.mdl"  -- Placeholder
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

-- Time to install lock (modified by toolkit)
SWEP.BaseInstallTime = 6  -- 6 seconds base, toolkit reduces this

-- ============================================================================
-- NETWORKING
-- ============================================================================

if SERVER then
    util.AddNetworkString("ixLockInstall")
    util.AddNetworkString("ixLockProgress")
    util.AddNetworkString("ixLockCancel")
end

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
    self:SetInstalling(false)
    self.wasRMBDown = false
    self.wasLMBDown = false
    self.nextInstallAttempt = 0
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
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
    local owner = self:GetOwner()
    if not IsValid(owner) then return nil end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.MaxUseDistance,
        filter = owner
    })

    local ent = tr.Entity
    if not IsValid(ent) then return nil end

    -- Check if it's our managed door
    if ent.ixIsWindsweptDoor then
        return ent
    end

    return nil
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
    net.Receive("ixLockInstall", function(len, ply)
        print("[ix_lock] Received ixLockInstall from " .. ply:Nick())
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_lock" then
            print("[ix_lock] ERROR: Player's active weapon is not ix_lock!")
            return
        end

        weapon:StartInstall()
    end)

    net.Receive("ixLockCancel", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_lock" then return end

        weapon:CancelInstall()
    end)
end

function SWEP:StartInstall()
    if CLIENT then return end

    local owner = self:GetOwner()
    print("[ix_lock] StartInstall called for " .. owner:Nick())

    local door = self:GetTargetDoor()
    print("[ix_lock] GetTargetDoor returned: " .. tostring(door))

    if not IsValid(door) then
        print("[ix_lock] No valid door found - notifying lockNoDoor")
        owner:NotifyLocalized("lockNoDoor")
        return
    end

    -- Check if door already has a lock
    if ix.doors.HasLock(door) then
        owner:NotifyLocalized("lockAlreadyHasLock")
        return
    end

    -- Check for toolkit
    local hasToolkit, toolkit = self:HasToolkit()
    print("[ix_lock] HasToolkit: " .. tostring(hasToolkit))
    if not hasToolkit then
        print("[ix_lock] No toolkit - notifying lockNeedToolkit")
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
    if not self:GetInstalling() then return end

    self:SetInstalling(false)
    self.targetDoor = nil
    self.installingToolkit = nil

    local owner = self:GetOwner()
    if IsValid(owner) then
        owner:EmitSound("buttons/button10.wav", 50)
    end
end

function SWEP:CompleteInstall()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self.targetDoor
    local item = self.ixItem

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
    ix.doors.InstallLock(door, lockData)

    -- Damage toolkit slightly
    local toolkit = self.installingToolkit
    if toolkit and toolkit.TakeDurabilityDamage then
        toolkit:TakeDurabilityDamage(1)
    end

    -- Remove lock from inventory
    local character = owner:GetCharacter()
    if character then
        local inventory = character:GetInventory()
        if inventory then
            inventory:Remove(item:GetID())
        end
    end

    -- Strip weapon and clean up
    owner:StripWeapon("ix_lock")
    owner.ixLockItem = nil

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
            if not self:GetInstalling() and CurTime() >= (self.nextInstallAttempt or 0) then
                self.nextInstallAttempt = CurTime() + 0.5
                net.Start("ixLockInstall")
                net.SendToServer()
            end
        end

        -- LMB pressed - cancel install
        if lmbDown and not self.wasLMBDown then
            if self:GetInstalling() then
                net.Start("ixLockCancel")
                net.SendToServer()
            end
        end

        self.wasRMBDown = rmbDown
        self.wasLMBDown = lmbDown
    end

    -- Installation progress checks (server only)
    if self:GetInstalling() then
        if SERVER then
            local currentDoor = self:GetTargetDoor()
            if currentDoor ~= self.targetDoor then
                self:CancelInstall()
                owner:NotifyLocalized("lockLookedAway")
                return
            end

            -- Check if owner moved too far
            if not IsValid(self.targetDoor) then
                self:CancelInstall()
                return
            end

            local distance = owner:GetPos():Distance(self.targetDoor:GetPos())
            if distance > self.MaxUseDistance + 32 then
                self:CancelInstall()
                owner:NotifyLocalized("lockTooFar")
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
    local owner = self:GetOwner()
    if not IsValid(owner) then
        return self:DrawModel()
    end

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

    pos = pos + ang:Forward() * 4 + ang:Right() * 1 + ang:Up() * -2
    ang:RotateAroundAxis(ang:Forward(), 90)

    self:SetRenderOrigin(pos)
    self:SetRenderAngles(ang)
    self:DrawModel()
end

-- ============================================================================
-- HUD - Installation Progress
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        if not self:GetInstalling() then return end

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
        surface.SetDrawColor(100, 150, 200, 255)
        surface.DrawRect(x + 2, y + 2, (barW - 4) * progress, barH - 4)

        -- Border
        surface.SetDrawColor(200, 200, 200, 255)
        surface.DrawOutlinedRect(x, y, barW, barH, 2)

        -- Text
        draw.SimpleText("Installing Lock...", "ixSmallFont", w / 2, y - 20, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        draw.SimpleText("LMB to cancel", "ixSmallFont", w / 2, y + barH + 10, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end
