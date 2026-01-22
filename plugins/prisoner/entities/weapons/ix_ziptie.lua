--[[
    Zip Tie SWEP

    Used to restrain players.
    - Raise weapon (R) then LMB on target
    - 5 second progress bar to restrain
    - Consumes the zip tie on success
    - Untying returns zip tie to untier's inventory
]]--

AddCSLuaFile()

SWEP.PrintName = "Zip Tie"
SWEP.Author = "Windswept"
SWEP.Purpose = "Restrain players."
SWEP.Instructions = "Raise (R) then LMB on a player to restrain them."

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModel = ""
SWEP.WorldModel = Model("models/items/crossbowrounds.mdl")

SWEP.UseHands = false
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

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    return true
end

function SWEP:Holster()
    return true
end

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Tying")
    self:NetworkVar("Entity", 0, "TyingTarget")
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

if CLIENT then
    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()

        if not IsValid(owner) then
            self:DrawModel()
            return
        end

        local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        if not bone then
            self:DrawModel()
            return
        end

        local matrix = owner:GetBoneMatrix(bone)
        if not matrix then
            self:DrawModel()
            return
        end

        local pos = matrix:GetTranslation()
        local ang = matrix:GetAngles()

        -- Offset for zip tie (small item held in hand)
        pos = pos + ang:Forward() * 3 + ang:Right() * 1 + ang:Up() * -1

        -- Rotate to lay flat in hand
        ang:RotateAroundAxis(ang:Forward(), 0)
        ang:RotateAroundAxis(ang:Right(), 90)

        self:SetRenderOrigin(pos)
        self:SetRenderAngles(ang)
        self:SetModelScale(1, 0)
        self:DrawModel()
    end
end

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        local isRaised = owner:IsWepRaised()

        if isRaised then
            local lmbDown = input.IsMouseDown(MOUSE_LEFT)

            if lmbDown and not self.wasLMBDown then
                if not self.nextUseTime or self.nextUseTime <= CurTime() then
                    self.nextUseTime = CurTime() + 0.5
                    net.Start("ixZipTieUse")
                    net.SendToServer()
                end
            end

            self.wasLMBDown = lmbDown
        else
            self.wasLMBDown = false
        end
    end
end

function SWEP:PrimaryAttack()
    -- Handled in Think via net message
    return false
end

function SWEP:SecondaryAttack()
    return false
end

-- ============================================================================
-- SERVER LOGIC
-- ============================================================================

if SERVER then
    util.AddNetworkString("ixZipTieUse")

    net.Receive("ixZipTieUse", function(len, client)
        local weapon = client:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_ziptie" then return end

        -- Must be raised
        if not client:IsWepRaised() then
            client:Notify("You must raise the zip tie first.")
            return
        end

        -- Already tying someone
        if weapon:GetTying() then return end

        -- Get linked item
        local item = weapon.ixItem
        if not item then return end

        -- Trace to find target
        local tr = client:GetEyeTrace()
        local target = tr.Entity

        if not IsValid(target) or not target:IsPlayer() or not target:GetCharacter() then
            client:NotifyLocalized("plyNotValid")
            return
        end

        -- Check distance
        if client:GetPos():DistToSqr(target:GetPos()) > (96 * 96) then
            client:Notify("You are too far away.")
            return
        end

        -- Check if already restrained or being tied
        if target:GetNetVar("tying") or target:IsRestricted() then
            client:Notify("This person is already restrained or being restrained.")
            return
        end

        -- Start tying
        weapon:SetTying(true)
        weapon:SetTyingTarget(target)

        client:SetAction("@tying", 5)
        target:SetAction("@beingTied", 5)
        target:SetNetVar("tying", true)

        client:DoStaredAction(target, function()
            -- Success - restrain the target
            target:SetRestricted(true)
            target:SetNetVar("tying", nil)
            target:SetNetVar("tiedBy", client:GetCharacter():GetID())
            target:NotifyLocalized("restrained")

            -- Remove the item and strip the weapon
            if IsValid(weapon) then
                weapon:SetTying(false)
                weapon:SetTyingTarget(nil)
            end

            client.ixZipTieItem = nil

            if client:HasWeapon("ix_ziptie") then
                client:StripWeapon("ix_ziptie")
            end

            item:Remove()
        end, 5, function()
            -- Cancelled
            if IsValid(weapon) then
                weapon:SetTying(false)
                weapon:SetTyingTarget(nil)
            end

            client:SetAction()

            if IsValid(target) then
                target:SetAction()
                target:SetNetVar("tying", nil)
            end
        end)
    end)
end

-- ============================================================================
-- CLIENT CROSSHAIR
-- ============================================================================

if CLIENT then
    function SWEP:DoDrawCrosshair(x, y)
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local tr = owner:GetEyeTrace()
        local target = tr.Entity

        local color = Color(255, 255, 255, 200)

        if IsValid(target) and target:IsPlayer() then
            if target:IsRestricted() then
                color = Color(150, 150, 150, 100) -- Gray - already restrained
            elseif owner:IsWepRaised() then
                color = Color(255, 200, 100, 255) -- Orange - can restrain
            end
        end

        local size = 8
        surface.SetDrawColor(color)
        surface.DrawLine(x - size, y, x + size, y)
        surface.DrawLine(x, y - size, x, y + size)

        return true
    end
end
