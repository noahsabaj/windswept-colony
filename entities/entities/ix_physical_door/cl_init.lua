--[[
    Physical Door Entity - Client

    Handles visual feedback: damage states, lock display, pulsating hints.
]]--

include("shared.lua")

-- Damage overlay materials (would need custom textures)
-- For now we'll use color tinting

function ENT:Draw()
    self:DrawModel()

    -- Draw lock model if has lock
    if self:HasLock() then
        self:DrawLockModel()
    end

    -- Draw damage overlay
    self:DrawDamageOverlay()
end

-- Cache lock model for rendering
local lockModel = "models/props_c17/tools_pliers01a.mdl"  -- Placeholder for padlock

function ENT:DrawLockModel()
    if not self.lockCSModel then
        self.lockCSModel = ClientsideModel(lockModel, RENDERGROUP_OPAQUE)
        self.lockCSModel:SetNoDraw(true)
    end

    if not IsValid(self.lockCSModel) then return end

    -- Position the lock on the door (handle area)
    local doorPos = self:GetPos()
    local doorAng = self:GetAngles()

    -- Offset to door handle position (adjust based on door model)
    local lockPos = doorPos + doorAng:Forward() * 2 + doorAng:Right() * -35 + doorAng:Up() * 40
    local lockAng = Angle(doorAng.p, doorAng.y + 90, doorAng.r)

    -- Apply lock state visual (locked = slightly different angle)
    if self:GetLocked() then
        lockAng:RotateAroundAxis(lockAng:Up(), 10)
    end

    self.lockCSModel:SetPos(lockPos)
    self.lockCSModel:SetAngles(lockAng)
    self.lockCSModel:SetModelScale(0.8)

    -- Color based on durability
    local lockData = self:GetLockData()
    local durability = lockData and lockData.durability or 100

    if durability < 25 then
        self.lockCSModel:SetColor(Color(200, 100, 100))  -- Red tint for damaged
    elseif durability < 50 then
        self.lockCSModel:SetColor(Color(200, 180, 100))  -- Yellow tint
    else
        self.lockCSModel:SetColor(Color(180, 180, 180))  -- Normal metal color
    end

    self.lockCSModel:DrawModel()
end

function ENT:OnRemove()
    if IsValid(self.lockCSModel) then
        self.lockCSModel:Remove()
    end
end

function ENT:DrawDamageOverlay()
    local condition = self:GetCondition()

    -- Tint door based on damage
    if condition == "minor" then
        -- Slight darkening
        render.SetColorModulation(0.9, 0.9, 0.85)
    elseif condition == "moderate" then
        -- More noticeable damage
        render.SetColorModulation(0.75, 0.7, 0.65)
    elseif condition == "severe" then
        -- Heavy damage
        render.SetColorModulation(0.6, 0.5, 0.45)
    else
        -- Intact - normal
        render.SetColorModulation(1, 1, 1)
    end
end

-- ============================================================================
-- 3D2D Door Info
-- ============================================================================

local DOOR_INFO_DISTANCE = 256

function ENT:DrawTranslucent()
    local ply = LocalPlayer()
    local dist = ply:GetPos():DistToSqr(self:GetPos())

    if dist > DOOR_INFO_DISTANCE * DOOR_INFO_DISTANCE then return end

    -- Calculate alpha based on distance
    local alpha = 1 - (math.sqrt(dist) / DOOR_INFO_DISTANCE)
    alpha = math.Clamp(alpha, 0, 1) * 255

    -- Draw info above door
    local pos = self:GetPos() + Vector(0, 0, 80)
    local ang = (ply:GetPos() - pos):Angle()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.1)
        self:Draw3D2DInfo(alpha)
    cam.End3D2D()
end

function ENT:Draw3D2DInfo(alpha)
    local locked = self:GetLocked()
    local hasLock = self:HasLock()
    local health = self:GetHealth()
    local maxHealth = self:GetMaxHealth()

    -- Background
    surface.SetDrawColor(30, 30, 30, alpha * 0.8)
    surface.DrawRect(-100, -30, 200, 60)

    -- Lock status
    local lockText, lockColor
    if not hasLock then
        lockText = "No Lock"
        lockColor = Color(150, 150, 150, alpha)
    elseif locked then
        lockText = "Locked"
        lockColor = Color(200, 50, 50, alpha)
    else
        lockText = "Unlocked"
        lockColor = Color(50, 200, 50, alpha)
    end

    draw.SimpleText(lockText, "ixMediumFont", 0, -15, lockColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Health bar
    local healthPercent = maxHealth > 0 and (health / maxHealth) or 0
    local barW, barH = 160, 12
    local barX, barY = -80, 5

    surface.SetDrawColor(50, 50, 50, alpha)
    surface.DrawRect(barX, barY, barW, barH)

    local healthColor = Color(50, 200, 50, alpha)
    if healthPercent < 0.5 then
        healthColor = Color(200, 200, 50, alpha)
    end
    if healthPercent < 0.25 then
        healthColor = Color(200, 50, 50, alpha)
    end

    surface.SetDrawColor(healthColor)
    surface.DrawRect(barX + 2, barY + 2, (barW - 4) * healthPercent, barH - 4)
end

-- ============================================================================
-- Pulsating Hints for Players with Equipment
-- ============================================================================

local PULSE_DISTANCE = 192

hook.Add("PostDrawTranslucentRenderables", "ixPhysicalDoorPulse", function()
    local ply = LocalPlayer()
    local weapon = ply:GetActiveWeapon()

    if not IsValid(weapon) then return end

    local weaponClass = weapon:GetClass()

    -- Only show pulse for toolkit (for lock removal)
    if weaponClass ~= "ix_toolkit" then return end

    -- Find nearby doors
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), PULSE_DISTANCE)) do
        if ent:GetClass() == "ix_physical_door" then
            -- Draw pulsating effect around lock position
            if ent:HasLock() and not ent:GetLocked() then
                -- Lock is removable (unlocked)
                local lockPos = ent:GetPos() + Vector(0, 0, 40)  -- Approximate lock height
                local pulse = math.sin(CurTime() * 4) * 0.5 + 0.5

                render.SetColorMaterial()
                render.DrawSphere(lockPos, 8 + pulse * 4, 16, 16, Color(100, 200, 100, 100 * pulse))
            end
        end
    end
end)
