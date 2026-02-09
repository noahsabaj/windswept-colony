--[[
    Base Windswept SWEP

    Universal defaults shared by all Windswept SWEPs (except ix_flashlight which
    inherits from shaky_flashlight). Child SWEPs only need to set their unique
    properties and override methods as needed.

    Provides:
    - Standard Primary/Secondary (no clip, no ammo)
    - Drop=false, Spawnable=false, DrawAmmo=false, DrawCrosshair=true
    - ViewModelFOV=54, ViewModel=c_arms, UseHands=true, HoldType="normal"
    - Initialize: SetHoldType + edge detection vars
    - Deploy: SetHoldType + return true
    - Empty PrimaryAttack/SecondaryAttack stubs
]]--

AddCSLuaFile()

SWEP.Author = "Windswept"

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModelFOV = 54
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
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

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self.wasLMBDown = false
    self.wasRMBDown = false
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    return true
end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end
