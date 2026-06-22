--[[
    Windswept Doors (Colony bridge) - Server

    Colony-only door glue: locksmith cleanup and admin/test commands. The door-use and
    damage routing now live in the framework door plugin (via the damage-source registry
    this bridge populates in sh_plugin.lua).
]]--

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Close any locksmith machine a disconnecting player was using.
hook.Add("PlayerDisconnected", "wsWindsweptDoorSave", function(client)
    for _, ent in ipairs(ents.FindByClass("ws_auto_locksmith")) do
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
