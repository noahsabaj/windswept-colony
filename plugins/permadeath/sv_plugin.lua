--[[
    Permadeath Plugin - Server Logic

    Handles damage interception, knockout state management,
    revival mechanics, and permadeath application.
]]--

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

ix.log.AddType("suicide", function(client, charName)
    return string.format("%s's character '%s' took their own life", client:Name(), charName)
end, FLAG_DANGER)

ix.log.AddType("cremation", function(client, charName)
    return string.format("Body of '%s' was cremated", charName)
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
    -- Forward damage from prop_ragdoll to its linked ix_knocked entity
    if entity:GetClass() == "prop_ragdoll" and IsValid(entity.ixKnockedEntity) then
        entity.ixKnockedEntity:OnTakeDamage(dmgInfo)
        return
    end

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

    -- Set flag to prevent race conditions with multiple damage events
    client.ixProcessingLethalDamage = true

    -- Scale damage to 0 to prevent death
    dmgInfo:ScaleDamage(0)

    -- Check for headshot - configurable chance of instant permadeath
    if self:IsHeadshot(client) then
        local headshotChance = ix.config.Get("permadeathHeadshotChance", 50) / 100
        if math.random() < headshotChance then
            -- Lost the coin flip - instant permadeath
            -- Create the knocked entity first so there's a body to leave behind
            local pos = client:GetPos()
            local ang = Angle(0, client:EyeAngles().y, 0)
            local entity = self:CreateKnockedEntity(client, character, pos, ang, 0)

            if entity then
                self:HideKnockedPlayer(client, entity)
            end

            self:ApplyPermadeath(client, character, "headshot_execution")
            client.ixProcessingLethalDamage = nil
            return
        end
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

-- Prevent Helix from creating competing ragdolls when player has knockout entity
-- Helix's DoPlayerDeath checks this hook before calling client:CreateRagdoll()
function PLUGIN:ShouldSpawnClientRagdoll(client)
    if IsValid(client.ixKnockedEntity) then
        return false
    end
end

-- ============================================================================
-- KNOCKOUT HELPERS
-- ============================================================================

-- Collect all bodygroups from a player
function PLUGIN:CollectBodygroups(client)
    local bodygroups = {}
    for i = 0, client:GetNumBodyGroups() - 1 do
        bodygroups[i] = client:GetBodygroup(i)
    end
    return bodygroups
end

-- Collect all SubMaterials from a player (clothing system)
function PLUGIN:CollectSubMaterials(client)
    local submaterials = {}
    local materials = client:GetMaterials()
    for i = 0, #materials - 1 do
        local submat = client:GetSubMaterial(i)
        if submat and submat ~= "" then
            submaterials[i] = submat
        end
    end
    return submaterials
end

-- Check if a player entity is on fire (supports windswept_fire, vFire, and GMod native)
function PLUGIN:IsPlayerOnFire(client)
    if not IsValid(client) then return false end

    -- Prefer ws_fire API if available
    if ws_fire and ws_fire.IsOnFire then
        return ws_fire.IsOnFire(client)
    end

    -- Fallback: Check .fires table (works with vFire and windswept_fire)
    if client.fires and next(client.fires) then
        return true
    end

    -- Final fallback to GMod native
    return client:IsOnFire()
end

-- Create and configure an ix_knocked entity
function PLUGIN:CreateKnockedEntity(client, character, pos, ang, duration)
    local entity = ents.Create("ix_knocked")
    if not IsValid(entity) then
        ErrorNoHalt("[Permadeath] Failed to create ix_knocked entity!\n")
        return nil
    end

    entity:SetPos(pos)
    entity:SetAngles(ang)
    entity:Spawn()
    entity:Activate()

    -- Configure NetworkVars
    entity:SetKnockedModel(client:GetModel())
    entity:SetKnockedSkin(client:GetSkin())
    entity:SetOwningPlayer(client)
    entity:SetCharacterID(character:GetID())
    entity:SetCharacterName(character:GetName())
    entity:SetTimerStart(CurTime())
    entity:SetTimerDuration(duration)

    -- Link to character's inventory for looting
    local inventory = character:GetInventory()
    if inventory then
        entity:SetInventoryID(inventory:GetID())
    end

    -- Create the visible ragdoll
    local bodygroups = self:CollectBodygroups(client)
    local submaterials = self:CollectSubMaterials(client)
    entity:CreateRagdoll(client:GetModel(), client:GetSkin(), bodygroups, submaterials)

    -- Store references
    client.ixKnockedEntity = entity
    entity.ixOwner = client
    entity.ixSteamID64 = client:SteamID64()
    self.knockedEntities[entity.ixSteamID64] = entity

    -- Transfer cremation progress from alive player (if any)
    if client.ixCremationProgress and client.ixCremationProgress > 0 then
        entity:SetBurnProgress(client.ixCremationProgress)
        entity.ixLastBurnThink = CurTime()
        -- Clear from player
        client.ixCremationProgress = nil
        client.ixLastFireThink = nil
    end

    return entity
end

-- Hide and freeze a knocked player
function PLUGIN:HideKnockedPlayer(client, entity)
    client:StripWeapons()
    client:SetNoDraw(true)
    client:SetNotSolid(true)
    client:Freeze(true)
    client:SetMoveType(MOVETYPE_NONE)
    client:SetPos(entity:GetPos() + Vector(0, 0, 10000))
    client:SetDSP(31)
end

-- Send knockout notification to client
function PLUGIN:SendKnockoutStart(client, duration, knockoutCount)
    net.Start("ixKnockoutStart")
        net.WriteFloat(duration)
        net.WriteUInt(knockoutCount, 8)
    net.Send(client)
end

-- Validate a knocked body interaction (loot, revive, etc.)
-- Returns entity if valid and in range, nil otherwise
function PLUGIN:ValidateKnockedInteraction(client, entity)
    if not IsValid(entity) or entity:GetClass() ~= "ix_knocked" then
        return nil
    end

    -- Check distance to ragdoll (the visible/draggable body), not ix_knocked entity
    -- The ix_knocked entity stays at the original knockout position, but the ragdoll can be dragged
    local checkPos = IsValid(entity.ixRagdoll) and entity.ixRagdoll:GetPos() or entity:GetPos()
    if client:GetPos():Distance(checkPos) > 96 then
        return nil
    end

    return entity
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

    -- Create the knocked entity (zeroes pitch/roll for ragdoll)
    local pos = client:GetPos()
    local ang = Angle(0, client:EyeAngles().y, 0)
    local entity = self:CreateKnockedEntity(client, character, pos, ang, duration)
    if not entity then return end

    -- Drop currently equipped weapon (except protected items)
    local activeWeapon = client:GetActiveWeapon()
    if IsValid(activeWeapon) then
        local class = activeWeapon:GetClass()
        local protected = {["ix_hands"] = true, ["ix_handsup"] = true}

        if not protected[class] and activeWeapon.ixItem then
            local item = activeWeapon.ixItem
            -- Clear equipped state before dropping
            item:SetData("equipped", nil)
            item:Transfer(nil, nil, nil, client, client:GetPos() + Vector(0, 0, 10))
        end
    end

    self:HideKnockedPlayer(client, entity)
    self:SendKnockoutStart(client, duration, knockoutCount)

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

    -- Track revival attempt time to prevent Use() from triggering loot during/after CPR
    knockedEntity.ixLastReviveAttempt = CurTime()

    -- Random progress duration (3-10 seconds by default)
    -- This is equipmentless CPR-style revival (no defib)
    local duration = self:GetRevivalDuration()

    -- Start the revival progress
    reviver:SetAction("@reviving", duration)

    -- IMPORTANT: Pass the ragdoll to DoStaredAction, not the ix_knocked entity
    -- The ix_knocked entity is invisible and hidden - player is looking at the ragdoll
    local stareTarget = IsValid(knockedEntity.ixRagdoll) and knockedEntity.ixRagdoll or knockedEntity

    -- Use DoStaredAction for progress-based revival (must look at target)
    -- Signature: DoStaredAction(entity, callback, time, onCancel, distance)
    reviver:DoStaredAction(stareTarget, function()
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

    -- Update revival attempt timestamp to prevent immediate loot after CPR
    knockedEntity.ixLastReviveAttempt = CurTime()

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
        -- Move player to ragdoll position (where the body actually is after potential dragging)
        local revivePos = IsValid(knockedEntity.ixRagdoll) and knockedEntity.ixRagdoll:GetPos() or knockedEntity:GetPos()
        local reviveAng = IsValid(knockedEntity.ixRagdoll) and knockedEntity.ixRagdoll:GetAngles() or knockedEntity:GetAngles()
        owner:SetPos(revivePos)
        owner:SetEyeAngles(reviveAng)

        -- Restore player state
        owner:SetNoDraw(false)
        owner:SetNotSolid(false)
        owner:Freeze(false)
        owner:SetMoveType(MOVETYPE_WALK)

        -- Set revival health
        owner:SetHealth(revivalHealth)

        -- Temporary no-collide to prevent clipping with reviver
        owner:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        timer.Simple(1.5, function()
            if IsValid(owner) then
                owner:SetCollisionGroup(COLLISION_GROUP_PLAYER)
            end
        end)

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

        -- Handle cremation state on revival
        if not self:IsPlayerOnFire(owner) then
            -- Not on fire after revival = reset cremation (body heals)
            owner.ixCremationProgress = nil
            owner.ixLastFireThink = nil
        else
            -- Still on fire after revival - transfer progress back from entity
            local burnProgress = knockedEntity:GetBurnProgress()
            if burnProgress and burnProgress > 0 then
                owner.ixCremationProgress = burnProgress
                owner.ixLastFireThink = CurTime()
            end
        end
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

end

-- Delete a character when the player is offline (database only)
function PLUGIN:DeleteCharacterOffline(charID)
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

end

-- Find a character's Personal ID item from their inventory
function PLUGIN:FindPersonalID(character)
    local inventory = character:GetInventory()
    if not inventory then return nil end

    local items = inventory:GetItemsByUniqueID("personal_id", false)
    return items[1] or nil
end

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
        local knockedEntity = client.ixKnockedEntity
        if knockedEntity.ixSteamID64 then
            self.knockedEntities[knockedEntity.ixSteamID64] = nil
        end
        knockedEntity:SetPermadead(true)
        knockedEntity.ixOwner = nil
        client.ixKnockedEntity = nil
    end

    -- Log permadeath
    ix.log.Add(client, "permadeath", character:GetName(), reason)

    if IsValid(client) then
        -- Bots don't get memorial screens - just kick them from the server
        if client:IsBot() then
            -- Delete the bot's character
            local charID = character:GetID()
            ix.char.loaded[charID] = nil

            -- Kick the bot from the server
            client:Kick("Permadeath")
            return
        end

        -- Gather memorial data BEFORE deleting character
        local charName = character:GetName()
        local model = character:GetModel()
        local personalID = self:FindPersonalID(character)
        local physical = personalID and personalID:GetData("physical", {}) or {}

        local birthMonth = physical.birthMonth or 1
        local birthDay = physical.birthDay or 1
        local age = physical.age or 25
        local skin = physical.skin or client:GetSkin() or 0
        local bodygroups = physical.bodygroups or ""

        -- Convert bodygroups table to string if needed
        if istable(bodygroups) then
            local bgStr = ""
            for i = 0, 20 do
                bgStr = bgStr .. (bodygroups[i] or 0)
            end
            bodygroups = bgStr
        end

        -- Restore player state (make visible again for memorial)
        client:SetNoDraw(false)
        client:SetNotSolid(false)
        client:Freeze(true)  -- Keep frozen so they can't move
        client:SetMoveType(MOVETYPE_NONE)
        client:SetDSP(0)

        -- Delete the character NOW (before memorial - no escape)
        self:DeleteCharacter(client, character)

        -- Send memorial screen data
        net.Start("ixPermadeathScreen")
            net.WriteString(charName)
            net.WriteString(model)
            net.WriteUInt(skin, 8)
            net.WriteString(bodygroups)
            net.WriteUInt(birthMonth, 4)
            net.WriteUInt(birthDay, 5)
            net.WriteUInt(age, 8)
        net.Send(client)

        -- Start 60s timeout timer (in case client never responds)
        local steamID = client:SteamID64()
        timer.Create("ixPermadeathTimeout_" .. steamID, 60, 1, function()
            if IsValid(client) then
                client:Freeze(false)
                client:KillSilent()

                -- Tell client to open character menu
                net.Start("ixCharacterKick")
                    net.WriteBool(true)  -- isCurrentChar = true
                net.Send(client)

                -- Clear the character netvar and spawn
                client:SetNetVar("char", nil)
                client:Spawn()
            end
        end)
    end
end

-- Called when knockout timer expires
function PLUGIN:OnKnockoutExpired(knockedEntity)
    -- Cancel any active revival attempt (CPR in progress)
    local reviver = knockedEntity:GetCurrentReviver()
    if IsValid(reviver) then
        reviver:SetAction()  -- Clear action bar
        reviver:NotifyLocalized("cprCanceledPatientDied")
        knockedEntity:SetCurrentReviver(NULL)
    end

    -- Immediately set permadead to prevent multiple calls from Think()
    knockedEntity:SetPermadead(true)

    local charID = knockedEntity:GetCharacterID()
    local character = ix.char.loaded[charID]

    -- Clean up tracking table
    if knockedEntity.ixSteamID64 then
        self.knockedEntities[knockedEntity.ixSteamID64] = nil
    end

    if not character then
        return
    end

    local owner = knockedEntity.ixOwner

    if IsValid(owner) then
        self:ApplyPermadeath(owner, character, "timer_expired")
    else
        -- Player offline - apply permadeath and delete character
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
    -- Use knockedEntities table lookup instead of ents.FindByClass iteration
    local existingEntity = self.knockedEntities[client:SteamID64()]

    -- Fallback: if not in table, search by character ID (handles edge cases)
    if not IsValid(existingEntity) then
        for steamID, ent in pairs(self.knockedEntities) do
            if IsValid(ent) and ent:GetCharacterID() == character:GetID() then
                existingEntity = ent
                break
            end
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
            local bodygroups = self:CollectBodygroups(client)
            local submaterials = self:CollectSubMaterials(client)
            existingEntity:CreateRagdoll(client:GetModel(), client:GetSkin(), bodygroups, submaterials)
        end

        -- Recalculate timer
        existingEntity:SetTimerStart(CurTime())
        existingEntity:SetTimerDuration(remainingTime)
    else
        -- Entity was removed (server restart?) - recreate it
        local pos = client:GetPos()
        local ang = client:EyeAngles()
        self:CreateKnockedEntity(client, character, pos, ang, remainingTime)
    end

    self:HideKnockedPlayer(client, client.ixKnockedEntity)
    self:SendKnockoutStart(client, remainingTime, character:GetData("knockoutCount") or 1)
end

-- Handle player disconnect while knocked
function PLUGIN:PlayerDisconnected(client)
    -- Clean up memorial timeout timer
    timer.Remove("ixPermadeathTimeout_" .. client:SteamID64())

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

    -- Alive player cremation tracking (1.5s interval - cremation is not time-critical)
    timer.Create("ixAliveFireTracking", 1.5, 0, function()
        for _, client in player.Iterator() do
            if not IsValid(client) then continue end
            if not client:Alive() then continue end
            if IsValid(client.ixKnockedEntity) then continue end -- They're knocked, entity handles it

            local isOnFire = self:IsPlayerOnFire(client)

            if isOnFire then
                -- Initialize or continue tracking
                if not client.ixCremationProgress then
                    client.ixCremationProgress = 0
                end
                if not client.ixLastFireThink then
                    client.ixLastFireThink = CurTime()
                end

                -- Accumulate burn time
                local delta = CurTime() - client.ixLastFireThink
                client.ixCremationProgress = client.ixCremationProgress + delta
                client.ixLastFireThink = CurTime()
            else
                -- Fire extinguished while alive = RESET (body heals)
                if client.ixCremationProgress and client.ixCremationProgress > 0 then
                    client.ixCremationProgress = 0
                    client.ixLastFireThink = nil
                end
            end
        end
    end)
end

-- ============================================================================
-- GIVE UP HANDLER
-- ============================================================================

net.Receive("ixKnockoutGiveUp", function(len, client)
    -- Validate player is actually knocked out
    if not IsValid(client) then return end

    if not IsValid(client.ixKnockedEntity) then return end

    local entity = client.ixKnockedEntity
    if entity:GetPermadead() then return end

    -- Get current remaining time
    local remaining = entity:GetRemainingTime()

    -- Only reduce if timer is above 10 seconds (don't extend if already lower)
    if remaining > 10 then
        entity:SetTimerStart(CurTime())
        entity:SetTimerDuration(10)

        -- Sync to client
        net.Start("ixKnockoutTimerSync")
            net.WriteFloat(10)
        net.Send(client)

        -- Log the give up
        ix.log.Add(client, "knockout_giveup")
    end
end)

-- ============================================================================
-- KNOCKED BODY INTERACTION (E tap = Loot, E hold = Revive)
-- ============================================================================

-- E tap: Search/loot body (works on both knocked and dead)
net.Receive("ixKnockoutLoot", function(len, client)
    if not IsValid(client) then return end

    local plugin = ix.plugin.Get("permadeath")
    if not plugin then return end

    local entity = plugin:ValidateKnockedInteraction(client, net.ReadEntity())
    if not entity then return end

    -- Block searching while actively performing CPR on this body
    if entity:GetCurrentReviver() == client then
        client:NotifyLocalized("cprCannotSearchDuring")
        return
    end

    entity:OpenInventory(client)
end)

-- E hold: Attempt revival (only works on knocked, not dead)
net.Receive("ixKnockoutRevive", function(len, client)
    if not IsValid(client) then return end

    local plugin = ix.plugin.Get("permadeath")
    if not plugin then return end

    local entity = plugin:ValidateKnockedInteraction(client, net.ReadEntity())
    if not entity then return end

    if entity:GetPermadead() then
        client:NotifyLocalized("knockedAlreadyDead")
        return
    end

    plugin:AttemptRevival(client, entity)
end)

-- ============================================================================
-- MEMORIAL ACKNOWLEDGMENT
-- ============================================================================

-- Client acknowledged memorial screen
net.Receive("ixPermadeathReady", function(len, client)
    if not IsValid(client) then return end

    local steamID = client:SteamID64()

    -- Cancel the timeout timer
    timer.Remove("ixPermadeathTimeout_" .. steamID)

    -- Properly kick to character menu (replicating Helix's character:Kick() logic)
    client:Freeze(false)
    client:KillSilent()

    -- Tell client to open character menu
    net.Start("ixCharacterKick")
        net.WriteBool(true)  -- isCurrentChar = true
    net.Send(client)

    -- Clear the character netvar and spawn
    client:SetNetVar("char", nil)
    client:Spawn()
end)

-- ============================================================================
-- SUICIDE EXECUTION
-- ============================================================================

net.Receive("ixSuicideExecute", function(len, client)
    if not IsValid(client) then return end

    local character = client:GetCharacter()
    if not character then return end

    -- Validate weapon
    local weapon = client:GetActiveWeapon()
    if not IsValid(weapon) then return end
    if weapon:GetClass() ~= "tfa_ins2_wpn_38revolver" then return end

    -- Validate ammo (must have at least 1 in clip)
    if weapon:Clip1() < 1 then return end

    -- Consume the bullet
    weapon:SetClip1(weapon:Clip1() - 1)

    -- Play gunshot sound
    client:EmitSound("weapons/357/357_fire2.wav", 100, 100)

    -- Log suicide
    ix.log.Add(client, "suicide", character:GetName())

    -- Apply instant permadeath (bypass knockout)
    local plugin = ix.plugin.Get("permadeath")
    if plugin then
        plugin:ApplyPermadeath(client, character, "suicide")
    end
end)