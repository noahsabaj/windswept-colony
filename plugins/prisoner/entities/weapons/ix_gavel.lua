--[[
    Gavel SWEP

    A wooden gavel prop for roleplay.
    - Primary: Gavel slam sound (makes noise)
]]--

AddCSLuaFile()

if CLIENT then
    SWEP.PrintName = "Gavel"
    SWEP.Slot = 0
    SWEP.SlotPos = 2
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = true
end

SWEP.Author = "Windswept"
SWEP.Instructions = "Primary: Slam gavel to make noise."
SWEP.Purpose = "Making authoritative noise."
SWEP.Drop = false

SWEP.Spawnable = false
SWEP.AdminSpawnable = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.ViewModel = ""  -- No viewmodel - prop model only
SWEP.WorldModel = Model("models/judge gavels & more/judge_gavel.mdl")

SWEP.UseHands = false
SWEP.HoldType = "melee"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextIdle")
end

function SWEP:Deploy()
    return true
end

function SWEP:CanDeploy()
    return true
end

-- Primary attack: Gavel slam (anyone can do this)
function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1)
    self:SetNextSecondaryFire(CurTime() + 0.5)

    -- Play slam sound
    if SERVER then
        self:EmitSound("physics/wood/wood_crate_impact_hard2.wav", 100, math.random(95, 105))
    end
end

-- Secondary attack: Does nothing (gavel is just for noise)
function SWEP:SecondaryAttack()
    -- No action
end

function SWEP:Reload()
    -- Do nothing
end

if CLIENT then
    -- Manual world model rendering (prop model doesn't attach to hand automatically)
    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()

        -- No owner, just draw normally
        if not IsValid(owner) then
            self:DrawModel()
            return
        end

        -- Find the right hand bone
        local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        if not bone then
            self:DrawModel()
            return
        end

        -- Get the bone's position and angle
        local matrix = owner:GetBoneMatrix(bone)
        if not matrix then
            self:DrawModel()
            return
        end

        local pos = matrix:GetTranslation()
        local ang = matrix:GetAngles()

        -- Offset position to place gavel in hand (gripping handle, head on top)
        pos = pos + ang:Forward() * 3 + ang:Right() * 3 + ang:Up() * -5

        -- Rotate to orient the gavel correctly (handle pointing forward)
        ang:RotateAroundAxis(ang:Forward(), -90)
        ang:RotateAroundAxis(ang:Up(), 180)

        self:SetRenderOrigin(pos)
        self:SetRenderAngles(ang)
        self:SetModelScale(1, 0)
        self:DrawModel()
    end

    -- Simple crosshair
    function SWEP:DoDrawCrosshair(x, y)
        local size = 8
        surface.SetDrawColor(255, 255, 255, 200)
        surface.DrawLine(x - size, y, x + size, y)
        surface.DrawLine(x, y - size, x, y + size)
        return true
    end
end
