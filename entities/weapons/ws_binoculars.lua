--[[
    Binoculars SWEP

    Used to see far distances.
    - RMB to zoom in/out
    - LMB to cycle zoom levels (2x to 8x)
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Binoculars"
SWEP.Purpose = "See far distances."
SWEP.Instructions = "RMB to zoom. LMB to cycle zoom levels."

SWEP.ViewModel = Model("models/weapons/c_binoculars.mdl")
SWEP.WorldModel = Model("models/weapons/w_binocularsbp.mdl")
SWEP.HoldType = "slam"
SWEP.HoldTypeZoomed = "camera"
SWEP.DrawCrosshair = false

-- Zoom settings
SWEP.ZoomLevels = {2, 4, 6, 8}
SWEP.ZoomTransitionTime = 0.2

-- Sounds
SWEP.ZoomInSound = "weapons/sniper/sniper_zoomin.wav"
SWEP.ZoomOutSound = "weapons/sniper/sniper_zoomout.wav"
SWEP.ClothSound = "foley/alyx_hug_eli.wav"

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Zoomed")
    self:NetworkVar("Int", 0, "ZoomLevel")
end

function SWEP:Initialize()
    self.BaseClass.Initialize(self)
    self:SetZoomed(false)
    self:SetZoomLevel(1)
end

function SWEP:Deploy()
    self.BaseClass.Deploy(self)
    self:SetZoomed(false)
    self:SetZoomLevel(1)

    local owner = self:GetOwner()
    if IsValid(owner) then
        owner:SetFOV(0, 0)
        owner:DrawViewModel(true, 0)
    end

    return true
end

function SWEP:Holster()
    -- Can't holster while transitioning
    if self.isTransitioning then return false end

    local owner = self:GetOwner()
    if IsValid(owner) then
        owner:SetFOV(0, 0)
        owner:DrawViewModel(true, 0)
    end

    self:SetZoomed(false)
    self:SetZoomLevel(1)

    return true
end

-- Reset the zoom FOV/viewmodel if the weapon is removed while zoomed (death,
-- StripWeapon, disconnect/respawn). Holster handles the clean path, but those
-- bypass Holster and would otherwise leave the player stuck at a narrow FOV.
function SWEP:OnRemove()
    local owner = self:GetOwner()
    if IsValid(owner) then
        owner:SetFOV(0, 0)
        owner:DrawViewModel(true, 0)
    end
end

-- ============================================================================
-- ZOOM MECHANICS
-- ============================================================================

function SWEP:PrimaryAttack()
    if not self:GetZoomed() then return end
    if self.isTransitioning then return end

    self:SetNextPrimaryFire(CurTime() + 0.3)

    -- Cycle through zoom levels
    local currentLevel = self:GetZoomLevel()
    local nextLevel = currentLevel + 1

    if nextLevel > #self.ZoomLevels then
        nextLevel = 1
    end

    self:SetZoomLevel(nextLevel)

    local owner = self:GetOwner()
    if IsValid(owner) then
        local fov = 90 / self.ZoomLevels[nextLevel]
        owner:SetFOV(fov, self.ZoomTransitionTime)

        if nextLevel == 1 then
            self:EmitSound(self.ZoomOutSound, 60)
        else
            self:EmitSound(self.ZoomInSound, 60)
        end
    end
end

function SWEP:SecondaryAttack()
    if self.isTransitioning then return end

    self:SetNextSecondaryFire(CurTime() + 0.5)

    if self:GetZoomed() then
        self:EndZoom()
    else
        self:StartZoom()
    end
end

function SWEP:StartZoom()
    self.isTransitioning = true

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:EmitSound(self.ClothSound, 50, 110)
    self:SetHoldType(self.HoldTypeZoomed)

    local owner = self:GetOwner()
    local seqDuration = self:SequenceDuration()

    timer.Simple(seqDuration * 0.8, function()
        if not IsValid(self) or not IsValid(owner) then return end

        self:SetZoomed(true)
        self:SetZoomLevel(1)

        owner:DrawViewModel(false, 0)
        owner:SetFOV(90 / self.ZoomLevels[1], self.ZoomTransitionTime)
    end)

    timer.Simple(seqDuration, function()
        if not IsValid(self) then return end
        self.isTransitioning = false
    end)
end

function SWEP:EndZoom()
    self.isTransitioning = true

    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    self:EmitSound(self.ClothSound, 50, 90)
    self:SetHoldType(self.HoldType)

    local owner = self:GetOwner()
    local seqDuration = self:SequenceDuration()

    timer.Simple(seqDuration * 0.2, function()
        if not IsValid(self) or not IsValid(owner) then return end

        self:SetZoomed(false)
        self:SetZoomLevel(1)

        owner:DrawViewModel(true, 0)
        owner:SetFOV(0, self.ZoomTransitionTime)
    end)

    timer.Simple(seqDuration, function()
        if not IsValid(self) then return end
        self.isTransitioning = false
    end)
end

-- ============================================================================
-- CLIENT HUD
-- ============================================================================

if CLIENT then
    -- Create font for HUD text
    surface.CreateFont("wsBinocularsHUD", {
        font = "TargetID",
        size = 32,
        weight = 600,
        antialias = true,
    })

    -- Binocular overlay material (figure-8 shape with black borders)
    local overlayMaterial = Material("vgui/hud/rpw_binoculars_overlay")

    function SWEP:DrawHUD()
        if not self:GetZoomed() then return end

        local w = ScrW()
        local h = ScrH()

        -- Draw binocular overlay (figure-8 shape)
        surface.SetMaterial(overlayMaterial)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, -(w - h) / 2, w, w)

        -- Calculate range to target
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local tr = owner:GetEyeTrace()
        local range

        if tr.HitSky then
            range = "-"
        else
            local distance = tr.StartPos:Distance(tr.HitPos) * 0.024 -- Convert to meters
            range = string.format("%.1fm", distance)
        end

        -- Draw range on left side
        surface.SetFont("wsBinocularsHUD")
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(w * 0.165, h / 2 + 16)
        surface.DrawText("Range: " .. range)

        -- Draw zoom on right side
        local zoomLevel = self:GetZoomLevel()
        local zoomMult = self.ZoomLevels[zoomLevel] or 2

        surface.SetTextPos(w * 0.775, h / 2 + 16)
        surface.DrawText("Zoom: " .. zoomMult .. "x")
    end

    -- Adjust mouse sensitivity when zoomed (less sensitive at higher zoom)
    function SWEP:AdjustMouseSensitivity()
        if self:GetZoomed() then
            local zoomLevel = self:GetZoomLevel()
            local zoomMult = self.ZoomLevels[zoomLevel] or 2
            return 1 / zoomMult
        end
    end

    -- Hide crosshair
    function SWEP:DoDrawCrosshair(x, y)
        return true
    end
end
