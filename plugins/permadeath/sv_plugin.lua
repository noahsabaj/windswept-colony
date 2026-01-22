--[[
    Permadeath Plugin - Server Logic

    Handles damage interception, knockout state management,
    revival mechanics, and permadeath application.
]]--

print("[Permadeath] sv_plugin.lua is loading...")

-- Store reference to active knockout entities by SteamID64
PLUGIN.knockedEntities = PLUGIN.knockedEntities or {}

-- ============================================================================
-- LOG TYPE REGISTRATION (must happen before any logging calls)
-- ============================================================================

ix.log.AddType("knockout", function(client, knockoutCount, duration)
    return string.format("%s was knocked out (knockout #%d, %s remaining)",
        client:Name(), knockoutCount, duration)
end, FLAG_WARNING)

ix.log.AddType("revival", function(client, revivedName, health)
    return string.format("%s revived %s with %d HP",
        client:Name(), revivedName, health)
end, FLAG_SUCCESS)

ix.log.AddType("permadeath", function(client, charName, reason)
    return string.format("%s's character '%s' died permanently (%s)",
        client:Name(), charName, reason)
end, FLAG_DANGER)

ix.log.AddType("knockout_giveup", function(client)
    return string.format("%s gave up while knocked out", client:Name())
end, FLAG_WARNING)

ix.log.AddType("defibKnockout", function(client, victimName)
    return string.format("%s shocked %s with a defibrillator, knocking them out",
        client:Name(), victimName)
end, FLAG_WARNING)

-- ============================================================================
-- DAMAGE INTERCEPTION (using EntityTakeDamage hook)
-- ============================================================================

-- Track hit groups for headshot detection
-- ScalePlayerDamage is called before damage is applied and gives us the hit group
function PLUGIN:ScalePlayerDamage(client, hitGroup, dmgInfo)
    client.ixLastHitGroup = hitGroup
end

-- Intercept lethal damage and convert to knockout
-- EntityTakeDamage allows us to modify/cancel damage before it's applied
function PLUGIN:EntityTakeDamage(entity, dmgInfo)
    -- Only handle player damage
    if not entity:IsPlayer() then return end

    local client = entity
    local character = client:GetCharacter()
    if not character then return end

    -- If player is already knocked out, ignore (damage goes to entity instead)
    if IsValid(client.ixKnockedEntity) then return end

    -- Prevent race condition: if we're already processing lethal damage for this player
    -- (e.g., multiple bullets in same frame), ignore subsequent damage
    if client.ixProcessingLethalDamage then return end

    -- Check if this damage would be lethal
    local currentHealth = client:Health()
    local damage = dmgInfo:GetDamage()

    if currentHealth - damage > 0 then
        -- Not lethal, let normal damage through
        return
    end

    -- This would be lethal - intercept it
    print("[Permadeath] Lethal damage intercepted for " .. client:Name())

    -- Set flag to prevent race conditions with multiple damage events
    client.ixProcessingLethalDamage = true

    -- Scale damage to 0 to prevent death
    dmgInfo:ScaleDamage(0)

    -- Check for headshot - configurable chance of instant permadeath
    if self:IsHeadshot(client) then
        local headshotChance = ix.config.Get("permadeathHeadshotChance", 50) / 100
        if math.random() < headshotChance then
            -- Lost the coin flip - instant permadeath
            print("[Permadeath] Headshot execution!")
            self:ApplyPermadeath(client, character, "headshot_execution")
            client.ixProcessingLethalDamage = nil
            return
        end
        -- Won the coin flip - proceed to normal knockout
        print("[Permadeath] Survived headshot coin flip")
    end

    -- Create knockout state instead of death
    self:CreateKnockout(client, character, dmgInfo)
    client.ixProcessingLethalDamage = nil
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

    -- Collect bodygroups
    local bodygroups = {}
    for i = 0, client:GetNumBodyGroups() - 1 do
        bodygroups[i] = client:GetBodygroup(i)
    end

    -- Create the ix_knocked entity (invisible controller)
    local entity = ents.Create("ix_knocked")
    if not IsValid(entity) then
        ErrorNoHalt("[Permadeath] Failed to create ix_knocked entity!\n")
        return
    end

    entity:SetPos(pos)
    entity:SetAngles(Angle(0, ang.y, 0))
    entity:Spawn()
    entity:Activate()

    -- Configure entity with player data (NetworkVars)
    entity:SetKnockedModel(model)
    entity:SetKnockedSkin(skin)
    entity:SetOwningPlayer(client)
    entity:SetCharacterID(character:GetID())
    entity:SetCharacterName(character:GetName())  -- Store name permanently
    entity:SetTimerStart(CurTime())
    entity:SetTimerDuration(duration)

    -- Create the visible ragdoll
    entity:CreateRagdoll(model, skin, bodygroups)

    -- Link to character's inventory for looting
    local inventory = character:GetInventory()
    if inventory then
        entity:SetInventoryID(inventory:GetID())
    end

    -- Store references
    client.ixKnockedEntity = entity
    entity.ixOwner = client
    entity.ixSteamID64 = client:SteamID64()
    self.knockedEntities[entity.ixSteamID64] = entity

    -- Drop currently equipped weapon (except protected items)
    local activeWeapon = client:GetActiveWeapon()
    if IsValid(activeWeapon) then
        local class = activeWeapon:GetClass()
        local protected = {["ix_keys"] = true, ["ix_hands"] = true, ["ix_handsup"] = true}

        if not protected[class] and activeWeapon.ixItem then
            local item = activeWeapon.ixItem
            item:SetData("equipped", nil)
            local dropPos = client:GetPos() + Vector(0, 0, 10)
            item:Transfer(nil, nil, nil, client, dropPos)
        end
    end

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

    -- Check if owner is online (can't revive disconnected players)
    if not IsValid(knockedEntity.ixOwner) then
        reviver:NotifyLocalized("knockedPlayerDisconnected")
        return false
    end

    -- Check if someone else is already reviving
    local currentReviver = knockedEntity:GetCurrentReviver()
    if IsValid(currentReviver) and currentReviver ~= reviver then
        reviver:NotifyLocalized("knockedAlreadyBeingRevived")
        return false
    end

    -- Lock the entity to this reviver
    knockedEntity:SetCurrentReviver(reviver)

    -- Random progress duration (3-10 seconds by default)
    -- This is equipmentless CPR-style revival (no defib)
    local duration = self:GetRevivalDuration()

    -- Start the revival progress
    reviver:SetAction("@reviving", duration)

    -- Use DoStaredAction for progress-based revival (must look at target)
    -- Signature: DoStaredAction(entity, callback, time, onCancel, distance)
    reviver:DoStaredAction(knockedEntity, function()
        -- Completed - attempt the revival (equipmentless, no defib)
        self:CompleteRevivalAttempt(reviver, knockedEntity, false, nil)
    end, duration, function()
        -- Cancelled (looked away, moved too far, etc.)
        knockedEntity:SetCurrentReviver(NULL)
        reviver:SetAction()
    end, 96)  -- 96 units max distance for revival

    return true
end

function PLUGIN:CompleteRevivalAttempt(reviver, knockedEntity, hasDefib, defibItem)
    -- Clear the reviver lock
    knockedEntity:SetCurrentReviver(NULL)

    -- Calculate success using probabilistic squared
    -- hasDefib is false for hold-E revival (CPR-style, low chance)
    local success, actualChance = self:CalculateRevivalChance(hasDefib)

    if success then
        -- Revival succeeded!
        self:RevivePlayer(knockedEntity, reviver, hasDefib, defibItem)
    else
        -- Revival failed - can retry
        reviver:NotifyLocalized("revivalFailed")
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
    if knockedEntity.ixSteamID64 then
        self.knockedEntities[knockedEntity.ixSteamID64] = nil
    end
    knockedEntity:Remove()

    -- Log the revival
    ix.log.Add(reviver, "revival", character:GetName(), revivalHealth)
end

-- ============================================================================
-- PERMADEATH
-- ============================================================================

-- Delete a character from the database (replicates Helix's deletion logic)
function PLUGIN:DeleteCharacter(client, character)
    local id = character:GetID()
    local steamID = client:SteamID64()

    print("[Permadeath] Deleting character ID: " .. id)

    -- Remove from player's character list
    for k, v in ipairs(client.ixCharList or {}) do
        if v == id then
            table.remove(client.ixCharList, k)
            break
        end
    end

    -- Run pre-delete hook
    hook.Run("PreCharacterDeleted", client, character)

    -- Remove from loaded characters
    ix.char.loaded[id] = nil

    -- Notify all clients about the deletion
    net.Start("ixCharacterDelete")
        net.WriteUInt(id, 32)
    net.Broadcast()

    -- Delete character from database
    local query = mysql:Delete("ix_characters")
        query:Where("id", id)
        query:Where("steamid", steamID)
    query:Execute()

    -- NOTE: We intentionally do NOT delete the inventory here!
    -- The dead body (ix_knocked entity) needs the inventory for looting.
    -- The inventory will be cleaned up when the body is removed.

    -- Run post-delete hook
    hook.Run("CharacterDeleted", client, id, true)

    print("[Permadeath] Character deleted successfully")
end

-- Delete a character when the player is offline (database only)
function PLUGIN:DeleteCharacterOffline(charID)
    print("[Permadeath] Deleting offline character ID: " .. charID)

    -- Remove from loaded characters if still there
    ix.char.loaded[charID] = nil

    -- Notify all clients about the deletion
    net.Start("ixCharacterDelete")
        net.WriteUInt(charID, 32)
    net.Broadcast()

    -- Delete character from database
    local query = mysql:Delete("ix_characters")
        query:Where("id", charID)
    query:Execute()

    -- NOTE: We intentionally do NOT delete the inventory here!
    -- The dead body (ix_knocked entity) needs the inventory for looting.
    -- The inventory will be cleaned up when the body is removed.

    print("[Permadeath] Offline character deleted successfully")
end

function PLUGIN:ApplyPermadeath(client, character, reason)
    print("[Permadeath] ApplyPermadeath called for " .. (IsValid(client) and client:Name() or "invalid") .. ", reason: " .. reason)

    -- Mark character as permanently dead
    character:SetData("permadead", true)
    character:SetData("permaDeathReason", reason)
    character:SetData("permaDeathTime", os.time())

    -- Clear knockout state
    character:SetData("knocked", nil)
    character:SetData("knockoutExpires", nil)

    -- If there's a knockout entity, mark it as permadead (stays for looting)
    if IsValid(client) and IsValid(client.ixKnockedEntity) then
        local knockedEntity = client.ixKnockedEntity
        -- Clean up tracking table
        if knockedEntity.ixSteamID64 then
            self.knockedEntities[knockedEntity.ixSteamID64] = nil
        end
        knockedEntity:SetPermadead(true)
        knockedEntity.ixOwner = nil
        client.ixKnockedEntity = nil
    end

    -- Notify client and kick to character menu
    if IsValid(client) then
        print("[Permadeath] Sending ixKnockoutEnd to client")
        net.Start("ixKnockoutEnd")
            net.WriteBool(false)  -- Permadead
            net.WriteUInt(0, 8)
        net.Send(client)

        -- Small delay before kicking to character menu and deleting
        print("[Permadeath] Scheduling character:Kick() in 2 seconds")
        local charID = character:GetID()
        timer.Simple(2, function()
            if IsValid(client) then
                print("[Permadeath] Timer fired, kicking to character menu")
                client:SetNoDraw(false)
                client:SetNotSolid(false)
                client:Freeze(false)
                client:SetMoveType(MOVETYPE_WALK)
                client:SetDSP(0)
                client:KillSilent()

                -- Kick back to character menu
                print("[Permadeath] Calling character:Kick()")
                character:Kick()

                -- Delete the character after a short delay to ensure kick completes
                timer.Simple(0.5, function()
                    if IsValid(client) then
                        self:DeleteCharacter(client, character)
                    end
                end)
            else
                print("[Permadeath] Timer fired but client no longer valid")
                -- Player disconnected, still delete the character from database
                -- Need to handle this case without a valid client
                self:DeleteCharacterOffline(charID)
            end
        end)
    end

    -- Log permadeath
    ix.log.Add(client, "permadeath", character:GetName(), reason)
end

-- Called when knockout timer expires
function PLUGIN:OnKnockoutExpired(knockedEntity)
    print("[Permadeath] OnKnockoutExpired called")

    -- Immediately set permadead to prevent multiple calls from Think()
    knockedEntity:SetPermadead(true)

    local charID = knockedEntity:GetCharacterID()
    local character = ix.char.loaded[charID]

    print("[Permadeath] CharID: " .. tostring(charID) .. ", Character: " .. tostring(character))

    -- Clean up tracking table
    if knockedEntity.ixSteamID64 then
        self.knockedEntities[knockedEntity.ixSteamID64] = nil
    end

    if not character then
        print("[Permadeath] No character found, entity already set permadead")
        return
    end

    local owner = knockedEntity.ixOwner
    print("[Permadeath] Owner: " .. tostring(owner) .. ", IsValid: " .. tostring(IsValid(owner)))

    if IsValid(owner) then
        print("[Permadeath] Calling ApplyPermadeath for online player")
        self:ApplyPermadeath(owner, character, "timer_expired")
    else
        -- Player offline - apply permadeath and delete character
        print("[Permadeath] Player offline, deleting character")
        knockedEntity.ixOwner = nil

        -- Delete the character from database
        self:DeleteCharacterOffline(charID)
    end
end

-- ============================================================================
-- DEFIBRILLATOR HELPERS
-- ============================================================================

function PLUGIN:PlayerHasDefibReady(client)
    -- Check if player has a defibrillator equipped/ready with batteries
    if client.ixDefibReady and client.ixDefibItem then
        local item = client.ixDefibItem
        local batteries = item:GetData("batteries", {})
        for _, charge in ipairs(batteries) do
            if charge > 0 then return true, item end
        end
    end
    return false, nil
end

function PLUGIN:ConsumeDefibCharge(item, client)
    local batteries = item:GetData("batteries", {})
    if #batteries == 0 then return end

    -- Find first FULL battery (100up) and deplete it
    for i, charge in ipairs(batteries) do
        if charge == 100 then
            batteries[i] = 0  -- Deplete, don't remove
            break
        end
    end

    local character = client:GetCharacter()
    local inventory = character and character:GetInventory()

    -- Auto-eject: remove non-full batteries if enabled (0up and partial)
    if inventory and ix.option.Get(client, "batteryAutoEject", true) then
        for i = #batteries, 1, -1 do
            if batteries[i] < 100 then  -- Eject anything that's not full
                if inventory:FindEmptySlot(1, 1) then
                    inventory:Add("battery", 1, {charge = batteries[i]})
                    table.remove(batteries, i)
                    client:NotifyLocalized("flashlightBatteryEjected")
                end
            end
        end
    end

    -- Auto-load: fill empty slots with 100up batteries
    if inventory and ix.option.Get(client, "batteryAutoLoad", true) then
        while #batteries < 4 do
            local fullBattery = item:FindFullBatteryInInventory(inventory)
            if fullBattery then
                table.insert(batteries, 100)
                fullBattery:Remove()
                client:NotifyLocalized("defibAutoLoaded")
            else
                break
            end
        end
    end

    item:SetData("batteries", batteries)

    -- Count usable (100up) batteries for notification
    local usableCount = 0
    for _, charge in ipairs(batteries) do
        if charge == 100 then usableCount = usableCount + 1 end
    end
    client:NotifyLocalized("defibBatteryUsed", usableCount)

    -- Warn if no usable batteries left
    if usableCount == 0 then
        client:NotifyLocalized("defibNoBattery")
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

        -- Ensure SteamID64 is stored (may be missing from older entities)
        if not existingEntity.ixSteamID64 then
            existingEntity.ixSteamID64 = client:SteamID64()
            self.knockedEntities[existingEntity.ixSteamID64] = existingEntity
        end

        -- Ensure character name is stored (may be missing from older entities)
        if not existingEntity:GetCharacterName() or existingEntity:GetCharacterName() == "" then
            existingEntity:SetCharacterName(character:GetName())
        end

        -- Ensure ragdoll exists (may have been removed)
        if not IsValid(existingEntity.ixRagdoll) then
            local bodygroups = {}
            for i = 0, client:GetNumBodyGroups() - 1 do
                bodygroups[i] = client:GetBodygroup(i)
            end
            existingEntity:CreateRagdoll(client:GetModel(), client:GetSkin(), bodygroups)
        end

        -- Recalculate timer
        existingEntity:SetTimerStart(CurTime())
        existingEntity:SetTimerDuration(remainingTime)
    else
        -- Entity was removed (server restart?) - recreate it
        local knockoutCount = character:GetData("knockoutCount") or 1

        -- Collect bodygroups
        local bodygroups = {}
        for i = 0, client:GetNumBodyGroups() - 1 do
            bodygroups[i] = client:GetBodygroup(i)
        end

        local entity = ents.Create("ix_knocked")
        entity:SetPos(client:GetPos())
        entity:SetAngles(client:EyeAngles())
        entity:Spawn()
        entity:Activate()

        entity:SetKnockedModel(client:GetModel())
        entity:SetKnockedSkin(client:GetSkin())
        entity:SetOwningPlayer(client)
        entity:SetCharacterID(character:GetID())
        entity:SetCharacterName(character:GetName())  -- Store name permanently
        entity:SetTimerStart(CurTime())
        entity:SetTimerDuration(remainingTime)

        -- Create the visible ragdoll
        entity:CreateRagdoll(client:GetModel(), client:GetSkin(), bodygroups)

        local inventory = character:GetInventory()
        if inventory then
            entity:SetInventoryID(inventory:GetID())
        end

        client.ixKnockedEntity = entity
        entity.ixOwner = client
        entity.ixSteamID64 = client:SteamID64()
        self.knockedEntities[entity.ixSteamID64] = entity
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
-- GIVE UP HANDLER
-- ============================================================================

net.Receive("ixKnockoutGiveUp", function(len, client)
    print("[Permadeath] Received ixKnockoutGiveUp from " .. (IsValid(client) and client:Name() or "invalid"))

    -- Validate player is actually knocked out
    if not IsValid(client) then
        print("[Permadeath] Give up failed: invalid client")
        return
    end

    if not IsValid(client.ixKnockedEntity) then
        print("[Permadeath] Give up failed: no ixKnockedEntity")
        return
    end

    local entity = client.ixKnockedEntity
    if entity:GetPermadead() then
        print("[Permadeath] Give up failed: already permadead")
        return
    end

    -- Get current remaining time
    local remaining = entity:GetRemainingTime()
    print("[Permadeath] Give up: remaining time = " .. remaining)

    -- Only reduce if timer is above 10 seconds (don't extend if already lower)
    if remaining > 10 then
        entity:SetTimerStart(CurTime())
        entity:SetTimerDuration(10)

        -- Sync to client
        net.Start("ixKnockoutTimerSync")
            net.WriteFloat(10)
        net.Send(client)

        print("[Permadeath] Give up: timer reduced to 10 seconds")

        -- Log the give up
        ix.log.Add(client, "knockout_giveup")
    else
        print("[Permadeath] Give up: timer already <= 10, not extending")
    end
end)

-- ============================================================================
-- KNOCKED BODY INTERACTION (E tap = Loot, E hold = Revive)
-- ============================================================================

-- E tap: Search/loot body (works on both knocked and dead)
net.Receive("ixKnockoutLoot", function(len, client)
    if not IsValid(client) then return end

    local entity = net.ReadEntity()

    -- Validate entity is a valid ix_knocked
    if not IsValid(entity) or entity:GetClass() ~= "ix_knocked" then
        return
    end

    -- Validate distance
    local distance = client:GetPos():Distance(entity:GetPos())
    if distance > 96 then
        return
    end

    -- Open inventory for looting
    entity:OpenInventory(client)
end)

-- E hold: Attempt revival (only works on knocked, not dead)
net.Receive("ixKnockoutRevive", function(len, client)
    if not IsValid(client) then return end

    local entity = net.ReadEntity()

    -- Validate entity is a valid ix_knocked
    if not IsValid(entity) or entity:GetClass() ~= "ix_knocked" then
        return
    end

    -- Validate distance
    local distance = client:GetPos():Distance(entity:GetPos())
    if distance > 96 then
        return
    end

    -- Can't revive the dead
    if entity:GetPermadead() then
        client:NotifyLocalized("knockedAlreadyDead")
        return
    end

    -- Attempt revival through plugin
    local plugin = ix.plugin.Get("permadeath")
    if plugin then
        plugin:AttemptRevival(client, entity)
    end
end)

-- ============================================================================
-- PLAYERUSE HOOK
-- Helix blocks USE on entities with GetEntityMenu (menu-only interaction).
-- Our knocked body ragdolls need GetEntityMenu for right-click options (Search/Revive)
-- AND they need USE to work for E-tap/hold interaction (faster, more intuitive).
-- This hook tells Helix to allow USE on our ragdolls so both methods work.
-- ============================================================================

function PLUGIN:CanPlayerUseEntity(client, entity)
    if IsValid(entity) and entity:GetClass() == "prop_ragdoll" then
        local knockedEnt = entity:GetNetVar("ixKnockedEntity")
        if IsValid(knockedEnt) then
            return true
        end
    end
end

-- ============================================================================
-- LOGGING (log types registered at top of file)
-- ============================================================================
