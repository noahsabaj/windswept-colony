--[[
    Lantern World Entity

    A placed lantern that emits ambient light.
    - E click: Toggle on/off
    - E hold: Pick up (returns to inventory)
    - Drains battery while on (~0.167up/sec)
]]--

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Lantern"
ENT.Category = "Windswept"
ENT.Spawnable = false
ENT.AdminOnly = false

ENT.Model = "models/weapons/cof/w_lantern.mdl"

-- Battery drain rate: 100up / 600 seconds
ENT.DrainRate = 100 / 600

-- Light properties (matching the SWEP/addon)
ENT.LightColor = Color(170, 240, 250)
ENT.LightBrightness = 0.01
ENT.LightSize = 560
ENT.LightStyle = 12

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "LanternOn")
    self:NetworkVar("Float", 0, "BatteryCharge")

    self:SetLanternOn(false)
    self:SetBatteryCharge(0)
end

-- ============================================================================
-- SERVER
-- ============================================================================

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(CONTINUOUS_USE)
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetMass(5)
        end

        self.useStartTime = nil
        self.lastDrain = CurTime()
    end

    function ENT:Use(activator, caller, useType, value)
        if not IsValid(activator) or not activator:IsPlayer() then return end

        -- Track use duration for hold-to-pickup
        if not self.useStartTime then
            self.useStartTime = CurTime()
            self.usePlayer = activator
        end

        -- If same player holding E
        if self.usePlayer == activator then
            local holdTime = CurTime() - self.useStartTime

            -- Hold for 0.5 seconds to pick up (matches Helix itemPickupTime)
            if holdTime >= 0.5 then
                self:PickUp(activator)
                return
            end
        end
    end

    function ENT:Think()
        -- Reset use tracking if player stopped using
        if self.useStartTime then
            local holdTime = CurTime() - self.useStartTime
            -- If they released before 0.5s, it was a click (toggle)
            if holdTime < 0.5 then
                local player = self.usePlayer
                if IsValid(player) then
                    -- Check if they're still pressing use
                    if not player:KeyDown(IN_USE) then
                        self:Toggle(player)
                        self.useStartTime = nil
                        self.usePlayer = nil
                    end
                end
            end
        end

        -- Battery drain
        if self:GetLanternOn() then
            local deltaTime = CurTime() - self.lastDrain
            if deltaTime >= 1 then
                self.lastDrain = CurTime()

                local charge = self:GetBatteryCharge()
                charge = charge - self.DrainRate

                if charge <= 0 then
                    charge = 0
                    self:SetLanternOn(false)
                    self:EmitSound("buttons/lightswitch2.wav", 50, 80)
                end

                self:SetBatteryCharge(charge)
            end
        end

        self:NextThink(CurTime() + 0.1)
        return true
    end

    function ENT:Toggle(activator)
        if self:GetLanternOn() then
            -- Turn off
            self:SetLanternOn(false)
            self:EmitSound("buttons/lightswitch2.wav", 50, 90)
        else
            -- Turn on - check battery
            if self:GetBatteryCharge() <= 0 then
                activator:NotifyLocalized("lanternNoCharge")
                return
            end
            self:SetLanternOn(true)
            self:EmitSound("buttons/lightswitch2.wav", 50, 100)
        end
    end

    function ENT:PickUp(activator)
        local character, inventory = ix.constants.GetCharacterInventory(activator)
        if not character or not inventory then return end

        -- Check if inventory has room
        local canFit = inventory:FindEmptySlot(1, 2)
        if not canFit then
            activator:NotifyLocalized("lanternNoRoom")
            return
        end

        -- Get current state
        local charge = self:GetBatteryCharge()
        local batteries = {}
        if charge > 0 then
            batteries = {charge}
        end

        -- Add item to inventory with battery state
        inventory:Add("lantern", 1, {
            batteries = batteries,
            equipped = true
        })

        -- Give weapon and link item
        timer.Simple(0.1, function()
            if not IsValid(activator) then return end

            local weapon = activator:Give("ix_lantern")
            if IsValid(weapon) then
                -- Find the item we just added
                for _, item in pairs(inventory:GetItems()) do
                    if item.uniqueID == "lantern" and item:GetData("equipped") and not item.linkedToWeapon then
                        item.linkedToWeapon = true
                        weapon.ixItem = item
                        activator.ixLanternItem = item
                        break
                    end
                end

                activator:SelectWeapon("ix_lantern")
            end
        end)

        -- Remove entity
        self:EmitSound("weapons/cof/weapon_get.wav", 60)
        self:Remove()
    end
end

-- ============================================================================
-- CLIENT
-- ============================================================================

if CLIENT then
    function ENT:Think()
        if self:GetLanternOn() then
            local dlight = DynamicLight(self:EntIndex())
            if dlight then
                dlight.Pos = self:GetPos() + Vector(0, 0, 11)
                dlight.r = self.LightColor.r
                dlight.g = self.LightColor.g
                dlight.b = self.LightColor.b
                dlight.Brightness = self.LightBrightness
                dlight.Size = self.LightSize
                dlight.DieTime = CurTime() + 0.5  -- Longer lifespan reduces recreation overhead
                dlight.Style = self.LightStyle
                dlight.nomodel = true
            end
        end

        -- Throttle to 20x/sec instead of every frame (60x/sec)
        self:NextThink(CurTime() + 0.05)
        return true
    end

    function ENT:Draw()
        self:DrawModel()
    end
end
