--[[
    Lockpick SWEP

    Controls:
    - RMB on locked door: Start lockpicking minigame

    The minigame is a timing bar with a sweet spot.
    Player must press LMB when ticker is in the sweet spot.
    Each attempt damages lock durability.
    Failed attempts may break the lockpick.
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Lockpick"
SWEP.Purpose = "Pick locks on doors."
SWEP.Instructions = "RMB on locked door: Pick lock"

SWEP.WorldModel = "models/props_c17/tools_pliers01a.mdl"

SWEP.MaxUseDistance = 96

-- Minigame settings
SWEP.TickerSpeed = 2.0  -- Full bar traversals per second
SWEP.LockDamageMin = 1
SWEP.LockDamageMax = 5

-- ============================================================================
-- NETWORKING
-- ============================================================================

-- Network strings registered in schema/sv_netstrings.lua

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Picking")
    self:NetworkVar("Float", 0, "SweetSpotStart")
    self:NetworkVar("Float", 1, "SweetSpotSize")
    self:NetworkVar("Int", 0, "CurrentHits")
    self:NetworkVar("Int", 1, "RequiredHits")
    self:NetworkVar("Int", 2, "AttemptsLeft")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Initialize()
    self.BaseClass.Initialize(self)
    self.nextPickAttempt = 0
    self.nextServerAttempt = 0

    if self.SetPicking then
        self:SetPicking(false)
    end
end

function SWEP:Deploy()
    self.BaseClass.Deploy(self)
    if self.SetPicking then
        self:SetPicking(false)
    end
    return true
end

function SWEP:IsPicking()
    if not self.GetPicking then return false end
    return self:GetPicking()
end

function SWEP:Holster()
    self:CancelPicking()
    return true
end

function SWEP:OnRemove()
    self:CancelPicking()
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function SWEP:GetTargetDoor()
    return ws.doors.GetTargetDoor(self:GetOwner(), self.MaxUseDistance)
end

function SWEP:GenerateSweetSpot()
    local item = self.wsItem
    if not item then return 0.5, 0.1 end

    local size = item:GetSweetSpotSize()
    -- Random position, but ensure it fits on bar
    local start = math.Rand(0.05, 0.95 - size)

    return start, size
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    ws.weapon.NetReceive("wsLockpickStart", "ix_lockpick", "StartPicking")

    net.Receive("wsLockpickAttempt", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_lockpick" then return end
        if not weapon:IsPicking() then return end

        -- Server-side rate limit. Hit detection is necessarily client-side (the
        -- timing ticker runs on the client), so a modified client can always send
        -- hit=true; this throttle stops a script from completing the minigame
        -- instantly by spamming attempts. Full protection relies on external
        -- anticheat. Interval is derived from the ticker speed.
        local now = CurTime()
        if weapon.nextServerAttempt and now < weapon.nextServerAttempt then return end
        weapon.nextServerAttempt = now + math.max(0.1, 1 / (weapon.TickerSpeed * 3))

        -- Defensive: no attempts remaining (IsPicking is normally already cleared)
        if weapon:GetAttemptsLeft() <= 0 then return end

        local hit = net.ReadBool()

        -- Do damage to lock regardless
        weapon:DoAttempt()

        if hit then
            local currentHits = weapon:GetCurrentHits() + 1
            weapon:SetCurrentHits(currentHits)

            if currentHits >= weapon:GetRequiredHits() then
                weapon:OnPickSuccess()
            else
                -- Partial success, continue
                ply:EmitSound("buttons/button14.wav", 40)

                -- Generate new sweet spot
                local sweetStart, sweetSize = weapon:GenerateSweetSpot()
                weapon:SetSweetSpotStart(sweetStart)
                weapon:SetSweetSpotSize(sweetSize)
            end
        else
            weapon:OnPickFail()
        end
    end)

    ws.weapon.NetReceive("wsLockpickCancel", "ix_lockpick", "CancelPicking")
end

function SWEP:StartPicking()
    if CLIENT then return end
    if not self.SetPicking then return end
    if self:IsPicking() then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("lockpickNoDoor")
        return
    end

    -- Check if door has a lock
    if not ws.doors.HasLock(door) then
        owner:NotifyLocalized("lockpickNoLock")
        return
    end

    -- Check if door is locked
    if not door:IsLocked() then
        owner:NotifyLocalized("lockpickAlreadyUnlocked")
        return
    end

    -- Check if lock is broken
    local lockData = door.wsLockData
    if lockData.durability and lockData.durability <= 0 then
        owner:NotifyLocalized("lockpickLockBroken")
        return
    end

    local item = self.wsItem
    if not item then return end

    -- Initialize minigame state
    local sweetStart, sweetSize = self:GenerateSweetSpot()
    self:SetSweetSpotStart(sweetStart)
    self:SetSweetSpotSize(sweetSize)
    self:SetCurrentHits(0)
    self:SetRequiredHits(item:GetRequiredHits())
    self:SetAttemptsLeft(item:GetMaxAttempts())
    self:SetPicking(true)
    self.targetDoor = door

    owner:EmitSound("physics/metal/metal_solid_impact_soft3.wav", 40)
end

function SWEP:CancelPicking()
    ws.constants.CancelSWEPAction(self, function() return self:IsPicking() end, function()
        self:SetPicking(false)
        self.targetDoor = nil
    end, 40)
end

function SWEP:DoAttempt()
    if CLIENT then return end
    if not self:IsPicking() then return end

    local owner = self:GetOwner()
    local door = self.targetDoor
    local item = self.wsItem

    if not IsValid(door) or not item then
        self:CancelPicking()
        return
    end

    -- Calculate ticker position (server doesn't have precise timing, use approximate)
    -- In a real implementation, client would send their ticker position
    -- For now, we'll trust the client's timing check

    -- Damage the lock. DamageLock returns a BOOLEAN (true = lock destroyed) and
    -- already fires "unlock" + the break sound on the door when it breaks, so we
    -- only need to notify the picker and stop. (Previously this compared the
    -- boolean with <= 0, which errored every attempt and broke lockpicking.)
    if ws.doors.HasLock(door) then
        local damage = math.random(self.LockDamageMin, self.LockDamageMax)
        local destroyed = ws.doors.DamageLock(door, damage)

        if destroyed then
            owner:NotifyLocalized("lockpickLockDestroyed")
            self:CancelPicking()
            return
        end
    end
end

function SWEP:OnPickSuccess()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self.targetDoor

    if not IsValid(door) then
        self:CancelPicking()
        return
    end

    -- Unlock the door (syncs to partner for double doors)
    ws.doors.UnlockDoor(door)

    owner:EmitSound("doors/door_latch1.wav", 60)
    owner:NotifyLocalized("lockpickSuccess")

    self:CancelPicking()

    -- Save persistence
    if ws.doors and ws.doors.Save then
        ws.doors.Save()
    end
end

function SWEP:OnPickFail()
    if CLIENT then return end

    local owner = self:GetOwner()
    local item = self.wsItem

    if not item then
        self:CancelPicking()
        return
    end

    -- Check if lockpick breaks
    local breakChance = item:GetBreakChance()
    if math.random() < breakChance then
        -- Lockpick breaks!
        owner:EmitSound("physics/metal/metal_sheet_impact_hard6.wav", 70)
        owner:NotifyLocalized("lockpickBroke")

        -- Remove the lockpick item
        local _, inventory = ws.constants.GetCharacterInventory(owner)
        if inventory then
            inventory:Remove(item:GetID())
        end

        owner:StripWeapon("ix_lockpick")
        owner.wsLockpickItem = nil
        self:SetPicking(false)
        self.targetDoor = nil
        return
    end

    -- Decrease attempts
    local attemptsLeft = self:GetAttemptsLeft() - 1
    self:SetAttemptsLeft(attemptsLeft)

    if attemptsLeft <= 0 then
        -- Out of attempts
        owner:NotifyLocalized("lockpickOutOfAttempts")
        self:CancelPicking()
        return
    end

    -- Generate new sweet spot for next attempt
    local sweetStart, sweetSize = self:GenerateSweetSpot()
    self:SetSweetSpotStart(sweetStart)
    self:SetSweetSpotSize(sweetSize)

    owner:EmitSound("buttons/button11.wav", 50)
end

-- ============================================================================
-- THINK - Input Detection & Picking Progress
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        local lmb, rmb = ws.constants.ProcessSWEPInput(self)

        if rmb then
            if self:IsPicking() then
                net.Start("wsLockpickCancel")
                net.SendToServer()
            elseif CurTime() >= (self.nextPickAttempt or 0) then
                self.nextPickAttempt = CurTime() + 0.5
                net.Start("wsLockpickStart")
                net.SendToServer()
            end
        end

        if lmb and self:IsPicking() then
            local tickerPos = self:GetTickerPosition()
            local sweetStart = self:GetSweetSpotStart()
            local sweetSize = self:GetSweetSpotSize()
            local hit = tickerPos >= sweetStart and tickerPos <= (sweetStart + sweetSize)

            net.Start("wsLockpickAttempt")
            net.WriteBool(hit)
            net.SendToServer()
        end
    end

    -- Picking progress checks (server only)
    if self:IsPicking() then
        if SERVER then
            local valid, reason = ws.weapon.IsTargetValid(owner, self:GetTargetDoor(), self.targetDoor, self.MaxUseDistance)
            if not valid then
                self:CancelPicking()
                if reason == "looked_away" then owner:NotifyLocalized("lockpickLookedAway")
                elseif reason == "too_far" then owner:NotifyLocalized("lockpickTooFar") end
                return
            end
        end
    end
end

function SWEP:GetTickerPosition()
    -- Oscillate between 0 and 1
    local time = CurTime() * self.TickerSpeed
    return (math.sin(time * math.pi) + 1) / 2
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

function SWEP:DrawWorldModel()
    ws.constants.DrawWorldModelBone(self, {3, 0.5, -1}, {{"Forward", 45}})
end

-- ============================================================================
-- HUD - Lockpicking Minigame
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        if not self:IsPicking() then return end

        local w, h = ScrW(), ScrH()
        local barW, barH = ScreenScale(150), ScreenScale(15)
        local pad = ScreenScale(5)
        local tickerW = ScreenScale(2)
        local tickerOverhang = ScreenScale(3)
        local textGap = ScreenScale(15)
        local x, y = (w - barW) / 2, h * 0.6

        -- Background
        surface.SetDrawColor(30, 30, 30, 230)
        surface.DrawRect(x - pad * 2, y - textGap * 2, barW + pad * 4, barH + textGap * 2 + pad * 2 + textGap * 3)

        -- Sweet spot
        local sweetStart = self:GetSweetSpotStart()
        local sweetSize = self:GetSweetSpotSize()
        local sweetX = x + (barW * sweetStart)
        local sweetW = barW * sweetSize

        surface.SetDrawColor(50, 150, 50, 200)
        surface.DrawRect(sweetX, y, sweetW, barH)

        -- Bar background
        surface.SetDrawColor(60, 60, 60, 255)
        surface.DrawRect(x, y, barW, barH)

        -- Sweet spot on top
        surface.SetDrawColor(80, 200, 80, 255)
        surface.DrawRect(sweetX, y, sweetW, barH)

        -- Border
        surface.SetDrawColor(200, 200, 200, 255)
        surface.DrawOutlinedRect(x, y, barW, barH, 2)

        -- Ticker
        local tickerPos = self:GetTickerPosition()
        local tickerX = x + (barW * tickerPos) - tickerW / 2
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(tickerX, y - tickerOverhang, tickerW, barH + tickerOverhang * 2)

        -- Progress (hits)
        local currentHits = self:GetCurrentHits()
        local requiredHits = self:GetRequiredHits()

        draw.SimpleText("Progress: " .. currentHits .. "/" .. requiredHits, "wsSmallFont", w / 2, y - textGap, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

        -- Attempts remaining
        local attemptsLeft = self:GetAttemptsLeft()
        draw.SimpleText("Attempts: " .. attemptsLeft, "wsSmallFont", w / 2, y + barH + pad * 2, ws.constants.COLOR_UI_NEUTRAL, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- Instructions
        draw.SimpleText("LMB when ticker is in green zone | RMB to cancel", "wsSmallFont", w / 2, y + barH + pad * 2 + textGap, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end
