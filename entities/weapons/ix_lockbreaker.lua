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

if SERVER then
    util.AddNetworkString("ixLockbreakerStart")
    util.AddNetworkString("ixLockbreakerCancel")
end

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

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    net.Receive("ixLockbreakerStart", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_lockbreaker" then return end
        weapon:StartBreaking()
    end)

    net.Receive("ixLockbreakerCancel", function(len, ply)
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_lockbreaker" then return end
        weapon:CancelBreaking()
    end)
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
        if ply:GetPos():DistToSqr(owner:GetPos()) < 1000000 then  -- ~1000 units
            ply:NotifyLocalized("lockbreakerHeard")
        end
    end
end

function SWEP:CancelBreaking()
    if not self:IsBreaking() then return end

    self:SetBreaking(false)
    self.targetDoor = nil

    local owner = self:GetOwner()
    if IsValid(owner) and SERVER then
        owner:EmitSound("buttons/button10.wav", 50)
    end
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

        -- RMB pressed - start breaking
        if rmbDown and not self.wasRMBDown then
            if not self:IsBreaking() and CurTime() >= (self.nextBreakAttempt or 0) then
                self.nextBreakAttempt = CurTime() + 0.5
                net.Start("ixLockbreakerStart")
                net.SendToServer()
            end
        end

        -- LMB pressed - cancel breaking
        if lmbDown and not self.wasLMBDown then
            if self:IsBreaking() then
                net.Start("ixLockbreakerCancel")
                net.SendToServer()
            end
        end

        self.wasRMBDown = rmbDown
        self.wasLMBDown = lmbDown
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

    pos = pos + ang:Forward() * 5 + ang:Right() * 2 + ang:Up() * -3
    ang:RotateAroundAxis(ang:Right(), -90)
    ang:RotateAroundAxis(ang:Forward(), 180)

    self:SetRenderOrigin(pos)
    self:SetRenderAngles(ang)
    self:DrawModel()
end

-- ============================================================================
-- HUD - Breaking Progress
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        if not self:IsBreaking() then return end

        local elapsed = CurTime() - self:GetBreakStartTime()
        local progress = math.Clamp(elapsed / self.BreakTime, 0, 1)

        local w, h = ScrW(), ScrH()
        local barW, barH = 200, 20
        local x, y = (w - barW) / 2, h * 0.6

        -- Background
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(x, y, barW, barH)

        -- Progress fill (red/orange for destructive action)
        surface.SetDrawColor(200, 100, 50, 255)
        surface.DrawRect(x + 2, y + 2, (barW - 4) * progress, barH - 4)

        -- Border
        surface.SetDrawColor(200, 200, 200, 255)
        surface.DrawOutlinedRect(x, y, barW, barH, 2)

        -- Text
        draw.SimpleText("Breaking Lock...", "ixSmallFont", w / 2, y - 20, Color(255, 150, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        draw.SimpleText("LOUD - Others can hear this!", "ixSmallFont", w / 2, y + barH + 10, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("LMB to cancel", "ixSmallFont", w / 2, y + barH + 30, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end
