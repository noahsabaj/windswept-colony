--[[
    ix_knocked Entity - Server

    Handles timer management, damage (execution),
    revival triggering, and inventory looting.
]]--

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/watermelon01.mdl")  -- Placeholder, will be overridden by player model
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    local physObj = self:GetPhysicsObject()
    if IsValid(physObj) then
        physObj:EnableMotion(true)
        physObj:Wake()
        physObj:SetMass(80)  -- Human-ish mass
    end

    -- Initialize state
    self:SetPermadead(false)
    self:SetCurrentReviver(NULL)
end

-- Set the player model (call after spawn)
function ENT:SetKnockedModel(model)
    self:SetModel(model)

    -- Reinitialize physics with new model
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    local physObj = self:GetPhysicsObject()
    if IsValid(physObj) then
        physObj:EnableMotion(true)
        physObj:Wake()
        physObj:SetMass(80)
    end

    -- Store for networking
    self:SetNetVar("knockedModel", model)
end

-- Set the player skin (NetworkVar auto-generates SetKnockedSkin but we need to apply it)
function ENT:SetKnockedSkin(skin)
    self:SetSkin(skin)
    -- Also store in NetworkVar for persistence
    self.dt.KnockedSkin = skin
end

-- ============================================================================
-- TIMER MANAGEMENT
-- ============================================================================

function ENT:Think()
    -- Skip if permadead
    if self:GetPermadead() then
        self:NextThink(CurTime() + 1)
        return true
    end

    -- Check timer expiration
    if self:GetRemainingTime() <= 0 then
        local plugin = ix.plugin.Get("permadeath")
        if plugin then
            plugin:OnKnockoutExpired(self)
        end
    end

    self:NextThink(CurTime() + 0.5)
    return true
end

-- Halve the remaining timer (from damage)
function ENT:HalveTimer()
    if self:GetPermadead() then return end

    local remaining = self:GetRemainingTime()
    local newDuration = remaining / 2

    self:SetTimerStart(CurTime())
    self:SetTimerDuration(newDuration)

    -- Sync to knocked player
    local owner = self:GetOwningPlayer()
    if IsValid(owner) then
        net.Start("ixKnockoutTimerSync")
            net.WriteFloat(newDuration)
        net.Send(owner)
    end
end

-- ============================================================================
-- DAMAGE HANDLING (EXECUTION)
-- ============================================================================

function ENT:OnTakeDamage(dmgInfo)
    if self:GetPermadead() then return end

    local attacker = dmgInfo:GetAttacker()
    local hitGroup = dmgInfo:GetHitGroup()
    local isHeadshot = (hitGroup == HITGROUP_HEAD)

    local plugin = ix.plugin.Get("permadeath")
    if not plugin then return end

    if isHeadshot then
        -- 50% instant execution, 50% halve timer
        if math.random() < 0.5 then
            -- Execution
            local charID = self:GetCharacterID()
            local character = ix.char.loaded[charID]

            if character then
                local owner = self:GetOwningPlayer()
                if IsValid(owner) then
                    plugin:ApplyPermadeath(owner, character, "executed_headshot")
                else
                    -- Offline execution
                    character:SetData("permadead", true)
                    character:SetData("permaDeathReason", "executed_headshot_offline")
                    character:SetData("permaDeathTime", os.time())
                    character:SetData("knocked", nil)
                    character:SetData("knockoutExpires", nil)
                    self:SetPermadead(true)
                end
            else
                self:SetPermadead(true)
            end
        else
            -- Survived headshot - halve timer
            self:HalveTimer()
        end
    else
        -- Body shot - halve timer
        self:HalveTimer()
    end
end

-- ============================================================================
-- USE / REVIVAL
-- ============================================================================

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    -- Trigger revival attempt through plugin
    local plugin = ix.plugin.Get("permadeath")
    if plugin then
        plugin:AttemptRevival(activator, self)
    end
end

-- ============================================================================
-- ENTITY MENU (Right-click options)
-- ============================================================================

function ENT:GetEntityMenu(client)
    local options = {}

    if not self:GetPermadead() then
        -- Revive option
        options[L("attemptRevival")] = function()
            local plugin = ix.plugin.Get("permadeath")
            if plugin then
                plugin:AttemptRevival(client, self)
            end
        end
    end

    -- Loot option (always available)
    options[L("searchBody")] = function()
        self:OpenInventory(client)
    end

    return options
end

-- ============================================================================
-- INVENTORY / LOOTING
-- ============================================================================

function ENT:OpenInventory(client)
    local invID = self:GetInventoryID()
    if not invID or invID == 0 then
        client:NotifyLocalized("noInventory")
        return
    end

    local inventory = ix.item.inventories[invID]
    if not inventory then
        client:NotifyLocalized("noInventory")
        return
    end

    -- Get character name for display
    local charID = self:GetCharacterID()
    local character = ix.char.loaded[charID]
    local name = character and character:GetName() or "Unknown"

    -- Use Helix storage system
    ix.storage.Open(client, inventory, {
        name = name .. "'s Body",
        entity = self,
        searchTime = 1,
        bMultipleUsers = true
    })
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

function ENT:OnRemove()
    -- Clear any revival in progress
    local reviver = self:GetCurrentReviver()
    if IsValid(reviver) then
        reviver:SetAction()
    end

    -- Clear reference from owner
    local owner = self:GetOwningPlayer()
    if IsValid(owner) then
        owner.ixKnockedEntity = nil
    end
end
