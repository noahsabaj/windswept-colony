--[[
    Physical Door Entity - Server

    Handles door logic: opening/closing, locking/unlocking, damage, destruction.
]]--

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self:GetTypeConfig().model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)  -- Static until opened
    end

    -- Animation state
    self.isAnimating = false
    self.animStartTime = 0
    self.animDuration = 0.5  -- Half second to open/close
    self.startAngles = self:GetAngles()
    self.targetAngles = self:GetAngles()
    self.closedAngles = self:GetAngles()
    self.openAngles = self:GetAngles() + Angle(0, 90, 0)  -- 90 degree swing
end

function ENT:SpawnFunction(ply, tr)
    -- Don't allow manual spawning
    return nil
end

-- ============================================================================
-- USE (E key)
-- ============================================================================

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    -- Can't use while animating
    if self.isAnimating then return end

    -- Check if locked
    if self:GetLocked() then
        activator:NotifyLocalized("doorIsLocked")
        self:EmitSound("doors/door_locked2.wav", 60)
        return
    end

    -- Toggle open/closed
    if self:GetOpen() then
        self:Close()
    else
        self:Open()
    end
end

-- ============================================================================
-- OPEN/CLOSE
-- ============================================================================

function ENT:Open()
    if self:GetOpen() then return end
    if self.isAnimating then return end

    self:SetOpen(true)
    self:StartAnimation(self.openAngles)
    self:EmitSound("doors/door1_move.wav", 60)
end

function ENT:Close()
    if not self:GetOpen() then return end
    if self.isAnimating then return end

    self:SetOpen(false)
    self:StartAnimation(self.closedAngles)
    self:EmitSound("doors/door1_move.wav", 60)

    -- Play close sound at end
    timer.Simple(self.animDuration, function()
        if IsValid(self) then
            self:EmitSound("doors/door1_stop.wav", 60)
        end
    end)
end

function ENT:StartAnimation(targetAng)
    self.isAnimating = true
    self.animStartTime = CurTime()
    self.startAngles = self:GetAngles()
    self.targetAngles = targetAng
end

-- ============================================================================
-- THINK - Animation
-- ============================================================================

function ENT:Think()
    if self.isAnimating then
        local elapsed = CurTime() - self.animStartTime
        local frac = math.Clamp(elapsed / self.animDuration, 0, 1)

        -- Smooth easing
        frac = frac * frac * (3 - 2 * frac)

        local newAng = LerpAngle(frac, self.startAngles, self.targetAngles)
        self:SetAngles(newAng)

        if frac >= 1 then
            self.isAnimating = false
            self:SetAngles(self.targetAngles)
        end

        self:NextThink(CurTime())
        return true
    end
end

-- ============================================================================
-- DAMAGE
-- ============================================================================

function ENT:OnTakeDamage(dmgInfo)
    local attacker = dmgInfo:GetAttacker()
    local damage = dmgInfo:GetDamage()
    local damageType = dmgInfo:GetDamageType()

    -- Get type config
    local config = self:GetTypeConfig()

    -- Check if fist damage (and if allowed)
    local inflictor = dmgInfo:GetInflictor()
    local isFist = IsValid(inflictor) and inflictor:GetClass() == "ix_hands"

    if isFist then
        if not config.fistDamageable then
            -- Metal doors can't be punched
            if IsValid(attacker) and attacker:IsPlayer() then
                attacker:NotifyLocalized("doorCantPunch")
            end
            self:EmitSound("physics/metal/metal_solid_impact_hard1.wav", 50)
            return
        end
        damage = 1  -- 1 HP per punch
    end

    -- Check if battering ram
    local isBatteringRam = IsValid(inflictor) and inflictor:GetClass() == "ix_batteringram"
    if isBatteringRam then
        damage = damage * config.ramResistance
    end

    -- Apply damage
    local health = self:GetHealth()
    health = health - damage
    self:SetHealth(math.max(0, health))

    -- Damage sound
    if config.material == "wood" then
        self:EmitSound("physics/wood/wood_plank_impact_hard" .. math.random(1, 4) .. ".wav", 60)
    else
        self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 60)
    end

    -- Check for destruction
    if health <= 0 then
        self:OnDestroyed(attacker)
    end
end

function ENT:OnDestroyed(attacker)
    -- Play destruction sound
    local config = self:GetTypeConfig()
    if config.material == "wood" then
        self:EmitSound("physics/wood/wood_crate_break" .. math.random(1, 5) .. ".wav", 80)
    else
        self:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 80)
    end

    -- Spawn debris effect (optional)
    local effectData = EffectData()
    effectData:SetOrigin(self:GetPos())
    effectData:SetScale(1)
    util.Effect("propspawn", effectData)

    -- Clear frame reference
    local frameID = self:GetFrameID()
    if frameID and frameID ~= "" then
        if ix.doors and ix.doors.frames and ix.doors.frames[frameID] then
            ix.doors.frames[frameID].hasDoor = false
            ix.doors.frames[frameID].doorEntity = nil
        end
    end

    -- Remove door
    self:Remove()

    -- Save persistence
    if ix.doors and ix.doors.Save then
        ix.doors.Save()
    end
end

-- ============================================================================
-- LOCK MANAGEMENT
-- ============================================================================

function ENT:Lock()
    if not self:HasLock() then return false end
    if self:GetOpen() then return false end  -- Can't lock open door

    self:SetLocked(true)
    return true
end

function ENT:Unlock()
    if not self:HasLock() then return false end

    self:SetLocked(false)
    return true
end

function ENT:DamageLock(amount)
    local lockData = self:GetLockData()
    if not lockData then return end

    lockData.durability = (lockData.durability or 100) - amount
    self:SetLockData(lockData)

    if lockData.durability <= 0 then
        -- Lock broken
        self:SetLocked(false)
        self:EmitSound("physics/metal/metal_box_break1.wav", 70)
        return true  -- Lock destroyed
    end

    return false
end

-- ============================================================================
-- PERSISTENCE HELPERS
-- ============================================================================

function ENT:GetPersistenceData()
    return {
        doorType = self:GetDoorType(),
        health = self:GetHealth(),
        maxHealth = self:GetMaxHealth(),
        locked = self:GetLocked(),
        open = self:GetOpen(),
        lockData = self:GetLockData(),
        pos = self:GetPos(),
        ang = self.closedAngles  -- Always save closed angles
    }
end

function ENT:LoadPersistenceData(data)
    if data.doorType then
        self:SetDoorType(data.doorType)
        local config = self:GetTypeConfig()
        self:SetModel(config.model)
    end

    if data.health then
        self:SetHealth(data.health)
    end

    if data.maxHealth then
        self:SetMaxHealth(data.maxHealth)
    end

    if data.locked ~= nil then
        self:SetLocked(data.locked)
    end

    if data.lockData then
        self:SetLockData(data.lockData)
    end

    -- Always start closed on load
    self:SetOpen(false)
end
