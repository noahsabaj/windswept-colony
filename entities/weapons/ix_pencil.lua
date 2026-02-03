--[[
    Pencil SWEP

    Simple held weapon for writing on paper with pencil.
    Does not attack - writing is done through item menu.
    Displays lead level HUD.
]]--

AddCSLuaFile()

SWEP.PrintName = "Pencil"
SWEP.Author = "Windswept"
SWEP.Instructions = "Use paper items in your inventory to write."
SWEP.Purpose = "Writing tool."

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
SWEP.WorldModel = "models/props_lab/bindergreen.mdl"  -- Placeholder
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

function SWEP:GetLead()
    local owner = self:GetOwner()
    if not IsValid(owner) then return 0, 500 end

    local item = owner.ixPencilItem
    if not item then return 0, 500 end

    return item:GetLead(), item.maxLead or 500
end

function SWEP:HasEraser()
    local owner = self:GetOwner()
    if not IsValid(owner) then return false end

    local item = owner.ixPencilItem
    if not item then return false end

    return item.hasEraser == true
end

-- ============================================================================
-- CLIENT HUD
-- ============================================================================

if CLIENT then
    function SWEP:DrawHUD()
        -- Don't draw HUD when menu is open
        if vgui.CursorVisible() then return end

        local lead, maxLead = self:GetLead()
        local hasEraser = self:HasEraser()

        local lines = {}
        table.insert(lines, string.format("Lead: %d/%d", lead, maxLead))
        if hasEraser then
            table.insert(lines, "Has Eraser")
        end

        -- Dynamic sizing
        local padding = ScreenScale(5)
        local lineSpacing = ScreenScale(2)

        surface.SetFont("ixSmallFont")

        local maxW = 0
        local totalH = 0
        for i, line in ipairs(lines) do
            local tw, th = surface.GetTextSize(line)
            maxW = math.max(maxW, tw)
            totalH = totalH + th
            if i < #lines then
                totalH = totalH + lineSpacing
            end
        end

        local boxW = maxW + (padding * 2)
        local boxH = totalH + (padding * 2)

        local x = (ScrW() - boxW) / 2
        local y = ScrH() * 0.85

        -- Background
        surface.SetDrawColor(30, 30, 30, 180)
        surface.DrawRect(x, y, boxW, boxH)

        -- Border (gray for pencil)
        surface.SetDrawColor(150, 150, 150, 200)
        surface.DrawOutlinedRect(x, y, boxW, boxH)

        -- Text
        local textY = y + padding
        for i, line in ipairs(lines) do
            local textColor = Color(200, 200, 200)
            if i == 1 and lead == 0 then
                textColor = Color(200, 100, 100)
            elseif i == 2 then
                textColor = Color(255, 150, 180)  -- Pink for eraser
            end

            local _, th = surface.GetTextSize(line)
            draw.SimpleText(line, "ixSmallFont", ScrW() / 2, textY, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            textY = textY + th + lineSpacing
        end
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
        pos = pos + ang:Forward() * 3 + ang:Right() * 1 + ang:Up() * -1
        ang:RotateAroundAxis(ang:Forward(), 90)
        ang:RotateAroundAxis(ang:Right(), -10)

        self:SetRenderOrigin(pos)
        self:SetRenderAngles(ang)
        self:DrawModel()
    end
end
