--[[
    Key Ring SWEP

    Controls:
    - R: Cycle through keys
    - LMB: Lock door with current key
    - RMB: Unlock door with current key

    Works just like a regular key, but can switch between multiple keys.
]]--

AddCSLuaFile()

SWEP.PrintName = "Key Ring"
SWEP.Author = "Windswept"
SWEP.Purpose = "Manage multiple keys."
SWEP.Instructions = "R: Cycle | LMB: Lock | RMB: Unlock"

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModelFOV = 54
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = "models/props_c17/tools_wrench01a.mdl"
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

SWEP.MaxUseDistance = 96

-- ============================================================================
-- NETWORKING
-- ============================================================================

if SERVER then
    util.AddNetworkString("ixKeyringLock")
    util.AddNetworkString("ixKeyringUnlock")
    util.AddNetworkString("ixKeyringCycle")
end

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Int", 0, "CurrentKeyIndex")
    self:NetworkVar("String", 0, "CurrentKeyName")
    self:NetworkVar("String", 1, "CurrentKeying")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:SetCurrentKeyIndex(1)
    self.wasLMBDown = false
    self.wasRMBDown = false
    self.wasReloadDown = false
    self.nextLockAttempt = 0
    self.nextUnlockAttempt = 0
    self.nextCycleAttempt = 0
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    self:UpdateCurrentKey()
    return true
end

function SWEP:Holster()
    return true
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function SWEP:GetItem()
    return self.ixItem
end

function SWEP:GetCurrentKey()
    local item = self:GetItem()
    if not item then return nil end
    return item:GetCurrentKey()
end

function SWEP:UpdateCurrentKey()
    if CLIENT then return end

    local key = self:GetCurrentKey()
    if key then
        local name = key:GetData("keyName", "")
        local keying = key:GetData("keying", "")

        if name == "" then
            name = "Key [" .. keying .. "]"
        end

        self:SetCurrentKeyName(name)
        self:SetCurrentKeying(keying)
    else
        self:SetCurrentKeyName("No Key")
        self:SetCurrentKeying("")
    end
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

    -- Check if it's our managed door
    if ent.ixIsWindsweptDoor then
        return ent
    end

    return nil
end

function SWEP:CanKeyFitLock(door)
    local keying = self:GetCurrentKeying()
    if not keying or keying == "" then return false end

    -- Use centralized keying check
    return ix.doors.CheckKeying(door, keying)
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    net.Receive("ixKeyringCycle", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_keyring" then return end

        weapon:DoCycle()
    end)

    net.Receive("ixKeyringLock", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_keyring" then return end

        weapon:DoLock()
    end)

    net.Receive("ixKeyringUnlock", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_keyring" then return end

        weapon:DoUnlock()
    end)
end

function SWEP:DoCycle()
    if CLIENT then return end

    local item = self:GetItem()
    if not item then return end

    item:CycleKey(1)
    self:UpdateCurrentKey()

    local owner = self:GetOwner()
    owner:EmitSound("physics/metal/metal_solid_impact_soft1.wav", 40, 120)
end

function SWEP:DoLock()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("keyNoDoor")
        return
    end

    if not ix.doors.HasLock(door) then
        owner:NotifyLocalized("keyNoLock")
        return
    end

    if not self:CanKeyFitLock(door) then
        owner:NotifyLocalized("keyDoesntFit")
        owner:EmitSound("buttons/button11.wav", 50)
        return
    end

    if door:IsLocked() then
        owner:NotifyLocalized("keyAlreadyLocked")
        return
    end

    -- Check if door is open (can't lock an open door)
    if ix.doors.IsDoorOpen(door) then
        owner:NotifyLocalized("keyDoorOpen")
        return
    end

    -- Lock the door (syncs to partner for double doors)
    ix.doors.LockDoor(door)
    door:EmitSound("doors/door_latch3.wav", 70)
    owner:NotifyLocalized("keyLocked")
end

function SWEP:DoUnlock()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("keyNoDoor")
        return
    end

    if not ix.doors.HasLock(door) then
        owner:NotifyLocalized("keyNoLock")
        return
    end

    if not self:CanKeyFitLock(door) then
        owner:NotifyLocalized("keyDoesntFit")
        owner:EmitSound("buttons/button11.wav", 50)
        return
    end

    if not door:IsLocked() then
        owner:NotifyLocalized("keyAlreadyUnlocked")
        return
    end

    -- Unlock the door (syncs to partner for double doors)
    ix.doors.UnlockDoor(door)
    door:EmitSound("doors/door_latch1.wav", 70)
    owner:NotifyLocalized("keyUnlocked")
end

-- ============================================================================
-- THINK - Input Detection
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
            self.wasReloadDown = false
            return
        end

        local lmbDown = input.IsMouseDown(MOUSE_LEFT)
        local rmbDown = input.IsMouseDown(MOUSE_RIGHT)
        local reloadDown = input.IsKeyDown(KEY_R)

        -- LMB pressed - lock door
        if lmbDown and not self.wasLMBDown then
            if CurTime() >= (self.nextLockAttempt or 0) then
                self.nextLockAttempt = CurTime() + 1
                net.Start("ixKeyringLock")
                net.SendToServer()
            end
        end

        -- RMB pressed - unlock door
        if rmbDown and not self.wasRMBDown then
            if CurTime() >= (self.nextUnlockAttempt or 0) then
                self.nextUnlockAttempt = CurTime() + 1
                net.Start("ixKeyringUnlock")
                net.SendToServer()
            end
        end

        -- R pressed - cycle keys
        if reloadDown and not self.wasReloadDown then
            if CurTime() >= (self.nextCycleAttempt or 0) then
                self.nextCycleAttempt = CurTime() + 0.3
                net.Start("ixKeyringCycle")
                net.SendToServer()
            end
        end

        self.wasLMBDown = lmbDown
        self.wasRMBDown = rmbDown
        self.wasReloadDown = reloadDown
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

    pos = pos + ang:Forward() * 3 + ang:Right() * 1 + ang:Up() * -1
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Up(), 180)

    self:SetRenderOrigin(pos)
    self:SetRenderAngles(ang)
    self:DrawModel()
end

-- ============================================================================
-- HUD - Current Key Display
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        local keyName = self:GetCurrentKeyName()
        local keying = self:GetCurrentKeying()

        if not keyName or keyName == "" then
            keyName = "No Key Selected"
        end

        local w, h = ScrW(), ScrH()
        local padding = ScreenScale(5)
        local lineSpacing = ScreenScale(2)

        -- Measure text sizes
        surface.SetFont("ixSmallFont")
        local nameW, nameH = surface.GetTextSize(keyName)
        local keyingW, keyingH = 0, 0
        local keyingText = ""

        if keying and keying ~= "" then
            keyingText = "[" .. keying .. "]"
            keyingW, keyingH = surface.GetTextSize(keyingText)
        end

        local instructionText = "R to cycle keys"
        local instructionW, instructionH = surface.GetTextSize(instructionText)

        -- Calculate box dimensions based on content
        local boxW = math.max(nameW, keyingW) + (padding * 2)
        local boxH = nameH + (keyingH > 0 and (lineSpacing + keyingH) or 0) + (padding * 2)

        local x = (w - boxW) / 2
        local y = h * 0.7

        -- Background box
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(x, y, boxW, boxH)

        surface.SetDrawColor(100, 100, 150, 255)
        surface.DrawOutlinedRect(x, y, boxW, boxH, 2)

        -- Key name
        local textY = y + padding
        draw.SimpleText(keyName, "ixSmallFont", w / 2, textY, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        textY = textY + nameH + lineSpacing

        -- Keying (if valid)
        if keyingText ~= "" then
            draw.SimpleText(keyingText, "ixSmallFont", w / 2, textY, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        -- Instructions (below box)
        draw.SimpleText(instructionText, "ixSmallFont", w / 2, y + boxH + lineSpacing, Color(100, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end
