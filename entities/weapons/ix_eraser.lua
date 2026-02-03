--[[
    Eraser SWEP

    Simple held weapon for erasing pencil writing from papers.
    Does not attack - erasing is done through item menu.
    Displays durability HUD.
]]--

AddCSLuaFile()

SWEP.PrintName = "Eraser"
SWEP.Author = "Windswept"
SWEP.Instructions = "Use paper items in your inventory to erase pencil writing."
SWEP.Purpose = "Erasing tool."

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

SWEP.ViewModel = ""
SWEP.WorldModel = "models/props_lab/box01a.mdl"  -- Placeholder (small box)
SWEP.UseHands = false
SWEP.HoldType = "normal"
SWEP.Drop = false

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    -- No attack action
end

function SWEP:SecondaryAttack()
    -- No attack action
end

function SWEP:Deploy()
    return true
end

function SWEP:Holster()
    return true
end

function SWEP:GetDurability()
    local owner = self:GetOwner()
    if not IsValid(owner) then return 0, 500 end

    local item = owner.ixEraserItem
    if not item then return 0, 500 end

    return item:GetDurability(), item.maxDurability or 500
end

-- ============================================================================
-- CLIENT HUD
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        -- Don't draw HUD when menu is open
        if vgui.CursorVisible() then return end

        local durability, maxDurability = self:GetDurability()
        local text = string.format("Durability: %d/%d", durability, maxDurability)

        -- Dynamic sizing
        local padding = ScreenScale(5)

        surface.SetFont("ixSmallFont")
        local textW, textH = surface.GetTextSize(text)

        local boxW = textW + (padding * 2)
        local boxH = textH + (padding * 2)

        local x = (ScrW() - boxW) / 2
        local y = ScrH() * 0.85

        -- Background
        surface.SetDrawColor(30, 30, 30, 180)
        surface.DrawRect(x, y, boxW, boxH)

        -- Border (pink for eraser)
        surface.SetDrawColor(255, 150, 180, 200)
        surface.DrawOutlinedRect(x, y, boxW, boxH)

        -- Text
        local textColor = durability > 0 and Color(200, 200, 200) or Color(200, 100, 100)
        draw.SimpleText(text, "ixSmallFont", ScrW() / 2, y + padding, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- Worldmodel positioning for third-person
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

        -- Offset to look held properly
        pos = pos + ang:Forward() * 2 + ang:Right() * 0 + ang:Up() * -0.5
        ang:RotateAroundAxis(ang:Forward(), 0)

        self:SetRenderOrigin(pos)
        self:SetRenderAngles(ang)
        self:DrawModel()
    end
end
