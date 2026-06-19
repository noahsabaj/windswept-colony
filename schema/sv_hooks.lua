--[[
    Windswept Colony RP - Server Hooks
]]--

-- ============================================================================
-- LOG TYPES
-- ============================================================================

ws.log.AddType("battering_ram_breach", function(client, doorClass, doorIndex)
	return string.format("%s breached a door (%s #%d) with a battering ram.", client:Name(), doorClass, doorIndex)
end)

-- ============================================================================
-- DOUBLE DOOR SYNC
-- When a player uses a door, sync the action to its partner (double doors)
-- Source Engine's slavename linking doesn't work for dynamically spawned doors
-- ============================================================================

-- Handle double door sync by taking full control of door usage
-- This fires BEFORE the native door use, so we can handle both doors simultaneously
function Schema:CanPlayerUseDoor(client, door)
	if not IsValid(door) then return end

	-- Get the partner door (double doors are linked via wsPartner)
	local partner = door:GetDoorPartner()

	-- Single door - let native handling work
	if not IsValid(partner) then return end

	-- Double door - we handle it ourselves for perfect sync
	-- Check current door state
	-- m_eDoorState: 0=closed, 1=opening, 2=open, 3=closing
	local doorState = door:GetInternalVariable("m_eDoorState")

	-- If we can't determine door state, let native handling work
	if doorState == nil then return end

	if doorState == 0 then
		-- Both doors closed - open both away from player
		local tempTarget = ents.Create("info_target")
		if IsValid(tempTarget) then
			tempTarget:SetPos(client:GetPos())
			tempTarget:SetName("ix_door_activator_" .. client:EntIndex())
			tempTarget:Spawn()

			-- Fire OpenAwayFrom on BOTH doors simultaneously
			door:Fire("OpenAwayFrom", tempTarget:GetName())
			partner:Fire("OpenAwayFrom", tempTarget:GetName())

			-- Remove temp entity after doors start opening
			timer.Simple(0.1, function()
				if IsValid(tempTarget) then
					tempTarget:Remove()
				end
			end)
		else
			-- Fallback: just fire open on both
			door:Fire("open")
			partner:Fire("open")
		end
	elseif doorState == 2 then
		-- Both doors open - close both
		door:Fire("close")
		partner:Fire("close")
	elseif doorState == 1 or doorState == 3 then
		-- Door is in motion (opening or closing) - ignore
		return false
	end

	-- Return false to PREVENT native door use - we handled it ourselves
	return false
end

-- ============================================================================
-- LADDER INTEGRATION
-- ============================================================================

-- When a player receives weapon_ladder_yl (from picking up deployed ladder),
-- create an inventory item instead of just having the weapon
function Schema:WeaponEquip(weapon, client)
    if not IsValid(weapon) or weapon:GetClass() ~= "weapon_ladder_yl" then return end
    if not IsValid(client) then return end

    local character = client:GetCharacter()
    if not character then return end

    -- If they already have an equipped ladder item, it's from our Equip function
    if client.wsLadderItem and client.wsLadderItem:GetData("equipped") then
        return
    end

    -- They picked up a ladder from the world - add to inventory
    local inventory = character:GetInventory()
    if not inventory then return end

    -- Try to add ladder item to inventory
    local canFit = inventory:FindEmptySlot(4, 4) -- ladder is 4x4
    if canFit then
        inventory:Add("ladder", 1, {equipped = true})

        -- Find the item we just added and link it
        timer.Simple(0.1, function()
            if not IsValid(client) then return end
            for _, item in pairs(inventory:GetItems()) do
                if item.uniqueID == "ladder" and item:GetData("equipped") and not item.linkedToWeapon then
                    item.linkedToWeapon = true
                    client.wsLadderItem = item
                    -- Register for efficient ladder tracking
                    Schema.equippedLadderPlayers[client] = true
                    if IsValid(weapon) then
                        weapon.wsItem = item
                    end
                    break
                end
            end
        end)
    else
        -- No room in inventory - drop the weapon as entity
        client:StripWeapon("weapon_ladder_yl")
        client:NotifyLocalized("ladderNoRoom")
    end
end

-- Track players with equipped ladders for efficient checking
-- (avoids iterating ALL players every 0.5s)
Schema.equippedLadderPlayers = Schema.equippedLadderPlayers or {}

-- Monitor equipped ladder items - if weapon disappears, item was deployed
timer.Create("wsLadderDeployCheck", 0.5, 0, function()
    for client, _ in pairs(Schema.equippedLadderPlayers) do
        if not IsValid(client) then
            Schema.equippedLadderPlayers[client] = nil
        else
            local item = client.wsLadderItem
            if item and item:GetData("equipped") then
                -- Item is marked as equipped but check if weapon still exists
                if not client:HasWeapon("weapon_ladder_yl") then
                    -- Weapon was stripped (ladder deployed) - remove item from inventory
                    local character = client:GetCharacter()
                    if character then
                        local inventory = character:GetInventory()
                        if inventory then
                            inventory:Remove(item:GetID())
                        end
                    end
                    client.wsLadderItem = nil
                    Schema.equippedLadderPlayers[client] = nil
                end
            else
                -- No longer has equipped ladder item
                Schema.equippedLadderPlayers[client] = nil
            end
        end
    end
end)

-- ============================================================================
-- CHARACTER CREATION
-- ============================================================================

-- Generate physical description from structured attributes during character creation
function Schema:AdjustCreationPayload(client, payload, newPayload)
    -- Get physical attribute values from payload
    local age = tonumber(payload.physAge) or 25
    local height = tonumber(payload.physHeight) or 170
    local weight = tonumber(payload.physWeight) or 160
    local skinTone = payload.physSkinTone or "Medium"
    local hairColor = payload.physHairColor or "Brown"
    local hairType = payload.physHairType or "Straight"
    local hairLength = payload.physHairLength or "Medium"
    local eyeColor = payload.physEyeColor or "Brown"
    local facialHair = payload.physFacialHair or "None"

    -- Get the model path for gender detection
    -- Helix's model OnAdjust already sets newPayload.model to the actual path
    local modelPath = newPayload.model

    -- Calculate build from height and weight
    local build, bmi = ws.physical.CalculateBuild(height, weight)

    -- Get birth data
    local birthMonth = tonumber(payload.physBirthMonth) or 1
    local birthDay = tonumber(payload.physBirthDay) or 1
    local birthLocation = payload.physBirthLocation or "Unspecified"

    -- Build the physical data table
    local physicalData = {
        age = age,
        height = height,
        weight = weight,
        build = build,
        bmi = bmi,
        skinTone = skinTone,
        hairColor = hairColor,
        hairType = hairType,
        hairLength = hairLength,
        eyeColor = eyeColor,
        facialHair = facialHair,
        model = modelPath,
        birthMonth = birthMonth,
        birthDay = birthDay,
        birthLocation = birthLocation
    }

    -- Generate the description
    local description = ws.physical.GenerateDescription(physicalData)

    -- Set the generated description
    newPayload.description = description

    -- Store the physical data on the character for Personal ID and other uses
    newPayload.data = newPayload.data or {}
    newPayload.data.physical = physicalData
end

-- ============================================================================
-- WALLET-AWARE MONEY PICKUP
-- ============================================================================

-- Override money entity pickup to use wallet routing
ws.currency.HandlePickup = function(client, entity)
    if not IsValid(client) or not IsValid(entity) then return end

    local amount = entity:GetAmount() -- This is in dollars
    local cents = amount * 100

    -- Use wallet-aware routing
    if ws.currency.AddToInventoryWithWallet(client, cents) then
        entity:Remove()

        -- Play pickup sound
        client:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 75, 100, 0.5)
    else
        client:NotifyLocalized("inventoryFull")
    end
end

-- ============================================================================
-- RADIO VOICE SYSTEM
-- ============================================================================

-- Track who is currently transmitting on radio
Schema.radioTransmitters = Schema.radioTransmitters or {}

-- Voice distance scaling uses ws.constants.RANGE_EAVESDROP_BASE

-- ============================================================================
-- ENTITY CACHING FOR VOICE SYSTEM PERFORMANCE
-- Cache radio-related entities to avoid ents.FindByClass() in voice hooks
-- ============================================================================

Schema.entityCache = Schema.entityCache or {
    ragdolls = {},           -- prop_ragdoll entities
    knockedBodies = {},      -- ix_knocked entities
    stationaryRadios = {},   -- ix_stationary_radio entities
}

-- Helper to add entity to cache
local function CacheEntity(ent, cacheTable)
    cacheTable[ent] = true
end

-- Helper to remove entity from cache
local function UncacheEntity(ent, cacheTable)
    cacheTable[ent] = nil
end

-- Cache entities on creation
hook.Add("OnEntityCreated", "wsRadioEntityCache", function(ent)
    if not IsValid(ent) then return end

    -- Delay slightly to ensure entity is fully initialized
    timer.Simple(0, function()
        if not IsValid(ent) then return end

        local class = ent:GetClass()
        if class == "prop_ragdoll" then
            CacheEntity(ent, Schema.entityCache.ragdolls)
        elseif class == "ix_knocked" then
            CacheEntity(ent, Schema.entityCache.knockedBodies)
        elseif class == "ix_stationary_radio" then
            CacheEntity(ent, Schema.entityCache.stationaryRadios)
        end
    end)
end)

-- Remove entities from cache on removal
hook.Add("EntityRemoved", "wsRadioEntityUncache", function(ent)
    if not ent then return end

    -- Remove from all caches (cheaper than checking class)
    Schema.entityCache.ragdolls[ent] = nil
    Schema.entityCache.knockedBodies[ent] = nil
    Schema.entityCache.stationaryRadios[ent] = nil
end)

-- Rebuild cache on map cleanup (fallback safety)
hook.Add("PostCleanupMap", "wsRadioEntityCacheRebuild", function()
    Schema.entityCache.ragdolls = {}
    Schema.entityCache.knockedBodies = {}
    Schema.entityCache.stationaryRadios = {}

    -- Repopulate caches
    for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
        CacheEntity(ent, Schema.entityCache.ragdolls)
    end
    for _, ent in ipairs(ents.FindByClass("ix_knocked")) do
        CacheEntity(ent, Schema.entityCache.knockedBodies)
    end
    for _, ent in ipairs(ents.FindByClass("ix_stationary_radio")) do
        CacheEntity(ent, Schema.entityCache.stationaryRadios)
    end
end)

-- Initialize caches on server start
hook.Add("InitPostEntity", "wsRadioEntityCacheInit", function()
    timer.Simple(1, function()
        for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
            CacheEntity(ent, Schema.entityCache.ragdolls)
        end
        for _, ent in ipairs(ents.FindByClass("ix_knocked")) do
            CacheEntity(ent, Schema.entityCache.knockedBodies)
        end
        for _, ent in ipairs(ents.FindByClass("ix_stationary_radio")) do
            CacheEntity(ent, Schema.entityCache.stationaryRadios)
        end
    end)
end)

-- Get player's active radio item
local function GetActiveRadio(client)
    if not IsValid(client) then return nil end

    local character = client:GetCharacter()
    if not character then return nil end

    -- Quick check using cached flag
    if not character:GetData("ixHasActiveRadio") then return nil end

    local inventory = character:GetInventory()
    if not inventory then return nil end

    local radios = inventory:GetItemsByUniqueID("handheld_radio", true)
    for _, radio in ipairs(radios) do
        if radio:GetData("enabled") and radio:CanOperate() then
            return radio
        end
    end

    return nil
end

-- Get radio on a ragdoll entity (dead player)
local function GetRagdollRadio(ragdoll)
    if not IsValid(ragdoll) then return nil end

    -- Check if this is a Helix ragdoll with inventory
    local charID = ragdoll.wsCharID
    if not charID then return nil end

    -- Find inventory by character ID
    for _, inv in pairs(ws.item.inventories) do
        if inv:GetOwner() == charID then
            local radios = inv:GetItemsByUniqueID("handheld_radio", true)
            for _, radio in ipairs(radios) do
                if radio:GetData("enabled") and radio:CanOperate() then
                    return radio
                end
            end
            break
        end
    end

    return nil
end

-- Net receiver: Player started transmitting
net.Receive("wsRadioVoiceStart", function(len, client)
    if not IsValid(client) then return end

    -- Check player can transmit
    if not client:Alive() then return end
    if client:GetNetVar("wsKnocked") then return end
    if client:GetNetVar("gagged") then return end
    if client:GetNetVar("wsRestricted") then return end

    local radio = GetActiveRadio(client)
    if not radio then return end

    -- Store transmission state
    Schema.radioTransmitters[client] = {
        frequency = radio:GetData("frequency", "100.0"),
        startTime = CurTime(),
        radio = radio
    }
end)

-- Net receiver: Player stopped transmitting
net.Receive("wsRadioVoiceStop", function(len, client)
    if not IsValid(client) then return end

    local txData = Schema.radioTransmitters[client]
    if txData then
        -- Calculate transmission duration and drain battery
        local duration = CurTime() - txData.startTime
        if txData.radio and duration > 0 then
            txData.radio:DrainActive(duration)
        end

        Schema.radioTransmitters[client] = nil
    end
end)

-- Net receiver: Set radio volume
net.Receive("wsRadioVolumeSet", function(len, client)
    if not IsValid(client) then return end

    local itemID = net.ReadUInt(32)
    local volume = net.ReadUInt(7)

    local item = ws.item.instances[itemID]
    if not item or item.uniqueID ~= "handheld_radio" then return end

    -- Verify ownership
    local character, inventory = ws.constants.GetCharacterInventory(client)
    if not character or not inventory then return end

    if item.invID ~= inventory:GetID() then return end

    -- Set volume
    item:SetData("volume", math.Clamp(volume, 0, 100))
    client:NotifyLocalized("radioVolumeSet", volume)
end)

-- Clean up transmitter on disconnect
hook.Add("PlayerDisconnected", "wsRadioTransmitCleanup", function(client)
    Schema.radioTransmitters[client] = nil
end)

-- Drain battery for voice receivers (runs every second while transmissions are active)
timer.Create("wsRadioVoiceReceiverDrain", 1, 0, function()
    -- Skip if no active transmitters
    if table.IsEmpty(Schema.radioTransmitters) then return end

    -- For each frequency being transmitted on, find all receivers and drain their batteries
    local frequencyDrained = {}  -- Track which player+frequency combos we've drained

    for transmitter, txData in pairs(Schema.radioTransmitters) do
        if not IsValid(transmitter) then
            Schema.radioTransmitters[transmitter] = nil
            continue
        end

        local frequency = txData.frequency

        -- Find all receivers on this frequency
        for _, ply in ipairs(player.GetAll()) do
            if ply == transmitter then continue end

            local drainKey = ply:SteamID64() .. "_" .. frequency
            if frequencyDrained[drainKey] then continue end  -- Already drained this player for this frequency

            local radio = GetActiveRadio(ply)
            if radio and radio:GetData("frequency", "100.0") == frequency then
                -- Drain 1 second of active usage
                radio:DrainActive(1)
                frequencyDrained[drainKey] = true
            end
        end
    end
end)

-- ============================================================================
-- VOICE SYSTEM OVERRIDE
-- Handles: radio transmission, amplitude-based distance, eavesdropping
-- ============================================================================

-- Store voice amplitude per player for distance calculations
Schema.voiceAmplitudes = Schema.voiceAmplitudes or {}

-- Track voice amplitude when player speaks
hook.Add("PlayerStartVoice", "wsTrackVoiceAmplitude", function(client)
    -- Reset amplitude tracking
    Schema.voiceAmplitudes[client] = 0.5  -- Default to medium
end)

-- Receive amplitude from client (VoiceVolume() is CLIENT-only)
net.Receive("wsVoiceAmplitude", function(len, client)
    if not IsValid(client) then return end

    local amp = net.ReadFloat()
    -- Clamp to valid range
    amp = math.Clamp(amp, 0, 1)
    Schema.voiceAmplitudes[client] = amp
end)

-- Helper: Check if speaker is within voice range of a position (for stationary radio pickup)
local function IsSpeakerInRangeOfPosition(speaker, pos, speakerAmplitude)
    local voiceRange = 100 + (speakerAmplitude * 700)
    local distSqr = speaker:GetPos():DistToSqr(pos)
    return distSqr <= (voiceRange * voiceRange)
end

-- Helper: Get all frequencies a speaker is being broadcast on (via stationary radios)
local function GetStationaryRadioBroadcastFrequencies(speaker, speakerAmplitude)
    local frequencies = {}

    for source, txData in pairs(Schema.radioTransmitters) do
        if txData.isStationary and IsValid(txData.entity) then
            -- Check if speaker is within voice range of the stationary radio
            if IsSpeakerInRangeOfPosition(speaker, txData.entity:GetPos(), speakerAmplitude) then
                -- Add all TX frequencies from this stationary radio
                for freq, _ in pairs(txData.frequencies) do
                    frequencies[freq] = txData.entity
                end
            end
        end
    end

    return frequencies
end

-- Helper: Check if listener is at a stationary radio receiving on any of these frequencies
local function IsListenerAtStationaryRadioReceiving(listener, frequencies)
    for source, txData in pairs(Schema.radioTransmitters) do
        if txData.isStationary and IsValid(txData.entity) and txData.user == listener then
            -- Listener is at this stationary radio - check RX frequencies
            local rxFreqs = txData.entity:GetRXFrequencies()
            for freq, volume in pairs(rxFreqs) do
                if frequencies[freq] then
                    return true, volume
                end
            end
        end
    end
    return false, 0
end

-- Main voice hearing logic
function Schema:PlayerCanHearPlayersVoice(listener, speaker)
    if not IsValid(listener) or not IsValid(speaker) then return false, false end
    if listener == speaker then return true, false end  -- Always hear yourself

    -- Dead players can't speak
    if not speaker:Alive() then return false, false end

    -- Get speaker's current voice amplitude
    local speakerAmplitude = Schema.voiceAmplitudes[speaker] or 0.5

    -- Check if speaker is transmitting on handheld radio
    local txData = Schema.radioTransmitters[speaker]
    local handheldFrequency = nil

    if txData and not txData.isStationary then
        -- Speaker is transmitting on handheld radio
        handheldFrequency = txData.frequency
    end

    -- Check if speaker is being picked up by any stationary radios with MIC on
    local stationaryFrequencies = GetStationaryRadioBroadcastFrequencies(speaker, speakerAmplitude)

    -- Combine all frequencies speaker is being broadcast on
    local allBroadcastFrequencies = {}
    if handheldFrequency then
        allBroadcastFrequencies[handheldFrequency] = true
    end
    for freq, _ in pairs(stationaryFrequencies) do
        allBroadcastFrequencies[freq] = true
    end

    -- If speaker is being broadcast on any frequency, check if listener can receive
    if not table.IsEmpty(allBroadcastFrequencies) then
        -- Check if listener has handheld radio on any broadcast frequency
        local listenerRadio = GetActiveRadio(listener)
        if listenerRadio then
            local listenerFreq = listenerRadio:GetData("frequency", "100.0")
            if allBroadcastFrequencies[listenerFreq] then
                return true, false  -- Direct radio reception
            end
        end

        -- Check if listener is at a stationary radio receiving on any broadcast frequency
        local atStationary, volume = IsListenerAtStationaryRadioReceiving(listener, allBroadcastFrequencies)
        if atStationary then
            return true, false  -- Receiving via stationary radio
        end

        -- Check eavesdropping: listener is near someone/something with a receiving radio
        local listenerPos = listener:GetPos()
        local closestReceiverDist = math.huge
        local closestReceiverVolume = 0

        -- Check living players with handheld radios
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= speaker and ply ~= listener then
                local radio = GetActiveRadio(ply)
                if radio then
                    local radioFreq = radio:GetData("frequency", "100.0")
                    if allBroadcastFrequencies[radioFreq] then
                        local dist = listenerPos:Distance(ply:GetPos())
                        if dist < closestReceiverDist then
                            closestReceiverDist = dist
                            closestReceiverVolume = radio:GetData("volume", 50) / 100
                        end
                    end
                end
            end
        end

        -- Check ragdolls (knocked/dead) - uses cached entities
        for ent, _ in pairs(Schema.entityCache.ragdolls) do
            if IsValid(ent) then
                local radio = GetRagdollRadio(ent)
                if radio then
                    local radioFreq = radio:GetData("frequency", "100.0")
                    if allBroadcastFrequencies[radioFreq] then
                        local dist = listenerPos:Distance(ent:GetPos())
                        if dist < closestReceiverDist then
                            closestReceiverDist = dist
                            closestReceiverVolume = radio:GetData("volume", 50) / 100
                        end
                    end
                end
            end
        end

        -- Check ix_knocked entities - uses cached entities
        for ent, _ in pairs(Schema.entityCache.knockedBodies) do
            if IsValid(ent) and ent.GetInventory then
                local inv = ent:GetInventory()
                if inv then
                    local radios = inv:GetItemsByUniqueID("handheld_radio", true)
                    for _, radio in ipairs(radios) do
                        if radio:GetData("enabled") and radio:CanOperate() then
                            local radioFreq = radio:GetData("frequency", "100.0")
                            if allBroadcastFrequencies[radioFreq] then
                                local dist = listenerPos:Distance(ent:GetPos())
                                if dist < closestReceiverDist then
                                    closestReceiverDist = dist
                                    closestReceiverVolume = radio:GetData("volume", 50) / 100
                                end
                                break
                            end
                        end
                    end
                end
            end
        end

        -- Check stationary radios (eavesdrop from their speaker) - uses cached entities
        for ent, _ in pairs(Schema.entityCache.stationaryRadios) do
            if IsValid(ent) then
                local rxFreqs = ent:GetRXFrequencies()
                for freq, volume in pairs(rxFreqs) do
                    if allBroadcastFrequencies[freq] then
                        local dist = listenerPos:Distance(ent:GetPos())
                        if dist < closestReceiverDist then
                            closestReceiverDist = dist
                            closestReceiverVolume = volume / 100
                        end
                    end
                end
            end
        end

        -- Calculate eavesdrop range: base * receiver_volume * transmitter_amplitude
        local eavesdropRange = ws.constants.RANGE_EAVESDROP_BASE * closestReceiverVolume * speakerAmplitude

        if closestReceiverDist < eavesdropRange then
            return true, false  -- Can hear via eavesdrop
        end

        -- If speaker was ONLY broadcasting via radio (not also speaking locally), stop here
        if handheldFrequency then
            return false, false
        end
    end

    -- Normal proximity voice with amplitude scaling
    local listenerPos = listener:EyePos()
    local speakerPos = speaker:EyePos()
    local distance = listenerPos:Distance(speakerPos)

    -- Scale voice range by amplitude
    -- Whisper (0.0-0.2): 100-200 units
    -- Normal (0.2-0.5): 200-400 units
    -- Loud (0.5-0.8): 400-600 units
    -- Yelling (0.8-1.0): 600-800 units
    local voiceRange = 100 + (speakerAmplitude * 700)

    if distance <= voiceRange then
        return true, false
    end

    return false, false
end
