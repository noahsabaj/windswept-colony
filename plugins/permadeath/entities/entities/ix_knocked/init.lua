--[[
    ix_knocked Entity - Server

    Handles timer management, damage (execution),
    revival triggering, and inventory looting.
]]--

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    -- This entity is invisible - we use a prop_ragdoll for visuals
    self:SetNoDraw(true)
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(SIMPLE_USE)

    -- Initialize state
    self:SetPermadead(false)
    self:SetCurrentReviver(NULL)
end

-- Create the ragdoll visual for this knocked entity
function ENT:CreateRagdoll(model, skin, bodygroups)
    -- Remove existing ragdoll if any
    if IsValid(self.ixRagdoll) then
        self.ixRagdoll:Remove()
    end

    -- Create prop_ragdoll for proper ragdoll physics
    local ragdoll = ents.Create("prop_ragdoll")
    ragdoll:SetPos(self:GetPos())
    ragdoll:SetAngles(self:GetAngles())
    ragdoll:SetModel(model)
    ragdoll:SetSkin(skin or 0)

    -- Copy bodygroups
    if bodygroups then
        for i, v in pairs(bodygroups) do
            ragdoll:SetBodygroup(i, v)
        end
    end

    ragdoll:Spawn()
    ragdoll:Activate()
    ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    -- Link ragdoll to this entity (server-side)
    ragdoll.ixKnockedEntity = self
    self.ixRagdoll = ragdoll

    -- Network the link to clients using Helix's SetNetVar
    ragdoll:SetNetVar("ixKnockedEntity", self)

    -- Make ragdoll useable and forward Use to our entity
    ragdoll:SetUseType(SIMPLE_USE)
    ragdoll.Use = function(rag, activator, caller)
        if IsValid(self) then
            self:Use(activator, caller)
        end
    end

    -- Forward GetEntityMenu to our entity for right-click menu
    ragdoll.GetEntityMenu = function(rag, client)
        if IsValid(self) then
            return self:GetEntityMenu(client)
        end
        return {}
    end

    -- Keep our entity position synced with ragdoll
    self:SetPos(ragdoll:GetPos())

    return ragdoll
end

-- Set the player model and create the ragdoll
-- Note: NetworkVar "KnockedModel" (String) handles networking via SetupDataTables
function ENT:SetKnockedModel(model)
    -- Store in NetworkVar for client access
    self.dt.KnockedModel = model
end

-- Set the player skin
-- Note: NetworkVar "KnockedSkin" (Int) handles networking via SetupDataTables
function ENT:SetKnockedSkin(skin)
    self:SetSkin(skin)
    -- Store in NetworkVar for client access (auto-generated setter from SetupDataTables)
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
    local remaining = self:GetRemainingTime()
    if remaining <= 0 then
        print("[Permadeath] Entity timer expired! Remaining: " .. remaining)
        local plugin = ix.plugin.Get("permadeath")
        if plugin then
            print("[Permadeath] Calling OnKnockoutExpired")
            plugin:OnKnockoutExpired(self)
        else
            print("[Permadeath] ERROR: Could not get permadeath plugin!")
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
    local plugin = ix.plugin.Get("permadeath")
    if not plugin then return end

    -- Determine if headshot via damage position relative to head height
    -- Note: dmgInfo:GetHitGroup() doesn't work for entities, only for players
    local isHeadshot = false
    local damagePos = dmgInfo:GetDamagePosition()

    if damagePos and damagePos ~= Vector(0, 0, 0) then
        -- Calculate head position (approximately 60 units above entity origin for standing models)
        local headPos = self:GetPos() + Vector(0, 0, 60)
        local distToHead = damagePos:Distance(headPos)
        -- Consider it a headshot if damage is within 15 units of head position
        isHeadshot = distToHead < 15
    end

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

-- Note: Primary interaction is now handled via net messages (ixKnockoutLoot/ixKnockoutRevive)
-- This Use function is kept as a fallback and for compatibility
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    -- Default Use action is to loot (matches E tap behavior)
    -- Revival requires holding E (handled via client-side detection)
    self:OpenInventory(activator)
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

-- Sound effects for looting (rustling through clothes/gear)
local lootSounds = {
    "npc/combine_soldier/gear1.wav",
    "npc/combine_soldier/gear2.wav",
    "npc/combine_soldier/gear3.wav",
    "npc/combine_soldier/gear4.wav",
    "npc/combine_soldier/gear5.wav",
    "npc/combine_soldier/gear6.wav"
}

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

    -- Play looting sound (rustling through gear)
    local ragdoll = self.ixRagdoll
    local soundPos = IsValid(ragdoll) and ragdoll:GetPos() or self:GetPos()
    sound.Play(lootSounds[math.random(#lootSounds)], soundPos, 60, 100, 0.8)

    -- Get character name for display (stored permanently on entity)
    local name = self:GetCharacterName()
    if not name or name == "" then
        name = "Unknown"
    end

    -- Use Helix storage system
    -- IMPORTANT: Pass the ragdoll as the entity, not self (ix_knocked is invisible)
    -- DoStaredAction traces to check if player is looking at the entity,
    -- so we need to pass the visible ragdoll they're actually looking at
    local stareEntity = IsValid(ragdoll) and ragdoll or self
    ix.storage.Open(client, inventory, {
        name = name .. "'s Body",
        entity = stareEntity,
        searchTime = 1,
        bMultipleUsers = true
    })
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

function ENT:OnRemove()
    -- Remove the ragdoll
    if IsValid(self.ixRagdoll) then
        self.ixRagdoll:Remove()
    end

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

    -- Clean up from plugin tracking table to prevent memory leaks
    if self.ixSteamID64 then
        local plugin = ix.plugin.Get("permadeath")
        if plugin and plugin.knockedEntities then
            plugin.knockedEntities[self.ixSteamID64] = nil
        end
    end
end
