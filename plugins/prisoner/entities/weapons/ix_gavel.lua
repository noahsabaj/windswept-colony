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

-- Check if owner is a judge
function SWEP:IsOwnerJudge()
    local owner = self:GetOwner()
    if not IsValid(owner) then return false end

    local character = owner:GetCharacter()
    if not character then return false end

    local class = character:GetClass()
    return class == CLASS_JUDGE
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

-- Secondary attack: Context-sensitive sentencing/management (judge only)
function SWEP:SecondaryAttack()
    if CLIENT then return end

    -- Only judges can sentence/manage prisoners
    if not self:IsOwnerJudge() then
        self:GetOwner():NotifyLocalized("judgeOnly")
        return
    end

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
