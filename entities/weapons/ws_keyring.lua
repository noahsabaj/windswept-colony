--[[
    Key Ring SWEP

    Controls:
    - R: Cycle through keys
    - LMB: Lock door with current key
    - RMB: Unlock door with current key

    Works just like a regular key, but can switch between multiple keys.
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Key Ring"
SWEP.Purpose = "Manage multiple keys."
SWEP.Instructions = "R: Cycle | LMB: Lock | RMB: Unlock"

SWEP.WorldModel = "models/props_c17/tools_wrench01a.mdl"

SWEP.MaxUseDistance = 96

-- ============================================================================
-- NETWORKING
-- ============================================================================

-- Network strings registered in schema/sv_netstrings.lua

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
    self.BaseClass.Initialize(self)
    self:SetCurrentKeyIndex(1)
    self.wasReloadDown = false
    self.nextLockAttempt = 0
    self.nextUnlockAttempt = 0
    self.nextCycleAttempt = 0
end

function SWEP:Deploy()
    self.BaseClass.Deploy(self)
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
    return self.wsItem
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
    return ws.doors.GetTargetDoor(self:GetOwner(), self.MaxUseDistance)
end

function SWEP:CanKeyFitLock(door)
    local keying = self:GetCurrentKeying()
    if not keying or keying == "" then return false end

    -- Use centralized keying check
    return ws.doors.CheckKeying(door, keying)
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    ws.weapon.NetReceive("wsKeyringCycle", "ws_keyring", "DoCycle")
    ws.weapon.NetReceive("wsKeyringLock", "ws_keyring", "DoLock")
    ws.weapon.NetReceive("wsKeyringUnlock", "ws_keyring", "DoUnlock")
end

-- Server-side per-weapon throttle. The client's self.next*Attempt gates are
-- cosmetic only; never trust them for rate limiting. (sc-doors-access-4) (sc-weapons-tools-5)
function SWEP:ServerRateLimited(interval)
    if self.svNextAttempt and self.svNextAttempt > CurTime() then
        return true
    end

    self.svNextAttempt = CurTime() + (interval or 1)
    return false
end

function SWEP:DoCycle()
    if CLIENT then return end
    if self:ServerRateLimited(0.3) then return end

    local item = self:GetItem()
    if not item then return end

    item:CycleKey(1)
    self:UpdateCurrentKey()

    local owner = self:GetOwner()
    owner:EmitSound("physics/metal/metal_solid_impact_soft1.wav", 40, 120)
end

function SWEP:DoLock()
    if CLIENT then return end
    if self:ServerRateLimited(1) then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("keyNoDoor")
        return
    end

    if not ws.doors.HasLock(door) then
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
    if ws.doors.IsDoorOpen(door) then
        owner:NotifyLocalized("keyDoorOpen")
        return
    end

    -- Lock the door (syncs to partner for double doors)
    ws.doors.LockDoor(door)
    door:EmitSound("doors/door_latch3.wav", 70)
    owner:NotifyLocalized("keyLocked")
end

function SWEP:DoUnlock()
    if CLIENT then return end
    if self:ServerRateLimited(1) then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("keyNoDoor")
        return
    end

    if not ws.doors.HasLock(door) then
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
    ws.doors.UnlockDoor(door)
    door:EmitSound("doors/door_latch1.wav", 70)
    owner:NotifyLocalized("keyUnlocked")
end

-- ============================================================================
-- THINK - Input Detection
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        local lmb, rmb = ws.constants.ProcessSWEPInput(self)

        if lmb and CurTime() >= (self.nextLockAttempt or 0) then
            self.nextLockAttempt = CurTime() + 1
            net.Start("wsKeyringLock")
            net.SendToServer()
        end

        if rmb and CurTime() >= (self.nextUnlockAttempt or 0) then
            self.nextUnlockAttempt = CurTime() + 1
            net.Start("wsKeyringUnlock")
            net.SendToServer()
        end

        -- R key: cycle keys
        local reloadDown = input.IsKeyDown(KEY_R)
        if reloadDown and self.wasReloadDown == false and CurTime() >= (self.nextCycleAttempt or 0) then
            self.nextCycleAttempt = CurTime() + 0.3
            net.Start("wsKeyringCycle")
            net.SendToServer()
        end
        self.wasReloadDown = reloadDown
    end
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

function SWEP:DrawWorldModel()
    ws.constants.DrawWorldModelBone(self, {3, 1, -1}, {{"Forward", 90}, {"Up", 180}})
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
        surface.SetFont("wsSmallFont")
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
        draw.SimpleText(keyName, "wsSmallFont", w / 2, textY, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        textY = textY + nameH + lineSpacing

        -- Keying (if valid)
        if keyingText ~= "" then
            draw.SimpleText(keyingText, "wsSmallFont", w / 2, textY, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        -- Instructions (below box)
        draw.SimpleText(instructionText, "wsSmallFont", w / 2, y + boxH + lineSpacing, Color(100, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end
