--[[
    Hands Up SWEP

    A weapon that indicates surrender by raising hands.
    - Normal movement allowed
    - Radio usage disabled while equipped
    - Cannot be dropped
]]--

AddCSLuaFile()

if CLIENT then
    SWEP.PrintName = "Hands Up"
    SWEP.Slot = 0
    SWEP.SlotPos = 3
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = false
end

SWEP.Author = "Windswept"
SWEP.Instructions = "Equip to raise your hands in surrender."
SWEP.Purpose = "Indicating surrender."
SWEP.Drop = false

SWEP.ViewModelFOV = 45
SWEP.ViewModelFlip = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.ViewModel = Model("models/weapons/c_arms.mdl")
SWEP.WorldModel = ""

SWEP.UseHands = true
SWEP.HoldType = "normal"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    local owner = self:GetOwner()
    if not IsValid(owner) then return true end

    -- Set hands up netvar (used by CalcMainActivity hook)
    if SERVER then
        owner:SetNetVar("handsUp", true)
    end

    return true
end

function SWEP:Holster()
    local owner = self:GetOwner()
    if SERVER and IsValid(owner) then
        owner:SetNetVar("handsUp", nil)
    end
    return true
end

function SWEP:OnRemove()
    local owner = self:GetOwner()
    if SERVER and IsValid(owner) then
        owner:SetNetVar("handsUp", nil)
    end
end

function SWEP:PrimaryAttack()
    -- Do nothing
end

function SWEP:SecondaryAttack()
    -- Do nothing
end

function SWEP:Reload()
    -- Do nothing
end

function SWEP:Think()
    -- Animation handled by CalcMainActivity hook
end

if CLIENT then
    function SWEP:DrawWorldModel()
        -- Don't draw anything
    end

    function SWEP:DrawWorldModelTranslucent()
        -- Don't draw anything
    end

    function SWEP:PreDrawViewModel()
        return true -- Hide viewmodel
    end

    function SWEP:DoDrawCrosshair(x, y)
        return true -- Hide crosshair
    end
end

-- Override player animation when hands are up
hook.Add("CalcMainActivity", "ixHandsUpAnimation", function(ply, velocity)
    if ply:GetNetVar("handsUp") then
        -- Try to use the cower sequence directly (hands up defensive pose)
        local seq = ply:LookupSequence("seq_cower") or ply:LookupSequence("cower")
        if seq and seq > 0 then
            return ACT_HL2MP_IDLE, seq
        end
        -- Fallback to magic idle (raised hands for casting)
        return ACT_HL2MP_IDLE_MAGIC, -1
    end
end)
