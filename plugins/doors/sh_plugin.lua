--[[
    Windswept Doors Plugin

    Overrides Windswept's default door system with the physical lock & key system.
    - Removes door ownership (buying/selling)
    - Removes faction/class door access
    - Uses prop_door_rotating entities with wsIsWindsweptDoor marker
]]--

local PLUGIN = PLUGIN

PLUGIN.name = "Windswept Doors"
PLUGIN.author = "Windswept"
PLUGIN.description = "Physical lock and key door system."

-- Include plugin files
ws.util.Include("sv_plugin.lua")
ws.util.Include("cl_plugin.lua")

-- ============================================================================
-- DISABLE WINDSWEPT DOOR SYSTEM
-- ============================================================================

-- Override Windswept door access to always return false (use physical keys instead)
hook.Add("CanPlayerAccessDoor", "wsWindsweptDoors", function(client, door, access)
    -- If it's a map door that's been hidden by our system, deny access
    -- Our managed doors have their own access system
    if door:IsDoor() and door:GetNoDraw() then
        return false
    end

    -- For our managed doors, access is determined by having the right key
    if door.wsIsWindsweptDoor then
        -- Lock/unlock is handled by keys, not by this hook
        -- Use is allowed if door is unlocked
        return not door:IsLocked()
    end
end)

-- Prevent Windswept door buying
hook.Add("CanPlayerBuyDoor", "wsWindsweptDoors", function(client, door)
    return false, "Door ownership has been disabled."
end)

-- Prevent Windswept door selling
hook.Add("CanPlayerSellDoor", "wsWindsweptDoors", function(client, door)
    return false, "Door ownership has been disabled."
end)

-- ============================================================================
-- ENTITY METHODS
-- ============================================================================

-- Override CheckDoorAccess for our system
local entityMeta = FindMetaTable("Entity")

-- Store original function
local originalCheckDoorAccess = entityMeta.CheckDoorAccess

function entityMeta:CheckDoorAccess(client, access)
    -- For our managed doors, use lock state
    if self.wsIsWindsweptDoor then
        if self:IsLocked() then
            return false  -- Need key to access locked door
        end
        return true  -- Unlocked doors are accessible
    end

    -- For hidden map doors (our frames), deny access
    if self:IsDoor() and self:GetNoDraw() then
        return false
    end

    -- Fall back to original for any other doors
    if originalCheckDoorAccess then
        return originalCheckDoorAccess(self, client, access)
    end

    return false
end

-- ============================================================================
-- CONFIG OVERRIDES
-- ============================================================================

-- Set door cost to 0 and hide from config menu
hook.Add("InitializedConfig", "wsWindsweptDoorConfig", function()
    -- These configs still exist but are unused in our system
    ws.config.Set("doorCost", 0)
    ws.config.Set("doorSellRatio", 0)
end)
