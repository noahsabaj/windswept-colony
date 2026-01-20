--[[
    Gavel SWEP

    Judge's tool for sentencing and managing prisoners.
    - Primary: Gavel slam sound
    - Secondary: Context-sensitive sentencing/management UI
    - Only usable by Judge classes
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
SWEP.Instructions = "Primary: Slam gavel. Secondary: Sentence/manage prisoner (aim at restrained player)."
SWEP.Purpose = "Sentencing and managing prisoners."
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

SWEP.ViewModel = Model("models/weapons/c_crowbar.mdl")
SWEP.WorldModel = Model("models/weapons/w_crowbar.mdl")

SWEP.UseHands = true
SWEP.HoldType = "melee"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextIdle")
end

-- Check if owner is a judge
function SWEP:IsOwnerJudge()
    local owner = self:GetOwner()
    if not IsValid(owner) then return false end

    local character = owner:GetCharacter()
    if not character then return false end

    local class = character:GetClass()
    return class == CLASS_JUDGE or class == CLASS_ADMIN_JUDGE
end

function SWEP:Deploy()
    if not self:IsOwnerJudge() then
        if SERVER then
            self:GetOwner():NotifyLocalized("judgeOnly")
        end
        return false
    end
    return true
end

function SWEP:CanDeploy()
    return self:IsOwnerJudge()
end

-- Primary attack: Gavel slam
function SWEP:PrimaryAttack()
    if not self:IsOwnerJudge() then return end

    self:SetNextPrimaryFire(CurTime() + 1)
    self:SetNextSecondaryFire(CurTime() + 0.5)

    local owner = self:GetOwner()

    -- Play slam animation
    local vm = owner:GetViewModel()
    if IsValid(vm) then
        vm:SendViewModelMatchingSequence(vm:LookupSequence("misscenter"))
    end

    -- Play slam sound
    if SERVER then
        self:EmitSound("physics/wood/wood_crate_impact_hard2.wav", 100, math.random(95, 105))
    end

    -- Set weapon animation
    self:SendWeaponAnim(ACT_VM_HITCENTER)
end

-- Secondary attack: Context-sensitive sentencing/management
function SWEP:SecondaryAttack()
    if CLIENT then return end
    if not self:IsOwnerJudge() then return end

    self:SetNextSecondaryFire(CurTime() + 0.5)

    local owner = self:GetOwner()

    -- Trace to find target
    local tr = owner:GetEyeTrace()
    local target = tr.Entity

    if not IsValid(target) or not target:IsPlayer() then
        owner:Notify("You must be looking at a player.")
        return
    end

    if not target:IsRestricted() then
        owner:NotifyLocalized("cannotSentence")
        return
    end

    -- Check if target is already a prisoner
    if target:Team() == FACTION_PRISONERS then
        -- Open management UI
        net.Start("ixPrisonerManage")
        net.WriteEntity(target)
        net.Send(owner)
    else
        -- Open sentencing UI
        net.Start("ixPrisonerSentence")
        net.WriteEntity(target)
        net.Send(owner)
    end
end

function SWEP:Reload()
    -- Do nothing
end

if CLIENT then
    -- Custom crosshair for judge mode
    function SWEP:DoDrawCrosshair(x, y)
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local tr = owner:GetEyeTrace()
        local target = tr.Entity

        local color = Color(255, 255, 255, 200)

        if IsValid(target) and target:IsPlayer() then
            if target:IsRestricted() then
                if target:Team() == FACTION_PRISONERS then
                    color = Color(100, 200, 255, 255) -- Blue for prisoner management
                else
                    color = Color(255, 200, 100, 255) -- Orange for sentencing
                end
            else
                color = Color(150, 150, 150, 100) -- Gray for non-restrained
            end
        end

        -- Draw simple crosshair
        local size = 8
        surface.SetDrawColor(color)
        surface.DrawLine(x - size, y, x + size, y)
        surface.DrawLine(x, y - size, x, y + size)

        return true
    end
end
