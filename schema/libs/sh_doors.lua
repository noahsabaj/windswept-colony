--[[
    Door Frame Management Library

    Handles:
    - Detection and hiding of map doors
    - Spawning prop_door_rotating entities with original models
    - Frame data persistence
    - Door type auto-detection from map models

    Uses native prop_door_rotating for:
    - Correct original door models
    - Native door handle animation
    - Native open/close sounds
    - Native physics behavior
]]--

ix.doors = ix.doors or {}
ix.doors.frames = ix.doors.frames or {}

-- Door type configurations (for health/damage, not models)
ix.doors.typeConfig = {
    wood = {
        maxHealth = 100,
        ramResistance = 1.0,
        fistDamageable = true,
        material = "wood"
    },
    metal = {
        maxHealth = 250,
        ramResistance = 0.4,
        fistDamageable = false,
        material = "metal"
    },
    gate = {
        maxHealth = 175,
        ramResistance = 0.65,
        fistDamageable = false,
        material = "metal"
    }
}

-- Model path patterns to detect door types
ix.doors.modelPatterns = {
    wood = {
        "door01",
        "door02",
        "wooddoor",
        "door_wood",
        "apartment_door"
    },
    metal = {
        "door03",
        "metaldoor",
        "door_metal",
        "security",
        "industrial"
    },
    gate = {
        "gate",
        "fence",
        "barrier"
    }
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Detect door type from model path
function ix.doors.DetectTypeFromModel(model)
    model = string.lower(model or "")

    for doorType, patterns in pairs(ix.doors.modelPatterns) do
        for _, pattern in ipairs(patterns) do
            if string.find(model, pattern) then
                return doorType
            end
        end
    end

    return "wood"  -- Default to wood
end

-- Check if an entity is a valid door
function ix.doors.IsDoor(ent)
    if not IsValid(ent) then return false end
    return ent:IsDoor()
end

-- Check if a door is fully closed (not open or in motion)
-- prop_door_rotating uses m_eDoorState: 0=closed, 1=opening, 2=open, 3=closing
function ix.doors.IsDoorClosed(door)
    if not IsValid(door) then return false end

    local doorState = door:GetInternalVariable("m_eDoorState")
    return doorState == 0  -- DOOR_STATE_CLOSED
end

-- Check if a door is open or ajar (not fully closed)
function ix.doors.IsDoorOpen(door)
    return not ix.doors.IsDoorClosed(door)
end

-- ============================================================================
-- SERVER: Frame Detection & Management
-- ============================================================================

if SERVER then
    -- Capture all visual properties from an entity
    function ix.doors.CaptureVisualData(ent)
        local data = {
            model = ent:GetModel() or "",
            skin = ent:GetSkin() or 0,
            color = ent:GetColor(),
            material = ent:GetMaterial() or "",
            renderMode = ent:GetRenderMode(),
        }

        -- Capture submaterials (per-part texture overrides)
        local materials = ent:GetMaterials()
        if istable(materials) then
            data.subMaterials = {}
            for k, _ in pairs(materials) do
                local subMat = ent:GetSubMaterial(k - 1)
                if subMat and subMat ~= "" then
                    data.subMaterials[k] = subMat
                end
            end
            if table.IsEmpty(data.subMaterials) then
                data.subMaterials = nil
            end
        end

        -- Capture bodygroups (visible variants of multi-part models)
        local bodyGroups = ent:GetBodyGroups()
        if istable(bodyGroups) then
            data.bodyGroups = {}
            for _, v in pairs(bodyGroups) do
                local bgValue = ent:GetBodygroup(v.id)
                if bgValue and bgValue > 0 then
                    data.bodyGroups[v.id] = bgValue
                end
            end
            if table.IsEmpty(data.bodyGroups) then
                data.bodyGroups = nil
            end
        end

        return data
    end

    -- Capture door-specific keyvalues from a prop_door_rotating
    function ix.doors.CaptureDoorKeyvalues(ent)
        local keyvalues = {}

        -- Get all keyvalues from the entity
        local allKV = ent:GetKeyValues()

        -- Door identity (critical for double door master/slave relationships)
        if allKV.targetname and allKV.targetname ~= "" then
            keyvalues.targetname = allKV.targetname
        end

        -- Slave door link (makes double doors open/close together)
        if allKV.slavename and allKV.slavename ~= "" then
            keyvalues.slavename = allKV.slavename
        end

        -- Hardware type (0=none, 1=lever/handle, 2=push bar, 3=keypad)
        -- This is CRITICAL for door handles to appear
        if allKV.hardware then
            keyvalues.hardware = allKV.hardware
        end

        -- Spawn flags
        local spawnFlags = ent:GetSpawnFlags()
        if spawnFlags and spawnFlags > 0 then
            keyvalues.spawnflags = spawnFlags
        end

        -- Door rotation settings
        if allKV.distance then
            keyvalues.distance = allKV.distance
        end

        if allKV.speed then
            keyvalues.speed = allKV.speed
        end

        -- Return delay (-1 = never auto-close)
        if allKV.returndelay then
            keyvalues.returndelay = allKV.returndelay
        end

        -- Open direction
        if allKV.opendir then
            keyvalues.opendir = allKV.opendir
        end

        -- Sound overrides
        if allKV.soundopenoverride and allKV.soundopenoverride ~= "" then
            keyvalues.soundopenoverride = allKV.soundopenoverride
        end

        if allKV.soundcloseoverride and allKV.soundcloseoverride ~= "" then
            keyvalues.soundcloseoverride = allKV.soundcloseoverride
        end

        if allKV.soundmoveoverride and allKV.soundmoveoverride ~= "" then
            keyvalues.soundmoveoverride = allKV.soundmoveoverride
        end

        if allKV.soundlockedoverride and allKV.soundlockedoverride ~= "" then
            keyvalues.soundlockedoverride = allKV.soundlockedoverride
        end

        if allKV.soundunlockedoverride and allKV.soundunlockedoverride ~= "" then
            keyvalues.soundunlockedoverride = allKV.soundunlockedoverride
        end

        return keyvalues
    end

    -- Apply visual data to an entity
    function ix.doors.ApplyVisualData(ent, visualData)
        if not IsValid(ent) or not visualData then return end

        -- Apply skin
        if visualData.skin then
            ent:SetSkin(visualData.skin)
        end

        -- Apply color
        if visualData.color then
            ent:SetColor(visualData.color)
        end

        -- Apply material override
        if visualData.material and visualData.material ~= "" then
            ent:SetMaterial(visualData.material)
        end

        -- Apply render mode
        if visualData.renderMode then
            ent:SetRenderMode(visualData.renderMode)
        end

        -- Apply submaterials
        if visualData.subMaterials then
            for k, subMat in pairs(visualData.subMaterials) do
                ent:SetSubMaterial(k - 1, subMat)
            end
        end

        -- Apply bodygroups
        if visualData.bodyGroups then
            for bgID, bgValue in pairs(visualData.bodyGroups) do
                ent:SetBodygroup(bgID, bgValue)
            end
        end
    end

    -- Detect all map doors and create frame data
    function ix.doors.DetectFrames()
        ix.doors.frames = {}
        local skippedBrush = 0

        for _, ent in ipairs(ents.GetAll()) do
            if ix.doors.IsDoor(ent) then
                local mapID = ent:MapCreationID()
                if mapID and mapID > 0 then
                    local model = ent:GetModel() or ""

                    -- Skip brush-based doors (func_door, func_door_rotating)
                    -- These have models like "*90", "*57" - BSP brush references
                    -- We can only replace prop_door_rotating which use actual model files
                    if string.sub(model, 1, 1) == "*" then
                        skippedBrush = skippedBrush + 1
                        continue
                    end

                    local defaultType = ix.doors.DetectTypeFromModel(model)

                    -- Capture all visual properties from the map door
                    local visualData = ix.doors.CaptureVisualData(ent)

                    -- Capture door-specific keyvalues (hardware, sounds, etc.)
                    local keyvalues = ix.doors.CaptureDoorKeyvalues(ent)

                    ix.doors.frames[mapID] = {
                        pos = ent:GetPos(),
                        ang = ent:GetAngles(),
                        originalModel = model,
                        defaultType = defaultType,
                        visualData = visualData,  -- Store all visual properties
                        keyvalues = keyvalues,    -- Store door keyvalues (hardware, sounds, etc.)
                        disabled = false,
                        hasDoor = false,
                        doorEntity = nil,
                        mapEntity = ent
                    }
                end
            end
        end

    end

    -- Hide all map doors (make them invisible and non-solid)
    function ix.doors.HideMapDoors()
        for mapID, frameData in pairs(ix.doors.frames) do
            local mapDoor = frameData.mapEntity

            if IsValid(mapDoor) then
                mapDoor:SetNoDraw(true)
                mapDoor:SetNotSolid(true)
                mapDoor:Fire("unlock")  -- Prevent "locked door" sounds
                mapDoor:Fire("open")    -- Ensure door is open (no collision)
            end
        end

    end

    -- Sync frame data to a client
    function ix.doors.SyncToPlayer(ply)
        local count = table.Count(ix.doors.frames)
        if count == 0 then return end

        net.Start("ixDoorsSync")
            net.WriteUInt(count, 16)
            for mapID, frameData in pairs(ix.doors.frames) do
                net.WriteUInt(mapID, 32)
                net.WriteVector(frameData.pos)
                net.WriteAngle(frameData.ang)
                net.WriteBool(frameData.hasDoor or false)
                net.WriteBool(frameData.disabled or false)
            end
        net.Send(ply)
    end

    -- Sync frame data to all clients
    function ix.doors.SyncToAll()
        local count = table.Count(ix.doors.frames)
        if count == 0 then return end

        net.Start("ixDoorsSync")
            net.WriteUInt(count, 16)
            for mapID, frameData in pairs(ix.doors.frames) do
                net.WriteUInt(mapID, 32)
                net.WriteVector(frameData.pos)
                net.WriteAngle(frameData.ang)
                net.WriteBool(frameData.hasDoor or false)
                net.WriteBool(frameData.disabled or false)
            end
        net.Broadcast()
    end

    -- Sync when player joins
    hook.Add("PlayerInitialSpawn", "ixDoorsSyncOnJoin", function(ply)
        -- Delay to ensure everything is loaded
        timer.Simple(3, function()
            if IsValid(ply) then
                ix.doors.SyncToPlayer(ply)
            end
        end)
    end)

    -- Spawn a prop_door_rotating at a frame using the original model
    function ix.doors.SpawnDoor(mapID, doorData)
        local frameData = ix.doors.frames[mapID]
        if not frameData then return nil end
        if frameData.disabled then return nil end
        if frameData.hasDoor then return nil end

        -- Create native prop_door_rotating
        local door = ents.Create("prop_door_rotating")
        if not IsValid(door) then return nil end

        door:SetPos(frameData.pos)
        door:SetAngles(frameData.ang)
        door:SetModel(frameData.originalModel)  -- Use ORIGINAL map model

        -- Apply keyvalues BEFORE spawning (critical for hardware/handle type)
        if frameData.keyvalues then
            for key, value in pairs(frameData.keyvalues) do
                door:SetKeyValue(key, tostring(value))
            end
        end

        door:Spawn()
        door:Activate()

        -- Apply all visual properties from the original map door (skin, color, bodygroups, etc.)
        if frameData.visualData then
            ix.doors.ApplyVisualData(door, frameData.visualData)
        end

        -- Initialize physics as static
        local phys = door:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end

        -- Store custom data on the entity
        door.ixFrameID = tostring(mapID)
        door.ixDoorType = frameData.defaultType
        door.ixIsWindsweptDoor = true  -- Mark as our managed door

        -- Apply saved data or defaults
        if doorData then
            door.ixHealth = doorData.health or ix.doors.typeConfig[frameData.defaultType].maxHealth
            door.ixMaxHealth = doorData.maxHealth or ix.doors.typeConfig[frameData.defaultType].maxHealth
            door.ixLockData = doorData.lockData
            if doorData.locked and door.ixLockData then
                door:Fire("lock")
            end
            -- Restore battering ram damage (persists until repaired)
            door.ixBatteringRamRequired = doorData.ramRequired
            door.ixBatteringRamHits = doorData.ramHits
        else
            -- Default: full health, no lock, no damage
            local config = ix.doors.typeConfig[frameData.defaultType]
            door.ixHealth = config.maxHealth
            door.ixMaxHealth = config.maxHealth
            door.ixLockData = nil
            door.ixBatteringRamRequired = nil
            door.ixBatteringRamHits = nil
        end

        -- Update frame
        frameData.hasDoor = true
        frameData.doorEntity = door

        -- Sync to clients
        ix.doors.SyncToAll()

        return door
    end

    -- Get door's type config
    function ix.doors.GetTypeConfig(door)
        if not IsValid(door) then return ix.doors.typeConfig.wood end
        local doorType = door.ixDoorType or "wood"
        return ix.doors.typeConfig[doorType] or ix.doors.typeConfig.wood
    end

    -- Check if a door has a lock installed
    function ix.doors.HasLock(door)
        if not IsValid(door) then return false end
        return door.ixLockData ~= nil
    end

    -- Get lock keyings from a door
    function ix.doors.GetLockKeyings(door)
        if not IsValid(door) or not door.ixLockData then return {} end
        return door.ixLockData.keyings or {}
    end

    -- Check if a keying matches the door's lock
    function ix.doors.CheckKeying(door, keying)
        if not IsValid(door) or not door.ixLockData then return false end
        if not keying or keying == "" then return false end

        keying = string.upper(keying)
        for _, lockKeying in ipairs(door.ixLockData.keyings or {}) do
            if string.upper(lockKeying) == keying then
                return true
            end
        end
        return false
    end

    -- Install a lock on a door (syncs to partner for double doors)
    function ix.doors.InstallLock(door, lockData, bIgnorePartner)
        if not IsValid(door) then return false end
        door.ixLockData = lockData

        -- Sync to partner door (double doors share the same lock)
        local partner = door:GetDoorPartner()
        if IsValid(partner) and not bIgnorePartner then
            ix.doors.InstallLock(partner, table.Copy(lockData), true)
        end

        ix.doors.Save()
        return true
    end

    -- Remove lock from a door (syncs to partner for double doors)
    function ix.doors.RemoveLock(door, bIgnorePartner)
        if not IsValid(door) then return nil end
        local lockData = door.ixLockData
        door.ixLockData = nil
        door:Fire("unlock")

        -- Sync to partner door
        local partner = door:GetDoorPartner()
        if IsValid(partner) and not bIgnorePartner then
            ix.doors.RemoveLock(partner, true)
        end

        ix.doors.Save()
        return lockData
    end

    -- Lock a door (syncs to partner for double doors)
    function ix.doors.LockDoor(door, bIgnorePartner)
        if not IsValid(door) then return false end
        if not door.ixLockData then return false end
        if door:IsLocked() then return true end  -- Already locked

        door:Fire("lock")

        -- Sync to partner door
        local partner = door:GetDoorPartner()
        if IsValid(partner) and not bIgnorePartner then
            ix.doors.LockDoor(partner, true)
        end

        return true
    end

    -- Unlock a door (syncs to partner for double doors)
    function ix.doors.UnlockDoor(door, bIgnorePartner)
        if not IsValid(door) then return false end
        if not door.ixLockData then return false end
        if not door:IsLocked() then return true end  -- Already unlocked

        door:Fire("unlock")

        -- Sync to partner door
        local partner = door:GetDoorPartner()
        if IsValid(partner) and not bIgnorePartner then
            ix.doors.UnlockDoor(partner, true)
        end

        return true
    end

    -- Damage a door's lock (syncs to partner for double doors)
    function ix.doors.DamageLock(door, amount, bIgnorePartner)
        if not IsValid(door) or not door.ixLockData then return false end

        door.ixLockData.durability = (door.ixLockData.durability or 100) - amount

        -- Sync damage to partner door
        local partner = door:GetDoorPartner()
        if IsValid(partner) and partner.ixLockData and not bIgnorePartner then
            partner.ixLockData.durability = door.ixLockData.durability
        end

        if door.ixLockData.durability <= 0 then
            -- Lock broken - permanently unlocked on both doors
            door:Fire("unlock")
            door:EmitSound("physics/metal/metal_box_break1.wav", 70)

            if IsValid(partner) and not bIgnorePartner then
                partner.ixLockData = nil
                partner:Fire("unlock")
            end

            door.ixLockData = nil
            ix.doors.Save()
            return true  -- Lock destroyed
        end

        ix.doors.Save()
        return false
    end

    -- Damage a door
    function ix.doors.DamageDoor(door, damage, attacker, inflictor)
        if not IsValid(door) then return end

        local config = ix.doors.GetTypeConfig(door)

        -- Check if fist damage (and if allowed)
        local isFist = IsValid(inflictor) and inflictor:GetClass() == "ix_hands"
        if isFist then
            if not config.fistDamageable then
                if IsValid(attacker) and attacker:IsPlayer() then
                    attacker:NotifyLocalized("doorCantPunch")
                end
                door:EmitSound("physics/metal/metal_solid_impact_hard1.wav", 50)
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
        door.ixHealth = (door.ixHealth or config.maxHealth) - damage

        -- Damage sound
        if config.material == "wood" then
            door:EmitSound("physics/wood/wood_plank_impact_hard" .. math.random(1, 4) .. ".wav", 60)
        else
            door:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 60)
        end

        -- Check for destruction
        if door.ixHealth <= 0 then
            ix.doors.DestroyDoor(door, attacker)
        else
            ix.doors.Save()
        end
    end

    -- Destroy a door
    function ix.doors.DestroyDoor(door, attacker)
        if not IsValid(door) then return end

        local config = ix.doors.GetTypeConfig(door)

        -- Play destruction sound
        if config.material == "wood" then
            door:EmitSound("physics/wood/wood_crate_break" .. math.random(1, 5) .. ".wav", 80)
        else
            door:EmitSound("physics/metal/metal_box_break" .. math.random(1, 2) .. ".wav", 80)
        end

        -- Spawn debris effect
        local effectData = EffectData()
        effectData:SetOrigin(door:GetPos())
        effectData:SetScale(1)
        util.Effect("propspawn", effectData)

        -- Clear frame reference
        local frameID = door.ixFrameID
        if frameID then
            local mapID = tonumber(frameID)
            if mapID and ix.doors.frames[mapID] then
                ix.doors.frames[mapID].hasDoor = false
                ix.doors.frames[mapID].doorEntity = nil
            end
        end

        -- Remove door
        door:Remove()

        -- Sync and save
        ix.doors.SyncToAll()
        ix.doors.Save()
    end

    -- ============================================================================
    -- DOOR BREACH (Battering Ram) - Explosive destruction with debris
    -- ============================================================================

    -- Gib models for debris
    ix.doors.gibs = {
        wood = {
            "models/gibs/wood_gib01a.mdl",
            "models/gibs/wood_gib01b.mdl",
            "models/gibs/wood_gib01c.mdl",
            "models/gibs/wood_gib01d.mdl",
            "models/gibs/wood_gib01e.mdl"
        },
        metal = {
            "models/gibs/metal_gib1.mdl",
            "models/gibs/metal_gib2.mdl",
            "models/gibs/metal_gib3.mdl",
            "models/gibs/metal_gib4.mdl",
            "models/gibs/metal_gib5.mdl"
        }
    }

    -- Spawn debris gibs flying in a direction
    function ix.doors.SpawnDebris(pos, velocity, material, count)
        local gibModels = ix.doors.gibs[material] or ix.doors.gibs.wood
        count = count or 6

        for i = 1, count do
            local gib = ents.Create("prop_physics")
            if not IsValid(gib) then continue end

            gib:SetModel(gibModels[math.random(#gibModels)])
            gib:SetPos(pos + VectorRand() * 20)
            gib:SetAngles(AngleRand())
            gib:Spawn()
            gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

            local phys = gib:GetPhysicsObject()
            if IsValid(phys) then
                -- Add randomized velocity based on blast direction
                local gibVel = velocity + VectorRand() * 150
                gibVel.z = gibVel.z + math.random(50, 150)  -- Add upward force
                phys:SetVelocity(gibVel)
                phys:AddAngleVelocity(VectorRand() * 500)
            end

            -- Gibs fade and remove after a delay
            local fadeTime = math.random(8, 15)
            timer.Simple(fadeTime, function()
                if IsValid(gib) then
                    local alpha = 255
                    local color = gib:GetColor()
                    timer.Create("gibFade" .. gib:EntIndex() .. "_" .. CurTime(), 0.05, 50, function()
                        if IsValid(gib) then
                            alpha = alpha - 5
                            gib:SetColor(ColorAlpha(color, math.max(0, alpha)))
                            if alpha <= 0 then
                                gib:Remove()
                            end
                        end
                    end)
                end
            end)
        end
    end

    -- Spawn dust/debris particle effect
    function ix.doors.SpawnBreachEffect(pos, material)
        -- Dust cloud effect
        local effectData = EffectData()
        effectData:SetOrigin(pos)
        effectData:SetScale(2)
        effectData:SetMagnitude(3)

        if material == "wood" then
            util.Effect("GlassImpact", effectData)
            util.Effect("WheelDust", effectData)
        else
            util.Effect("MetalSpark", effectData)
            util.Effect("cball_bounce", effectData)
        end

        -- Additional debris effect
        effectData:SetScale(1.5)
        util.Effect("propspawn", effectData)
    end

    -- Breach a door with explosive force (battering ram)
    -- PERMANENTLY DESTROYS the door - creates debris, effects, and fading dummy debris
    -- Door frame is left empty until a new door is installed
    function ix.doors.BreachDoor(door, velocity, bIgnorePartner)
        if not IsValid(door) then return end
        if not door:IsDoor() then return end

        velocity = velocity or Vector(0, 0, 0)

        -- Handle partner door (double doors breach together)
        local partner = door:GetDoorPartner()
        if IsValid(partner) and not bIgnorePartner then
            ix.doors.BreachDoor(partner, velocity, true)
        end

        -- Get door properties before destruction
        local pos = door:GetPos()
        local ang = door:GetAngles()
        local model = door:GetModel()
        local color = door:GetColor()
        local doorMaterial = door:GetMaterial()
        local skin = door:GetSkin() or 0
        local config = ix.doors.GetTypeConfig(door)
        local matType = config.material or "wood"
        local frameID = door.ixFrameID

        -- Spawn debris gibs
        ix.doors.SpawnDebris(pos + Vector(0, 0, 40), velocity, matType, math.random(5, 8))

        -- Spawn particle effects
        ix.doors.SpawnBreachEffect(pos + Vector(0, 0, 40), matType)

        -- Create damaged dummy prop (debris flying off - NOT the actual door)
        local dummy = ents.Create("prop_physics")
        if IsValid(dummy) then
            dummy:SetModel(model)
            dummy:SetPos(pos)
            dummy:SetAngles(ang)
            dummy:Spawn()
            dummy:SetSkin(skin)
            dummy:SetMaterial(doorMaterial)
            dummy:SetRenderMode(RENDERMODE_TRANSALPHA)
            dummy:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

            -- Darken the dummy to look damaged/destroyed
            local damagedColor = Color(
                math.max(0, color.r - 80),
                math.max(0, color.g - 80),
                math.max(0, color.b - 80),
                color.a
            )
            dummy:SetColor(damagedColor)

            -- Copy bodygroups
            for _, v in ipairs(door:GetBodyGroups() or {}) do
                dummy:SetBodygroup(v.id, door:GetBodygroup(v.id))
            end

            -- Apply velocity - door flies away from the breach
            local phys = dummy:GetPhysicsObject()
            if IsValid(phys) then
                phys:SetVelocity(velocity)
                phys:AddAngleVelocity(VectorRand() * 150)
            end

            -- Dummy is just debris - fades and disappears after 20-30 seconds
            local fadeDelay = math.random(20, 30)
            timer.Simple(fadeDelay, function()
                if IsValid(dummy) then
                    local fadeAlpha = 255
                    timer.Create("dummyFade" .. dummy:EntIndex(), 0.1, 50, function()
                        if IsValid(dummy) then
                            fadeAlpha = fadeAlpha - 5
                            dummy:SetColor(ColorAlpha(damagedColor, math.max(0, fadeAlpha)))
                            if fadeAlpha <= 0 then
                                dummy:Remove()
                            end
                        end
                    end)
                end
            end)
        end

        -- Clear frame reference - door is DESTROYED, frame is now empty
        if frameID then
            local mapID = tonumber(frameID)
            if mapID and ix.doors.frames[mapID] then
                ix.doors.frames[mapID].hasDoor = false
                ix.doors.frames[mapID].doorEntity = nil
            end
        end

        -- Remove the actual door entity
        door:Remove()

        -- Sync and save - frame is now empty
        ix.doors.SyncToAll()
        ix.doors.Save()

        return dummy
    end

    -- Repair a door to full health (also resets battering ram hit counter)
    function ix.doors.RepairDoor(door)
        if not IsValid(door) then return false end
        local config = ix.doors.GetTypeConfig(door)
        door.ixHealth = config.maxHealth

        -- Reset battering ram damage - door is fully repaired
        door.ixBatteringRamRequired = nil
        door.ixBatteringRamHits = nil

        ix.doors.Save()
        return true
    end

    -- Repair a lock to full durability
    function ix.doors.RepairLock(door)
        if not IsValid(door) or not door.ixLockData then return false end
        door.ixLockData.durability = 100
        ix.doors.Save()
        return true
    end

    -- Remove a door from a frame
    function ix.doors.RemoveDoor(mapID)
        local frameData = ix.doors.frames[mapID]
        if not frameData then return false end

        if IsValid(frameData.doorEntity) then
            frameData.doorEntity:Remove()
        end

        frameData.hasDoor = false
        frameData.doorEntity = nil

        -- Sync to clients
        ix.doors.SyncToAll()

        return true
    end

    -- ============================================================================
    -- PERSISTENCE
    -- ============================================================================

    local SAVE_PATH = "helix/doors/"

    function ix.doors.GetSavePath()
        local mapName = game.GetMap()
        return SAVE_PATH .. mapName .. ".json"
    end

    function ix.doors.Save()
        local data = {
            frames = {},
            doors = {}
        }

        -- Save frame settings
        for mapID, frameData in pairs(ix.doors.frames) do
            data.frames[tostring(mapID)] = {
                disabled = frameData.disabled
            }

            -- Save door data if exists
            if frameData.hasDoor and IsValid(frameData.doorEntity) then
                local door = frameData.doorEntity
                data.doors[tostring(mapID)] = {
                    health = door.ixHealth,
                    maxHealth = door.ixMaxHealth,
                    lockData = door.ixLockData,
                    locked = door:IsLocked(),
                    -- Battering ram damage persists until repaired
                    ramRequired = door.ixBatteringRamRequired,
                    ramHits = door.ixBatteringRamHits
                }
            end
        end

        -- Ensure directory exists
        file.CreateDir(SAVE_PATH)

        -- Save to file
        local json = util.TableToJSON(data, true)
        file.Write(ix.doors.GetSavePath(), json)

    end

    function ix.doors.Load()
        local path = ix.doors.GetSavePath()

        if not file.Exists(path, "DATA") then
            -- First run: bootstrap all frames with default doors
            ix.doors.BootstrapDefaultDoors()
            return
        end

        local json = file.Read(path, "DATA")
        if not json then return end

        local data = util.JSONToTable(json)
        if not data then return end

        -- Apply frame settings
        if data.frames then
            for mapIDStr, frameSettings in pairs(data.frames) do
                local mapID = tonumber(mapIDStr)
                if mapID and ix.doors.frames[mapID] then
                    ix.doors.frames[mapID].disabled = frameSettings.disabled or false
                end
            end
        end

        -- Spawn doors
        if data.doors then
            for mapIDStr, doorData in pairs(data.doors) do
                local mapID = tonumber(mapIDStr)
                if mapID and ix.doors.frames[mapID] and not ix.doors.frames[mapID].hasDoor then
                    ix.doors.SpawnDoor(mapID, doorData)
                end
            end
        end

    end

    -- Bootstrap: spawn default doors for all frames on first run
    function ix.doors.BootstrapDefaultDoors()
        local count = 0
        for mapID, frameData in pairs(ix.doors.frames) do
            if not frameData.disabled and not frameData.hasDoor then
                local door = ix.doors.SpawnDoor(mapID, nil)  -- nil = use default type
                if IsValid(door) then
                    count = count + 1
                end
            end
        end

        -- Save the initial state so next load uses persistence
        ix.doors.Save()
    end

    -- ============================================================================
    -- DOUBLE DOOR PARTNER LINKING
    -- ============================================================================

    -- Link double doors via ixPartner
    -- Uses two methods:
    -- 1. targetname/slavename keyvalues (if mapper set them up)
    -- 2. Proximity detection (doors within 50 units with similar facing angles)
    function ix.doors.LinkPartners()
        local linkedCount = 0
        local linkedByKeyvalue = 0
        local linkedByProximity = 0

        -- First pass: Try keyvalue-based linking (targetname/slavename)
        local byTargetname = {}
        for mapID, frameData in pairs(ix.doors.frames) do
            if frameData.hasDoor and IsValid(frameData.doorEntity) then
                local door = frameData.doorEntity
                local targetname = frameData.keyvalues and frameData.keyvalues.targetname
                if targetname and targetname ~= "" then
                    byTargetname[targetname] = door
                end
            end
        end

        for mapID, frameData in pairs(ix.doors.frames) do
            if frameData.hasDoor and IsValid(frameData.doorEntity) then
                local door = frameData.doorEntity
                local slavename = frameData.keyvalues and frameData.keyvalues.slavename
                if slavename and slavename ~= "" then
                    local partner = byTargetname[slavename]
                    if IsValid(partner) and partner ~= door and not door.ixPartner then
                        door.ixPartner = partner
                        partner.ixPartner = door
                        linkedCount = linkedCount + 1
                        linkedByKeyvalue = linkedByKeyvalue + 1
                    end
                end
            end
        end

        -- Second pass: Proximity-based linking for doors without partners
        -- Two doors are considered a double-door pair if:
        -- 1. They are within 100 units of each other
        -- 2. They use the same model
        local PROXIMITY_THRESHOLD = 100 * 100  -- DistToSqr comparison

        local allDoors = {}
        for mapID, frameData in pairs(ix.doors.frames) do
            if frameData.hasDoor and IsValid(frameData.doorEntity) then
                local door = frameData.doorEntity
                table.insert(allDoors, {
                    door = door,
                    pos = door:GetPos(),
                    model = door:GetModel()
                })
            end
        end

        for i, data1 in ipairs(allDoors) do
            local door1 = data1.door

            -- Skip if already linked
            if door1.ixPartner then continue end

            for j, data2 in ipairs(allDoors) do
                if i == j then continue end

                local door2 = data2.door

                -- Skip if already linked
                if door2.ixPartner then continue end

                -- Check same model
                if data2.model ~= data1.model then continue end

                -- Check proximity
                local distSqr = data1.pos:DistToSqr(data2.pos)
                if distSqr > PROXIMITY_THRESHOLD then continue end

                -- These are double doors!
                door1.ixPartner = door2
                door2.ixPartner = door1
                linkedCount = linkedCount + 1
                linkedByProximity = linkedByProximity + 1
                break  -- Move to next door1
            end
        end

        end
    end

    -- ============================================================================
    -- INITIALIZATION
    -- ============================================================================

    hook.Add("InitPostEntity", "ixDoorsInit", function()
        -- Wait a tick for all entities to spawn
        timer.Simple(0.1, function()
            ix.doors.DetectFrames()
            ix.doors.HideMapDoors()
            ix.doors.Load()

            -- Link double door partners (required for BlastDoor and lock sync)
            ix.doors.LinkPartners()

            -- Sync to all connected players
            timer.Simple(1, function()
                ix.doors.SyncToAll()
            end)
        end)
    end)

    -- Save on map cleanup
    hook.Add("ShutDown", "ixDoorsSave", function()
        ix.doors.Save()
        timer.Remove("ixDoorsAutosave")
    end)

    -- Periodic autosave
    timer.Create("ixDoorsAutosave", 300, 0, function()
        ix.doors.Save()
    end)

    -- ============================================================================
    -- ADMIN COMMANDS
    -- ============================================================================

    ix.command.Add("DoorDisableFrame", {
        description = "Disable a door frame (prevents door installation).",
        adminOnly = true,
        OnRun = function(self, client)
            local tr = client:GetEyeTrace()
            local pos = tr.HitPos

            -- Find nearest frame
            local nearestID = nil
            local nearestDist = 128

            for mapID, frameData in pairs(ix.doors.frames) do
                local dist = pos:Distance(frameData.pos)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestID = mapID
                end
            end

            if not nearestID then
                return "@doorNoFrameNearby"
            end

            ix.doors.frames[nearestID].disabled = true

            -- Remove door if present
            if ix.doors.frames[nearestID].hasDoor then
                ix.doors.RemoveDoor(nearestID)
            end

            ix.doors.Save()
            return "@doorFrameDisabled"
        end
    })

    ix.command.Add("DoorEnableFrame", {
        description = "Enable a previously disabled door frame.",
        adminOnly = true,
        OnRun = function(self, client)
            local tr = client:GetEyeTrace()
            local pos = tr.HitPos

            local nearestID = nil
            local nearestDist = 128

            for mapID, frameData in pairs(ix.doors.frames) do
                local dist = pos:Distance(frameData.pos)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestID = mapID
                end
            end

            if not nearestID then
                return "@doorNoFrameNearby"
            end

            ix.doors.frames[nearestID].disabled = false
            ix.doors.Save()
            return "@doorFrameEnabled"
        end
    })

    ix.command.Add("DoorResetAll", {
        description = "Reset all doors to default state (admin only).",
        adminOnly = true,
        superAdminOnly = true,
        OnRun = function(self, client)
            -- Remove all custom doors
            for mapID, frameData in pairs(ix.doors.frames) do
                if frameData.hasDoor then
                    ix.doors.RemoveDoor(mapID)
                end
                frameData.disabled = false
            end

            -- Delete save file
            if file.Exists(ix.doors.GetSavePath(), "DATA") then
                file.Delete(ix.doors.GetSavePath())
            end

            return "@doorAllReset"
        end
    })
end

-- ============================================================================
-- CLIENT: Frame Visualization
-- ============================================================================

if CLIENT then
    ix.doors.clientFrames = ix.doors.clientFrames or {}

    local FRAME_PULSE_DISTANCE = 240
    local framePulseTime = 0

    -- Receive frame data from server
    net.Receive("ixDoorsSync", function()
        local count = net.ReadUInt(16)
        ix.doors.clientFrames = {}

        for i = 1, count do
            local mapID = net.ReadUInt(32)
            local pos = net.ReadVector()
            local ang = net.ReadAngle()
            local hasDoor = net.ReadBool()
            local disabled = net.ReadBool()

            ix.doors.clientFrames[mapID] = {
                pos = pos,
                ang = ang,
                hasDoor = hasDoor,
                disabled = disabled
            }
        end
    end)

    -- Draw pulsating indicators for empty frames when holding a door
    hook.Add("PostDrawTranslucentRenderables", "ixDoorsFramePulse", function(_, bSkybox)
        if bSkybox then return end

        local ply = LocalPlayer()
        local weapon = ply:GetActiveWeapon()

        if not IsValid(weapon) then return end
        if weapon:GetClass() ~= "ix_door" then return end

        -- Animate pulse
        framePulseTime = framePulseTime + FrameTime() * 3
        local pulse = math.sin(framePulseTime) * 0.5 + 0.5

        -- Draw pulsating effect for empty frames
        for mapID, frameData in pairs(ix.doors.clientFrames) do
            if not frameData.hasDoor and not frameData.disabled then
                local dist = ply:GetPos():Distance(frameData.pos)
                if dist < FRAME_PULSE_DISTANCE then
                    local alpha = 1 - (dist / FRAME_PULSE_DISTANCE)
                    alpha = alpha * pulse * 150

                    -- Draw a pulsating rectangle at the frame position
                    local pos = frameData.pos + Vector(0, 0, 40)

                    render.SetColorMaterial()
                    render.DrawSphere(pos, 16 + pulse * 8, 16, 16, Color(100, 200, 100, alpha))

                    -- Draw vertical line for frame
                    render.DrawLine(frameData.pos, frameData.pos + Vector(0, 0, 80), Color(100, 200, 100, alpha * 0.5), false)
                end
            end
        end
    end)
end
