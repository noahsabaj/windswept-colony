--[[
    Windswept Doors Plugin - Server

    Server-side door management.
]]--

local PLUGIN = PLUGIN

-- ============================================================================
-- DOOR USE HANDLING
-- ============================================================================

-- Hook to handle E key on physical doors
hook.Add("PlayerUse", "wsWindsweptDoorUse", function(client, entity)
    if not IsValid(entity) then return end

    -- Handle our managed doors (prop_door_rotating with wsIsWindsweptDoor marker)
    if entity.wsIsWindsweptDoor then
        -- Native prop_door_rotating handles Use automatically
        return true
    end

    -- Prevent using hidden map doors
    if entity:IsDoor() and entity:GetNoDraw() then
        return false
    end
end)

-- ============================================================================
-- BATTERING RAM INTEGRATION
-- ============================================================================

-- Hook for battering ram and fist damage to managed doors
hook.Add("EntityTakeDamage", "wsWindsweptDoorDamage", function(target, dmgInfo)
    -- Only handle our managed doors
    if not target.wsIsWindsweptDoor then return end

    local inflictor = dmgInfo:GetInflictor()
    local attacker = dmgInfo:GetAttacker()

    -- Check if it's a battering ram
    if IsValid(inflictor) and inflictor:GetClass() == "ix_batteringram" then
        -- Handle damage via our system
        local damage = dmgInfo:GetDamage()
        ws.doors.DamageDoor(target, damage, attacker, inflictor)
        return true  -- Block default damage
    end

    -- Check if it's fists (ix_hands)
    if IsValid(inflictor) and inflictor:GetClass() == "ix_hands" then
        -- Handle damage via our system (will check if fist damage is allowed)
        ws.doors.DamageDoor(target, 1, attacker, inflictor)
        return true  -- Block default damage
    end

    -- Block other damage types (prop_door_rotating shouldn't take random damage)
    return true
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Save doors when a player disconnects (in case they were editing)
hook.Add("PlayerDisconnected", "wsWindsweptDoorSave", function(client)
    -- Close any locksmith machines they were using
    for _, ent in ipairs(ents.FindByClass("ix_auto_locksmith")) do
        if ent:GetUser() == client then
            ent:CloseForUser(client)
        end
    end
end)

-- ============================================================================
-- ADMIN UTILITIES
-- ============================================================================

-- Command to spawn a door at a frame for testing
ws.command.Add("DoorSpawn", {
    description = "Spawn a door at the nearest empty frame.",
    adminOnly = true,
    arguments = {
        ws.type.string  -- Door type: "wood", "metal", "gate"
    },
    OnRun = function(self, client, doorType)
        doorType = string.lower(doorType or "wood")

        if doorType ~= "wood" and doorType ~= "metal" and doorType ~= "gate" then
            return "@doorInvalidType"
        end

        local tr = client:GetEyeTrace()
        local pos = tr.HitPos

        -- Find nearest empty frame
        local nearestID = nil
        local nearestDist = 256

        for mapID, frameData in pairs(ws.doors.frames or {}) do
            if not frameData.disabled and not frameData.hasDoor then
                local dist = pos:Distance(frameData.pos)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestID = mapID
                end
            end
        end

        if not nearestID then
            return "@doorNoEmptyFrame"
        end

        -- Spawn door
        local doorData = {
            doorType = doorType
        }

        local door = ws.doors.SpawnDoor(nearestID, doorData)
        if IsValid(door) then
            ws.doors.Save()
            return "@doorSpawned"
        else
            return "@doorSpawnFailed"
        end
    end
})

-- Command to give admin door/lock/key items for testing
ws.command.Add("DoorGiveItems", {
    description = "Give yourself door system test items.",
    adminOnly = true,
    OnRun = function(self, client)
        local character, inventory = ws.constants.GetCharacterInventory(client)
        if not character or not inventory then return end

        -- Give test items
        inventory:Add("key_blank", 1, {quantity = 5})
        inventory:Add("lock_blank", 1, {quantity = 3})
        inventory:Add("door_wood", 1, {health = 100})
        inventory:Add("toolkit", 1, {size = "medium", quality = "standard", durability = 100})
        inventory:Add("lockpick", 1, {quality = "quality"})

        return "@doorItemsGiven"
    end
})
