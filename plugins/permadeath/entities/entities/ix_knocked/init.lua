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
function ENT:CreateRagdoll(model, skin, bodygroups, submaterials)
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

    -- CRITICAL: Prevent Citizen Clothing Overhaul addon from randomizing our ragdoll's clothing
    -- The addon checks this flag before applying random outfits to prop_ragdoll entities
    ragdoll._ClothingHandled = true

    -- Copy SubMaterials (clothing system)
    if submaterials then
        for i, mat in pairs(submaterials) do
            ragdoll:SetSubMaterial(i, mat)
        end
    end

    -- Link ragdoll to this entity (server-side)
    ragdoll.ixKnockedEntity = self
    self.ixRagdoll = ragdoll

    -- Store reference for closure
    local knockedEntity = self

    -- Delay SetNetVar by one frame to ensure both entities are fully networked
    -- This prevents race condition where client receives ragdoll before NetVar propagates
    timer.Simple(0, function()
        -- Validate both entities still exist
        if not IsValid(ragdoll) or not IsValid(knockedEntity) then
            -- Clean up orphaned ragdoll if ix_knocked was removed
            if IsValid(ragdoll) and not IsValid(knockedEntity) then
                ragdoll:Remove()
            end
            return
        end

        -- Network the link to clients using Helix's SetNetVar
        ragdoll:SetNetVar("ixKnockedEntity", knockedEntity)
    end)

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

-- ============================================================================
-- CREMATION SYSTEM
-- ============================================================================

-- Check if ragdoll is on fire (supports both vFire and GMod native)
function ENT:IsRagdollOnFire()
    local ragdoll = self.ixRagdoll
    if not IsValid(ragdoll) then return false end

    -- Check vFire (ragdoll.fires table)
    if ragdoll.fires and next(ragdoll.fires) then
        return true
    end

    -- Fallback to GMod native
    return ragdoll:IsOnFire()
end

-- Check if inside cremation oven (future feature)
function ENT:IsInCremationOven()
    -- TODO: Implement cremation oven proximity detection
    return false
end

-- Get cremation duration based on location
function ENT:GetCremationDuration()
    return self:IsInCremationOven() and 60 or 240
end

-- Handle cremation progress tracking
function ENT:HandleCremation()
    local curTime = CurTime()

    -- Initialize burn tracking
    if not self.ixBurnStartTime then
        self.ixBurnStartTime = curTime
    end

    -- Calculate burn progress
    local burnProgress = self:GetBurnProgress() + (curTime - (self.ixLastBurnThink or curTime))
    self.ixLastBurnThink = curTime

    -- Update networked progress (for client-side darkening)
    self:SetBurnProgress(burnProgress)

    -- Play burning sounds periodically
    if not self.ixNextBurnSound or curTime >= self.ixNextBurnSound then
        local ragdoll = self.ixRagdoll
        if IsValid(ragdoll) then
            sound.Play("ambient/fire/mtov_flame2.wav", ragdoll:GetPos(), 60, math.random(90, 110), 0.7)
        end
        self.ixNextBurnSound = curTime + math.random(4, 6)
    end

    -- Check if cremation complete
    if burnProgress >= self:GetCremationDuration() then
        self:CompleteCremation()
    end
end

-- Handle cremation completion
function ENT:CompleteCremation()
    local charName = self:GetCharacterName() or "Unknown"
    local pos = IsValid(self.ixRagdoll) and self.ixRagdoll:GetPos() or self:GetPos()

    -- Log cremation
    ix.log.Add(nil, "cremation", charName)

    -- Destroy inventory (items burn with body)
    local invID = self:GetInventoryID()
    if invID and invID > 0 then
        -- Remove from memory
        ix.item.inventories[invID] = nil

        -- Delete items from database
        local itemQuery = mysql:Delete("ix_items")
            itemQuery:Where("inventory_id", invID)
        itemQuery:Execute()

        -- Delete inventory from database
        local invQuery = mysql:Delete("ix_inventories")
            invQuery:Where("inventory_id", invID)
        invQuery:Execute()
    end

    -- Mark inventory as already cleaned so OnRemove doesn't try again
    self:SetInventoryID(0)

    -- Spawn Human Remains item
    ix.item.Spawn("human_remains", pos, function(item, entity)
        if item then
            -- Store original character name as data (but not displayed - fog of war)
            item:SetData("originalCharacter", charName)
        end
    end)

    -- Remove this entity (OnRemove handles ragdoll cleanup)
    self:Remove()
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

-- Override SetPermadead to track when body became permadead (for decay timer)
function ENT:SetPermadead(value)
    self.dt.Permadead = value
    if value then
        self.ixPermadeadTime = CurTime()
    end
end

-- ============================================================================
-- TIMER MANAGEMENT
-- ============================================================================

function ENT:Think()
    -- Dead bodies persist indefinitely until players dispose of them
    -- (burial, cremation, disposal, etc.)
    if self:GetPermadead() then
        -- Check for cremation (burning)
        if self:IsRagdollOnFire() then
            self:HandleCremation()
        else
            -- Fire stopped - clear burn tracking so resuming doesn't count gap time
            self.ixLastBurnThink = nil
        end
        self:NextThink(CurTime() + 0.5)
        return true
    end

    -- Check for cremation on knocked (alive but unconscious) bodies
    if self:IsRagdollOnFire() then
        self:HandleCremation()
        -- Fire also halves knockout timer periodically
        if not self.ixLastFireDamage or CurTime() - self.ixLastFireDamage >= 2 then
            self:HalveTimer()
            self.ixLastFireDamage = CurTime()
        end
    else
        -- Fire stopped - clear burn tracking so resuming doesn't count gap time
        self.ixLastBurnThink = nil
    end

    -- Check knockout timer expiration (for knocked but not dead bodies)
    local remaining = self:GetRemainingTime()
    if remaining <= 0 then
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
    local plugin = ix.plugin.Get("permadeath")
    if not plugin then return end

    -- Determine if headshot via damage position relative to ragdoll head bone
    local isHeadshot = false
    local damagePos = dmgInfo:GetDamagePosition()

    if damagePos and damagePos ~= Vector(0, 0, 0) and IsValid(self.ixRagdoll) then
        -- Get the actual head bone position from the ragdoll
        local headBone = self.ixRagdoll:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then
            local headPos = self.ixRagdoll:GetBonePosition(headBone)
            if headPos then
                local distToHead = damagePos:Distance(headPos)
                -- Consider it a headshot if damage is within 12 units of head bone
                isHeadshot = distToHead < 12
            end
        end
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

    -- Block Use for 2 seconds after revival attempt to prevent CPR from triggering loot
    if self.ixLastReviveAttempt and CurTime() - self.ixLastReviveAttempt < 2 then
        return
    end

    -- Also block if this player has an active DoStaredAction
    if activator:GetAction() and activator:GetAction() ~= "" then
        return
    end

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

    -- Loot option (not available when on fire)
    if not self:IsRagdollOnFire() then
        options[L("searchBody")] = function()
            self:OpenInventory(client)
        end
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
    -- Cannot search a body that is on fire
    if self:IsRagdollOnFire() then
        client:NotifyLocalized("bodyOnFire")
        return
    end

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

    -- Clean up inventory when permadead body is removed (not when revived)
    if self:GetPermadead() then
        local invID = self:GetInventoryID()
        if invID and invID > 0 then
            -- Remove from memory
            ix.item.inventories[invID] = nil

            -- Delete items from database
            local itemQuery = mysql:Delete("ix_items")
                itemQuery:Where("inventory_id", invID)
            itemQuery:Execute()

            -- Delete inventory from database
            local invQuery = mysql:Delete("ix_inventories")
                invQuery:Where("inventory_id", invID)
            invQuery:Execute()
        end
    end
end
