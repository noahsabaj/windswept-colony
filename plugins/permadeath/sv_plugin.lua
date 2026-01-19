--[[
    Permadeath Plugin - Server Logic

    Handles damage interception, knockout state management,
    revival mechanics, and permadeath application.
]]--

print("[Permadeath] sv_plugin.lua is loading...")

-- Store reference to active knockout entities by SteamID64
PLUGIN.knockedEntities = PLUGIN.knockedEntities or {}

-- ============================================================================
-- DAMAGE INTERCEPTION (using Helix PLUGIN: pattern)
-- ============================================================================

-- Track hit groups for headshot detection
-- ScalePlayerDamage is called before DoPlayerDeath and gives us the hit group
function PLUGIN:ScalePlayerDamage(client, hitGroup, dmgInfo)
    client.ixLastHitGroup = hitGroup
end

-- Intercept player death and convert to knockout
-- This uses the Helix hook cache system - functions defined as PLUGIN:HookName
-- are automatically cached and called by hook.Call
function PLUGIN:DoPlayerDeath(client, attacker, dmgInfo)
    print("[Permadeath] DoPlayerDeath hook fired for " .. client:Name())

    local character = client:GetCharacter()
    if not character then
        print("[Permadeath] No character found, skipping")
        return
    end

    print("[Permadeath] Creating knockout for " .. character:GetName())

    -- If player is already knocked out (being executed), let damage go to entity
    if IsValid(client.ixKnockedEntity) then
        return
    end

    -- Check for headshot - 50% chance of instant permadeath
    if self:IsHeadshot(client) then
        local headshotChance = ix.config.Get("permadeathHeadshotChance", 50) / 100
        if math.random() < headshotChance then
            -- Lost the coin flip - instant permadeath
            print("[Permadeath] Headshot execution!")
            self:ApplyPermadeath(client, character, "headshot_execution")
            return true  -- Prevent normal death
        end
        -- Won the coin flip - proceed to normal knockout (no extra penalty)
        print("[Permadeath] Survived headshot coin flip")
    end

    -- Create knockout state instead of death
    self:CreateKnockout(client, character, dmgInfo)

    -- Prevent normal death processing by returning non-nil
    return true
end

-- Block normal respawn for knocked players
function PLUGIN:PlayerDeathThink(client)
    if IsValid(client.ixKnockedEntity) then
        return true  -- Block respawn
    end

    local character = client:GetCharacter()
    if character and character:GetData("permadead") then
        return true  -- Block respawn for permadead characters
    end
end

-- ============================================================================
-- KNOCKOUT CREATION
-- ============================================================================

function PLUGIN:CreateKnockout(client, character, dmgInfo)
    -- Increment knockout count (permanent, never resets)
    local knockoutCount = (character:GetData("knockoutCount") or 0) + 1
    character:SetData("knockoutCount", knockoutCount)

    -- Calculate duration based on knockout history
    local duration = self:GetKnockoutDuration(knockoutCount)

    -- Store knockout state for disconnect handling
    local expireTime = os.time() + math.ceil(duration)
    character:SetData("knockoutExpires", expireTime)
    character:SetData("knocked", true)

    -- Store player position and angles before hiding
    local pos = client:GetPos()
    local ang = client:EyeAngles()
    local model = client:GetModel()
    local skin = client:GetSkin()

    -- Create the ix_knocked entity
    local entity = ents.Create("ix_knocked")
    if not IsValid(entity) then
        ErrorNoHalt("[Permadeath] Failed to create ix_knocked entity!\n")
        return
    end

    entity:SetPos(pos)
    entity:SetAngles(Angle(0, ang.y, 0))
    entity:Spawn()
    entity:Activate()

    -- Configure entity with player data
    entity:SetKnockedModel(model)
    entity:SetKnockedSkin(skin)
    entity:SetOwningPlayer(client)
    entity:SetCharacterID(character:GetID())
    entity:SetTimerStart(CurTime())
    entity:SetTimerDuration(duration)

    -- Copy bodygroups
    for i = 0, client:GetNumBodyGroups() - 1 do
        entity:SetBodygroup(i, client:GetBodygroup(i))
    end

    -- Link to character's inventory for looting
    local inventory = character:GetInventory()
    if inventory then
        entity:SetInventoryID(inventory:GetID())
    end

    -- Store references
    client.ixKnockedEntity = entity
    entity.ixOwner = client
    self.knockedEntities[client:SteamID64()] = entity

    -- Hide and freeze the actual player
    client:StripWeapons()
    client:SetNoDraw(true)
    client:SetNotSolid(true)
    client:Freeze(true)
    client:SetMoveType(MOVETYPE_NONE)
    client:SetPos(entity:GetPos() + Vector(0, 0, 10000))  -- Move player away

    -- Apply muffled audio effect
    client:SetDSP(31)

    -- Notify the client they've been knocked out
    print("[Permadeath] Sending ixKnockoutStart to client, duration: " .. duration .. ", count: " .. knockoutCount)
    net.Start("ixKnockoutStart")
        net.WriteFloat(duration)
        net.WriteUInt(knockoutCount, 8)
    net.Send(client)

    -- Log the knockout
    ix.log.Add(client, "knockout", knockoutCount, self:FormatTime(duration))
end

-- ============================================================================
-- REVIVAL SYSTEM
-- ============================================================================

function PLUGIN:AttemptRevival(reviver, knockedEntity)
    if not IsValid(reviver) or not IsValid(knockedEntity) then
        return false
    end

    -- Check if entity is already permadead
    if knockedEntity:GetPermadead() then
        reviver:NotifyLocalized("knockedAlreadyDead")
        return false
    end

    -- Check if someone else is already reviving
    local currentReviver = knockedEntity:GetCurrentReviver()
    if IsValid(currentReviver) and currentReviver ~= reviver then
        reviver:NotifyLocalized("knockedAlreadyBeingRevived")
        return false
    end

    -- Check for defibrillator
    local hasDefib, defibItem = self:PlayerHasDefibReady(reviver)

    -- Lock the entity to this reviver
    knockedEntity:SetCurrentReviver(reviver)

    -- Random progress duration (3-10 seconds by default)
    local duration = self:GetRevivalDuration()

    -- Start the revival progress
    reviver:SetAction("@reviving", duration)

    -- Use DoStaredAction for progress-based revival (must look at target)
    reviver:DoStaredAction(knockedEntity, function()
        -- Completed - attempt the revival
        self:CompleteRevivalAttempt(reviver, knockedEntity, hasDefib, defibItem)
    end, duration, function()
        -- Cancelled (looked away, moved too far, etc.)
        knockedEntity:SetCurrentReviver(NULL)
        reviver:SetAction()
    end, function()
        -- Progress callback (optional)
    end)

    return true
end

function PLUGIN:CompleteRevivalAttempt(reviver, knockedEntity, hasDefib, defibItem)
    -- Clear the reviver lock
    knockedEntity:SetCurrentReviver(NULL)

    -- Calculate success using probabilistic squared
    local success, actualChance = self:CalculateRevivalChance(hasDefib)

    if success then
        -- Revival succeeded!
        self:RevivePlayer(knockedEntity, reviver, hasDefib, defibItem)
    else
        -- Revival failed - can retry
        reviver:NotifyLocalized("revivalFailed")

        -- If used defib, still consume a charge on failure
        if hasDefib and IsValid(defibItem) then
            self:ConsumeDefibCharge(defibItem, reviver)
        end
    end
end

function PLUGIN:RevivePlayer(knockedEntity, reviver, usedDefib, defibItem)
    local owner = knockedEntity.ixOwner
    local charID = knockedEntity:GetCharacterID()

    -- Find the character
    local character
    if IsValid(owner) then
        character = owner:GetCharacter()
    else
        character = ix.char.loaded[charID]
    end

    if not character then
        ErrorNoHalt("[Permadeath] Cannot revive - character not found!\n")
        return
    end

    -- Random revival health: 1-50 HP
    local revivalHealth = math.random(1, 50)

    -- Clear knockout state
    character:SetData("knocked", nil)
    character:SetData("knockoutExpires", nil)

    -- If player is online, restore them
    if IsValid(owner) then
        -- Move player back to entity position
        owner:SetPos(knockedEntity:GetPos())
        owner:SetEyeAngles(knockedEntity:GetAngles())

        -- Restore player state
        owner:SetNoDraw(false)
        owner:SetNotSolid(false)
        owner:Freeze(false)
        owner:SetMoveType(MOVETYPE_WALK)

        -- Set revival health
        owner:SetHealth(revivalHealth)

        -- Clear muffled audio
        owner:SetDSP(0)

        -- Give hands weapon back
        owner:Give("ix_hands")
        owner:SelectWeapon("ix_hands")

        -- Notify the revived player
        net.Start("ixKnockoutEnd")
            net.WriteBool(true)  -- Revived successfully
            net.WriteUInt(revivalHealth, 8)
        net.Send(owner)

        -- Clear knockout entity reference
        owner.ixKnockedEntity = nil
    end

    -- Consume defib charge if used
    if usedDefib and IsValid(defibItem) then
        self:ConsumeDefibCharge(defibItem, reviver)
    end

    -- Notify reviver
    reviver:NotifyLocalized("revivalSuccess")

    -- Remove the knockout entity
    self.knockedEntities[character:GetData("steamID") or ""] = nil
    knockedEntity:Remove()

    -- Log the revival
    ix.log.Add(reviver, "revival", character:GetName(), revivalHealth)
end

-- ============================================================================
-- PERMADEATH
-- ============================================================================

function PLUGIN:ApplyPermadeath(client, character, reason)
    -- Mark character as permanently dead
    character:SetData("permadead", true)
    character:SetData("permaDeathReason", reason)
    character:SetData("permaDeathTime", os.time())

    -- Clear knockout state
    character:SetData("knocked", nil)
    character:SetData("knockoutExpires", nil)

    -- If there's a knockout entity, mark it as permadead (stays for looting)
    if IsValid(client) and IsValid(client.ixKnockedEntity) then
        client.ixKnockedEntity:SetPermadead(true)
        client.ixKnockedEntity.ixOwner = nil
        client.ixKnockedEntity = nil
    end

    -- Notify client and kick to character menu
    if IsValid(client) then
        net.Start("ixKnockoutEnd")
            net.WriteBool(false)  -- Permadead
            net.WriteUInt(0, 8)
        net.Send(client)

        -- Small delay before kicking to character menu
        timer.Simple(2, function()
            if IsValid(client) then
                client:SetNoDraw(false)
                client:SetNotSolid(false)
                client:Freeze(false)
                client:SetMoveType(MOVETYPE_WALK)
                client:SetDSP(0)
                client:KillSilent()

                -- Kick back to character menu
                character:Kick()
            end
        end)
    end

    -- Log permadeath
    ix.log.Add(client, "permadeath", character:GetName(), reason)
end

-- Called when knockout timer expires
function PLUGIN:OnKnockoutExpired(knockedEntity)
    local charID = knockedEntity:GetCharacterID()
    local character = ix.char.loaded[charID]

    if not character then
        knockedEntity:SetPermadead(true)
        return
    end

    local owner = knockedEntity.ixOwner

    if IsValid(owner) then
        self:ApplyPermadeath(owner, character, "timer_expired")
    else
        -- Player offline - still apply permadeath
        character:SetData("permadead", true)
        character:SetData("permaDeathReason", "timer_expired_offline")
        character:SetData("permaDeathTime", os.time())
        character:SetData("knocked", nil)
        character:SetData("knockoutExpires", nil)

        knockedEntity:SetPermadead(true)
        knockedEntity.ixOwner = nil
    end
end

-- ============================================================================
-- DEFIBRILLATOR HELPERS
-- ============================================================================

function PLUGIN:PlayerHasDefibReady(client)
    -- Check if player has a charged defibrillator equipped/ready
    if client.ixDefibReady and IsValid(client.ixDefibItem) then
        local item = client.ixDefibItem
        if item:GetData("charges", item.maxCharges or 4) > 0 then
            return true, item
        end
    end

    return false, nil
end

function PLUGIN:ConsumeDefibCharge(item, client)
    local charges = item:GetData("charges", item.maxCharges or 4)
    charges = math.max(0, charges - 1)
    item:SetData("charges", charges)

    if charges <= 0 then
        client:NotifyLocalized("defibDepleted")
        client.ixDefibReady = nil
        client.ixDefibItem = nil
    end
end

-- ============================================================================
-- CHARACTER LOADING / DISCONNECT HANDLING
-- ============================================================================

-- Block permadead characters from being used
function PLUGIN:CanPlayerUseCharacter(client, character)
    if character:GetData("permadead") then
        return false, "@characterPermadead"
    end
end

-- Check if character was knocked out and timer expired while offline
function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
    local knockoutExpires = character:GetData("knockoutExpires")

    if knockoutExpires then
        if knockoutExpires < os.time() then
            -- Timer expired while offline - permadeath
            timer.Simple(1, function()
                if IsValid(client) and client:GetCharacter() == character then
                    self:ApplyPermadeath(client, character, "timer_expired_offline")
                end
            end)
        else
            -- Still knocked - recreate the knockout state
            local remaining = knockoutExpires - os.time()
            timer.Simple(0.5, function()
                if IsValid(client) and client:GetCharacter() == character then
                    self:RestoreKnockoutState(client, character, remaining)
                end
            end)
        end
    end
end

-- Restore knockout state for player who reconnected while knocked
function PLUGIN:RestoreKnockoutState(client, character, remainingTime)
    -- Check if there's an existing entity for this character
    local existingEntity = nil
    for _, ent in ipairs(ents.FindByClass("ix_knocked")) do
        if ent:GetCharacterID() == character:GetID() then
            existingEntity = ent
            break
        end
    end

    if IsValid(existingEntity) then
        -- Reconnect to existing entity
        client.ixKnockedEntity = existingEntity
        existingEntity.ixOwner = client
        existingEntity:SetOwningPlayer(client)

        -- Recalculate timer
        existingEntity:SetTimerStart(CurTime())
        existingEntity:SetTimerDuration(remainingTime)
    else
        -- Entity was removed (server restart?) - recreate it
        local knockoutCount = character:GetData("knockoutCount") or 1

        local entity = ents.Create("ix_knocked")
        entity:SetPos(client:GetPos())
        entity:SetAngles(client:EyeAngles())
        entity:Spawn()
        entity:Activate()

        entity:SetKnockedModel(client:GetModel())
        entity:SetKnockedSkin(client:GetSkin())
        entity:SetOwningPlayer(client)
        entity:SetCharacterID(character:GetID())
        entity:SetTimerStart(CurTime())
        entity:SetTimerDuration(remainingTime)

        for i = 0, client:GetNumBodyGroups() - 1 do
            entity:SetBodygroup(i, client:GetBodygroup(i))
        end

        local inventory = character:GetInventory()
        if inventory then
            entity:SetInventoryID(inventory:GetID())
        end

        client.ixKnockedEntity = entity
        entity.ixOwner = client
        self.knockedEntities[client:SteamID64()] = entity
    end

    -- Hide and freeze player
    client:StripWeapons()
    client:SetNoDraw(true)
    client:SetNotSolid(true)
    client:Freeze(true)
    client:SetMoveType(MOVETYPE_NONE)
    client:SetPos(client.ixKnockedEntity:GetPos() + Vector(0, 0, 10000))
    client:SetDSP(31)

    -- Notify client
    net.Start("ixKnockoutStart")
        net.WriteFloat(remainingTime)
        net.WriteUInt(character:GetData("knockoutCount") or 1, 8)
    net.Send(client)
end

-- Handle player disconnect while knocked
function PLUGIN:PlayerDisconnected(client)
    local entity = client.ixKnockedEntity

    if IsValid(entity) then
        -- Clear owner reference but keep entity alive
        entity.ixOwner = nil
        entity:SetOwningPlayer(NULL)
        -- Timer continues via entity Think
    end
end

-- ============================================================================
-- PASSIVE HEALING
-- ============================================================================

function PLUGIN:InitializedPlugins()
    -- Start passive healing timer
    timer.Create("ixPassiveHealing", 60, 0, function()
        local healRate = ix.config.Get("permadeathPassiveHealRate", 1)
        local healCap = ix.config.Get("permadeathPassiveHealCap", 80) / 100

        for _, client in player.Iterator() do
            if not IsValid(client) then continue end

            local character = client:GetCharacter()
            if not character then continue end
            if not client:Alive() then continue end
            if IsValid(client.ixKnockedEntity) then continue end

            local maxHealth = client:GetMaxHealth()
            local capHealth = math.floor(maxHealth * healCap)
            local currentHealth = client:Health()

            if currentHealth < capHealth then
                local newHealth = math.min(currentHealth + healRate, capHealth)
                client:SetHealth(newHealth)
            end
        end
    end)
end

-- ============================================================================
-- LOGGING
-- ============================================================================

function PLUGIN:InitializedSchema()
    -- Register log types
    ix.log.AddType("knockout", function(client, knockoutCount, duration)
        return string.format("%s was knocked out (knockout #%d, %s remaining)",
            client:Name(), knockoutCount, duration)
    end)

    ix.log.AddType("revival", function(client, revivedName, health)
        return string.format("%s revived %s with %d HP",
            client:Name(), revivedName, health)
    end)

    ix.log.AddType("permadeath", function(client, charName, reason)
        return string.format("%s's character '%s' died permanently (%s)",
            client:Name(), charName, reason)
    end)
end
