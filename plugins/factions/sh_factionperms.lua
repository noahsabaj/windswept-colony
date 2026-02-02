--[[
    Factions Plugin - Permission System

    Class-based permission system for faction management.

    Permission Rules:
    - Rank 255 (anchor/leader): ALL permissions automatically
    - Rank 0 (default class): NO permissions
    - Ranks 1-254: Based on class's permissions table

    Rank Scope:
    - You can only affect ranks BELOW yours
    - Rank 255 can affect 0-254
    - Rank 100 can affect 0-99
    - Rank 0 can affect nothing
]]--

ix.factionperms = ix.factionperms or {}

-- ============================================================================
-- PERMISSION CONSTANTS
-- ============================================================================

-- Class management
ix.factionperms.CLASS_CREATE = "class_create"
ix.factionperms.CLASS_DELETE = "class_delete"
ix.factionperms.CLASS_UPDATE = "class_update"
ix.factionperms.CLASS_ASSIGN = "class_assign"

-- Permission delegation
ix.factionperms.PERM_GRANT = "perm_grant"
ix.factionperms.PERM_REVOKE = "perm_revoke"

-- Member management
ix.factionperms.FACTION_INVITE = "faction_invite"
ix.factionperms.FACTION_REMOVE = "faction_remove"

-- Information access
ix.factionperms.FACTION_INFO = "faction_info"

-- All permissions (for iteration)
ix.factionperms.ALL = {
    ix.factionperms.CLASS_CREATE,
    ix.factionperms.CLASS_DELETE,
    ix.factionperms.CLASS_UPDATE,
    ix.factionperms.CLASS_ASSIGN,
    ix.factionperms.PERM_GRANT,
    ix.factionperms.PERM_REVOKE,
    ix.factionperms.FACTION_INVITE,
    ix.factionperms.FACTION_REMOVE,
    ix.factionperms.FACTION_INFO,
}

-- Human-readable names for UI
ix.factionperms.NAMES = {
    [ix.factionperms.CLASS_CREATE] = "Create Classes",
    [ix.factionperms.CLASS_DELETE] = "Delete Classes",
    [ix.factionperms.CLASS_UPDATE] = "Update Classes",
    [ix.factionperms.CLASS_ASSIGN] = "Assign Members to Classes",
    [ix.factionperms.PERM_GRANT] = "Grant Permissions",
    [ix.factionperms.PERM_REVOKE] = "Revoke Permissions",
    [ix.factionperms.FACTION_INVITE] = "Invite to Faction",
    [ix.factionperms.FACTION_REMOVE] = "Remove from Faction",
    [ix.factionperms.FACTION_INFO] = "View Faction Info",
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Get a character's class data
local function GetCharacterClass(character)
    if not character then return nil end

    local classID = character:GetClass()
    if not classID then return nil end

    return ix.class.Get(classID)
end

-- Get a character's rank (0-255)
local function GetCharacterRank(character)
    local classData = GetCharacterClass(character)
    if not classData then return 0 end

    return classData.rank or 0
end

-- ============================================================================
-- PERMISSION FUNCTIONS
-- ============================================================================

--[[
    Check if a character has a specific permission.

    @param character - The character to check
    @param permission - The permission key (e.g., ix.factionperms.CLASS_CREATE)
    @return boolean - Whether the character has the permission
]]--
function ix.factionperms.HasPermission(character, permission)
    if not character then return false end

    local classData = GetCharacterClass(character)
    if not classData then return false end

    local rank = classData.rank or 0

    -- Rank 255 (anchor) has ALL permissions
    if rank == 255 then
        return true
    end

    -- Rank 0 (default) has NO permissions
    if rank == 0 then
        return false
    end

    -- Ranks 1-254 check permissions table
    if classData.permissions and classData.permissions[permission] then
        return true
    end

    return false
end

--[[
    Get the maximum rank a character can assign/create.
    You can only create or assign to ranks BELOW your own.

    @param character - The character to check
    @return number - The maximum assignable rank (0 to 254)
]]--
function ix.factionperms.GetMaxAssignableRank(character)
    local rank = GetCharacterRank(character)

    -- Can only affect ranks below yours
    -- Rank 255 can assign up to 254
    -- Rank 100 can assign up to 99
    -- Rank 0 can assign nothing (returns -1, which fails validation)
    return rank - 1
end

--[[
    Check if a character can affect a target rank.
    You can only affect ranks BELOW your own.

    @param character - The character to check
    @param targetRank - The rank being affected
    @return boolean - Whether the character can affect that rank
]]--
function ix.factionperms.CanAffectRank(character, targetRank)
    local myRank = GetCharacterRank(character)

    -- Must have strictly higher rank to affect
    return myRank > targetRank
end

--[[
    Get all permissions a character has.
    Useful for UI display.

    @param character - The character to check
    @return table - Array of permission keys the character has
]]--
function ix.factionperms.GetPermissions(character)
    local perms = {}

    for _, perm in ipairs(ix.factionperms.ALL) do
        if ix.factionperms.HasPermission(character, perm) then
            table.insert(perms, perm)
        end
    end

    return perms
end

--[[
    Get the human-readable name of a permission.

    @param permission - The permission key
    @return string - The display name
]]--
function ix.factionperms.GetPermissionName(permission)
    return ix.factionperms.NAMES[permission] or permission
end
