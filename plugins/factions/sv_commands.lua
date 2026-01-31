--[[
    Factions Plugin - Server Commands
    All faction management commands

    Commands:
    - /CreateClass <name> <pay> <rank> - Create a new class
    - /DeleteClass <name> - Delete a class
    - /UpdateClass <name> <property> <value> - Update class property
    - /ViewClass [name] - View class info
    - /MyPermissions - View your permissions
    - /GrantPerm <class> <permission> - Grant permission to class
    - /RevokePerm <class> <permission> - Revoke permission from class
    - /FactionInvite <player> [class] - Invite player to faction
    - /FactionRemove <player> - Remove player from faction
    - /AssignClass <player> <class> - Assign player to class
    - /FactionResign [successor] - Resign from faction
    - /FactionInfo - View faction info panel
    - /VoteDropout - Drop out of succession vote
]]--

-- Command: /CreateClass
ix.command.Add("CreateClass", {
    description = "Create a new class in your faction.",
    arguments = {
        ix.type.string,  -- name
        ix.type.number,  -- pay
        ix.type.number,  -- rank
    },
    OnRun = function(self, client, name, pay, rank)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.CLASS_CREATE) then
            return "@noPermission"
        end

        -- Rank scope check
        local maxRank = ix.factionperms.GetMaxAssignableRank(character)
        if rank > maxRank then
            return "@rankTooHigh", maxRank
        end

        if rank < 1 then
            return "@rankTooLow"
        end

        -- Name validation
        name = string.Trim(name)
        if #name < 2 or #name > 32 then
            return "@invalidClassName"
        end

        if not name:match("^[%w%s]+$") then
            return "@invalidClassNameChars"
        end

        -- Check name collision
        local factionData = ix.faction.Get(faction)
        for _, classData in pairs(ix.class.list) do
            if classData.faction == faction and
               string.lower(classData.name) == string.lower(name) then
                return "@classNameExists", name
            end
        end

        -- Pay validation
        pay = math.floor(math.max(0, pay))

        -- Create the class
        local classData = ix.class.Create({
            faction = factionData.uniqueID,
            name = name,
            description = "A custom class.",
            rank = rank,
            pay = pay,
            permissions = {},
            createdBy = character:GetID(),
        })

        if classData then
            client:NotifyLocalized("classCreated", name, rank)
            ix.log.Add(client, "classCreate", name, rank)
        else
            return "@classCreateFailed"
        end
    end,
})

-- Command: /DeleteClass
ix.command.Add("DeleteClass", {
    description = "Delete a class from your faction.",
    arguments = {ix.type.string},  -- class name
    OnRun = function(self, client, className)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.CLASS_DELETE) then
            return "@noPermission"
        end

        -- Find class
        local targetClass = nil
        for _, classData in pairs(ix.class.list) do
            if classData.faction == faction and
               (string.lower(classData.name) == string.lower(className) or
                string.lower(classData.uniqueID or "") == string.lower(className)) then
                targetClass = classData
                break
            end
        end

        if not targetClass then
            return "@classNotFound", className
        end

        -- Cannot delete anchor or default
        if targetClass.isAnchor then
            return "@cannotDeleteAnchor"
        end

        if targetClass.isDefault then
            return "@cannotDeleteDefault"
        end

        -- Rank scope check
        if not ix.factionperms.CanAffectRank(character, targetClass.rank) then
            return "@cannotAffectRank"
        end

        -- Check for members
        local members = ix.class.GetPlayers(targetClass.index)
        if #members > 0 then
            return "@classHasMembers", #members
        end

        -- Delete
        local success = ix.class.Delete(targetClass.id)
        if success then
            client:NotifyLocalized("classDeleted", targetClass.name)
            ix.log.Add(client, "classDelete", targetClass.name)
        else
            return "@classDeleteFailed"
        end
    end,
})

-- Command: /UpdateClass
ix.command.Add("UpdateClass", {
    description = "Update a class property.",
    arguments = {
        ix.type.string,  -- class name
        ix.type.string,  -- property (name, pay, rank)
        ix.type.text,    -- value
    },
    OnRun = function(self, client, className, property, value)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.CLASS_UPDATE) then
            return "@noPermission"
        end

        -- Find class
        local targetClass = nil
        for _, classData in pairs(ix.class.list) do
            if classData.faction == faction and
               (string.lower(classData.name) == string.lower(className) or
                string.lower(classData.uniqueID or "") == string.lower(className)) then
                targetClass = classData
                break
            end
        end

        if not targetClass then
            return "@classNotFound", className
        end

        -- Rank scope check
        if not ix.factionperms.CanAffectRank(character, targetClass.rank) then
            return "@cannotAffectRank"
        end

        -- Handle property updates
        property = string.lower(property)
        local updates = {}

        if property == "name" then
            -- Cannot rename anchor classes
            if targetClass.isAnchor then
                return "@cannotRenameAnchor"
            end

            value = string.Trim(value)
            if #value < 2 or #value > 32 then
                return "@invalidClassName"
            end

            if not value:match("^[%w%s]+$") then
                return "@invalidClassNameChars"
            end

            -- Check collision
            for _, classData in pairs(ix.class.list) do
                if classData.faction == faction and
                   classData.index ~= targetClass.index and
                   string.lower(classData.name) == string.lower(value) then
                    return "@classNameExists", value
                end
            end

            updates.name = value

        elseif property == "pay" then
            local payNum = tonumber(value)
            if not payNum then return "@invalidPay" end
            updates.pay = math.floor(math.max(0, payNum))

        elseif property == "rank" then
            -- Cannot change anchor or default rank
            if targetClass.isAnchor or targetClass.isDefault then
                return "@cannotChangeRank"
            end

            local rankNum = tonumber(value)
            if not rankNum then return "@invalidRank" end
            rankNum = math.floor(rankNum)

            if rankNum < 1 or rankNum > 254 then
                return "@rankOutOfRange"
            end

            local maxRank = ix.factionperms.GetMaxAssignableRank(character)
            if rankNum > maxRank then
                return "@rankTooHigh", maxRank
            end

            updates.rank = rankNum

        elseif property == "description" then
            updates.description = string.sub(value, 1, 512)

        elseif property == "limit" then
            local limitNum = tonumber(value)
            if not limitNum then return "@invalidLimit" end
            updates.classLimit = math.floor(math.max(0, limitNum))

        else
            return "@invalidProperty", property
        end

        -- Apply updates
        local success = ix.class.Update(targetClass.id, updates)
        if success then
            client:NotifyLocalized("classUpdated", property, targetClass.name)
            ix.log.Add(client, "classUpdate", targetClass.name, property, value)
        else
            return "@classUpdateFailed"
        end
    end,
})

-- Command: /ViewClass
ix.command.Add("ViewClass", {
    description = "View class information.",
    arguments = {bit.bor(ix.type.string, ix.type.optional)},  -- optional class name
    OnRun = function(self, client, className)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        local factionData = ix.faction.Get(faction)

        if className then
            -- Show specific class
            local targetClass = nil
            for _, classData in pairs(ix.class.list) do
                if classData.faction == faction and
                   (string.lower(classData.name) == string.lower(className) or
                    string.lower(classData.uniqueID or "") == string.lower(className)) then
                    targetClass = classData
                    break
                end
            end

            if not targetClass then
                return "@classNotFound", className
            end

            -- Build info message
            client:ChatPrint("=== " .. targetClass.name .. " ===")
            client:ChatPrint("Rank: " .. (targetClass.rank or 0))
            client:ChatPrint("Pay: $" .. (targetClass.pay or 0))
            client:ChatPrint("Limit: " .. ((targetClass.limit or 0) > 0 and targetClass.limit or "Unlimited"))
            client:ChatPrint("Members: " .. #ix.class.GetPlayers(targetClass.index))

            if targetClass.description then
                client:ChatPrint("Description: " .. targetClass.description)
            end

            -- Show permissions if has faction_info perm
            if ix.factionperms.HasPermission(character, ix.factionperms.FACTION_INFO) then
                local perms = {}
                for _, perm in ipairs(ix.factionperms.ALL) do
                    if targetClass.permissions and targetClass.permissions[perm] then
                        table.insert(perms, perm)
                    end
                end
                if #perms > 0 then
                    client:ChatPrint("Permissions: " .. table.concat(perms, ", "))
                end
            end
        else
            -- Show all classes
            client:ChatPrint("=== Classes in " .. factionData.name .. " ===")

            local classes = {}
            for _, classData in pairs(ix.class.list) do
                if classData.faction == faction then
                    table.insert(classes, classData)
                end
            end

            -- Sort by rank descending
            table.sort(classes, function(a, b) return (a.rank or 0) > (b.rank or 0) end)

            for _, classData in ipairs(classes) do
                local memberCount = #ix.class.GetPlayers(classData.index)
                client:ChatPrint(string.format(
                    "[%d] %s - $%d - %d member(s)",
                    classData.rank or 0,
                    classData.name,
                    classData.pay or 0,
                    memberCount
                ))
            end
        end
    end,
})

-- Command: /MyPermissions
ix.command.Add("MyPermissions", {
    description = "View your class permissions.",
    OnRun = function(self, client)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local classID = character:GetClass()
        if not classID then
            return "@noClass"
        end

        local classData = ix.class.Get(classID)
        if not classData then
            return "@classNotFound"
        end

        client:ChatPrint("=== Your Permissions (" .. classData.name .. ") ===")
        client:ChatPrint("Rank: " .. (classData.rank or 0))

        if classData.rank == 255 then
            client:ChatPrint("You have ALL permissions (Rank 255)")
        elseif classData.rank == 0 then
            client:ChatPrint("You have NO permissions (Rank 0)")
        else
            local hasPerms = {}
            local noPerms = {}

            for _, perm in ipairs(ix.factionperms.ALL) do
                if classData.permissions and classData.permissions[perm] then
                    table.insert(hasPerms, perm)
                else
                    table.insert(noPerms, perm)
                end
            end

            if #hasPerms > 0 then
                client:ChatPrint("Has: " .. table.concat(hasPerms, ", "))
            end
            if #noPerms > 0 then
                client:ChatPrint("Missing: " .. table.concat(noPerms, ", "))
            end
        end

        client:ChatPrint("Can affect ranks: 0-" .. ((classData.rank or 1) - 1))
    end,
})

-- Command: /GrantPerm
ix.command.Add("GrantPerm", {
    description = "Grant a permission to a class.",
    arguments = {
        ix.type.string,  -- class name
        ix.type.string,  -- permission key
    },
    OnRun = function(self, client, className, permKey)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.PERM_GRANT) then
            return "@noPermission"
        end

        -- Validate permission key
        permKey = string.lower(permKey)
        local validPerm = false
        for _, perm in ipairs(ix.factionperms.ALL) do
            if perm == permKey then
                validPerm = true
                break
            end
        end

        if not validPerm then
            return "@invalidPermission", permKey
        end

        -- Check if granter has this permission
        if not ix.factionperms.HasPermission(character, permKey) then
            return "@cannotGrantPermYouDontHave", permKey
        end

        -- Find class
        local targetClass = nil
        for _, classData in pairs(ix.class.list) do
            if classData.faction == faction and
               (string.lower(classData.name) == string.lower(className) or
                string.lower(classData.uniqueID or "") == string.lower(className)) then
                targetClass = classData
                break
            end
        end

        if not targetClass then
            return "@classNotFound", className
        end

        -- Cannot modify anchor or default permissions
        if targetClass.isAnchor then
            return "@cannotModifyAnchorPerms"
        end

        if targetClass.isDefault then
            return "@cannotModifyDefaultPerms"
        end

        -- Rank scope check
        if not ix.factionperms.CanAffectRank(character, targetClass.rank) then
            return "@cannotAffectRank"
        end

        -- Grant permission
        local perms = targetClass.permissions or {}
        perms[permKey] = true

        local success = ix.class.Update(targetClass.id, {permissions = perms})
        if success then
            client:NotifyLocalized("permGranted", permKey, targetClass.name)
            ix.log.Add(client, "permGrant", permKey, targetClass.name)
        else
            return "@permGrantFailed"
        end
    end,
})

-- Command: /RevokePerm
ix.command.Add("RevokePerm", {
    description = "Revoke a permission from a class.",
    arguments = {
        ix.type.string,  -- class name
        ix.type.string,  -- permission key
    },
    OnRun = function(self, client, className, permKey)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.PERM_REVOKE) then
            return "@noPermission"
        end

        -- Validate permission key
        permKey = string.lower(permKey)
        local validPerm = false
        for _, perm in ipairs(ix.factionperms.ALL) do
            if perm == permKey then
                validPerm = true
                break
            end
        end

        if not validPerm then
            return "@invalidPermission", permKey
        end

        -- Find class
        local targetClass = nil
        for _, classData in pairs(ix.class.list) do
            if classData.faction == faction and
               (string.lower(classData.name) == string.lower(className) or
                string.lower(classData.uniqueID or "") == string.lower(className)) then
                targetClass = classData
                break
            end
        end

        if not targetClass then
            return "@classNotFound", className
        end

        -- Cannot modify anchor or default permissions
        if targetClass.isAnchor then
            return "@cannotModifyAnchorPerms"
        end

        if targetClass.isDefault then
            return "@cannotModifyDefaultPerms"
        end

        -- Rank scope check
        if not ix.factionperms.CanAffectRank(character, targetClass.rank) then
            return "@cannotAffectRank"
        end

        -- Revoke permission
        local perms = targetClass.permissions or {}
        perms[permKey] = nil

        local success = ix.class.Update(targetClass.id, {permissions = perms})
        if success then
            client:NotifyLocalized("permRevoked", permKey, targetClass.name)
            ix.log.Add(client, "permRevoke", permKey, targetClass.name)
        else
            return "@permRevokeFailed"
        end
    end,
})

-- Command: /FactionInvite
ix.command.Add("FactionInvite", {
    description = "Invite a player to your faction.",
    arguments = {
        ix.type.string,  -- character name
        bit.bor(ix.type.string, ix.type.optional),  -- class name (optional)
    },
    OnRun = function(self, client, targetName, className)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.FACTION_INVITE) then
            return "@noPermission"
        end

        -- Find target character
        local targetChar, targetPlayer = nil, nil
        for _, ply in player.Iterator() do
            local char = ply:GetCharacter()
            if char and string.lower(char:GetName()) == string.lower(targetName) then
                targetChar = char
                targetPlayer = ply
                break
            end
        end

        if not targetChar then
            -- Silent fail to prevent metagaming (checking if player is online)
            return
        end

        -- Check if already in this faction
        if targetPlayer:Team() == faction then
            return "@alreadyInFaction"
        end

        -- Check if already in ANY faction
        if targetPlayer:Team() ~= TEAM_UNASSIGNED then
            return "@targetInOtherFaction"
        end

        -- Determine target class
        local factionData = ix.faction.Get(faction)
        local targetClass = nil

        if className then
            -- Find specified class
            for _, classData in pairs(ix.class.list) do
                if classData.faction == faction and
                   (string.lower(classData.name) == string.lower(className) or
                    string.lower(classData.uniqueID or "") == string.lower(className)) then
                    targetClass = classData
                    break
                end
            end

            if not targetClass then
                return "@classNotFound", className
            end
        else
            -- Use default class (rank 0)
            for _, classData in pairs(ix.class.list) do
                if classData.faction == faction and classData.isDefault then
                    targetClass = classData
                    break
                end
            end
        end

        if not targetClass then
            return "@noDefaultClass"
        end

        -- Rank scope check
        if not ix.factionperms.CanAffectRank(character, targetClass.rank) then
            return "@cannotInviteToRank"
        end

        -- Send invite to target
        net.Start("ixFactionInvite")
            net.WriteString(factionData.name)
            net.WriteString(targetClass.name)
            net.WriteString(character:GetName())
            net.WriteUInt(faction, 8)
            net.WriteUInt(targetClass.index, 16)
        net.Send(targetPlayer)

        client:NotifyLocalized("inviteSent", targetChar:GetName())
    end,
})

-- Command: /FactionRemove
ix.command.Add("FactionRemove", {
    description = "Remove a player from your faction.",
    arguments = {ix.type.string},  -- character name
    OnRun = function(self, client, targetName)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.FACTION_REMOVE) then
            return "@noPermission"
        end

        -- Find target character
        local targetChar, targetPlayer = nil, nil
        for _, ply in player.Iterator() do
            local char = ply:GetCharacter()
            if char and string.lower(char:GetName()) == string.lower(targetName) then
                targetChar = char
                targetPlayer = ply
                break
            end
        end

        if not targetChar then
            return "@characterNotOnline"
        end

        -- Check if in same faction
        if targetPlayer:Team() ~= faction then
            return "@notInYourFaction"
        end

        -- Cannot remove yourself
        if targetChar:GetID() == character:GetID() then
            return "@cannotRemoveSelf"
        end

        -- Get target's rank
        local targetClassID = targetChar:GetClass()
        local targetClass = ix.class.Get(targetClassID)

        if targetClass then
            -- Rank scope check
            if not ix.factionperms.CanAffectRank(character, targetClass.rank or 0) then
                return "@cannotRemoveHigherRank"
            end
        end

        -- Remove from faction
        targetChar:SetFaction(TEAM_UNASSIGNED)
        targetChar:SetClass(nil)

        targetPlayer:NotifyLocalized("removedFromFaction")
        client:NotifyLocalized("memberRemoved", targetChar:GetName())
        ix.log.Add(client, "factionRemove", targetChar:GetName())
    end,
})

-- Command: /AssignClass
ix.command.Add("AssignClass", {
    description = "Assign a faction member to a class.",
    arguments = {
        ix.type.string,  -- character name
        ix.type.string,  -- class name
    },
    OnRun = function(self, client, targetName, className)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.CLASS_ASSIGN) then
            return "@noPermission"
        end

        -- Find target character
        local targetChar, targetPlayer = nil, nil
        for _, ply in player.Iterator() do
            local char = ply:GetCharacter()
            if char and string.lower(char:GetName()) == string.lower(targetName) then
                targetChar = char
                targetPlayer = ply
                break
            end
        end

        if not targetChar then
            return "@characterNotOnline"
        end

        -- Check if in same faction
        if targetPlayer:Team() ~= faction then
            return "@notInYourFaction"
        end

        -- Find target class
        local targetClass = nil
        for _, classData in pairs(ix.class.list) do
            if classData.faction == faction and
               (string.lower(classData.name) == string.lower(className) or
                string.lower(classData.uniqueID or "") == string.lower(className)) then
                targetClass = classData
                break
            end
        end

        if not targetClass then
            return "@classNotFound", className
        end

        -- Get current class
        local currentClassID = targetChar:GetClass()
        local currentClass = ix.class.Get(currentClassID)

        -- Rank scope check: must be able to affect BOTH current and target class
        if currentClass and not ix.factionperms.CanAffectRank(character, currentClass.rank or 0) then
            return "@cannotAffectCurrentRank"
        end

        if not ix.factionperms.CanAffectRank(character, targetClass.rank or 0) then
            return "@cannotAssignToRank"
        end

        -- Check class limit
        if targetClass.limit and targetClass.limit > 0 then
            local members = ix.class.GetPlayers(targetClass.index)
            if #members >= targetClass.limit then
                return "@classFull"
            end
        end

        -- Assign class
        targetChar:SetClass(targetClass.index)
        hook.Run("PlayerJoinedClass", targetPlayer, targetClass.index, currentClassID)

        targetPlayer:NotifyLocalized("classAssigned", targetClass.name)
        client:NotifyLocalized("memberAssigned", targetChar:GetName(), targetClass.name)
        ix.log.Add(client, "classAssign", targetChar:GetName(), targetClass.name)
    end,
})

-- Command: /FactionResign
ix.command.Add("FactionResign", {
    description = "Resign from your faction (rank 255 can name successor).",
    arguments = {bit.bor(ix.type.string, ix.type.optional)},  -- successor name (rank 255 only)
    OnRun = function(self, client, successorName)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        local classID = character:GetClass()
        local classData = ix.class.Get(classID)

        if not classData then
            return "@noClass"
        end

        local myRank = classData.rank or 0

        if myRank == 255 then
            -- Anchor class resignation - requires succession handling
            return ix.factions.HandleAnchorResignation(client, character, faction, successorName)
        else
            -- Normal resignation - just leave
            character:SetFaction(TEAM_UNASSIGNED)
            character:SetClass(nil)

            client:NotifyLocalized("resigned")
            ix.log.Add(client, "factionResign", classData.name)
        end
    end,
})

-- Command: /FactionInfo
ix.command.Add("FactionInfo", {
    description = "View detailed faction information (opens UI).",
    OnRun = function(self, client)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local faction = client:Team()
        if not faction or faction == TEAM_UNASSIGNED then
            return "@notInFaction"
        end

        -- Permission check
        if not ix.factionperms.HasPermission(character, ix.factionperms.FACTION_INFO) then
            return "@noPermission"
        end

        -- Gather faction data
        local factionData = ix.faction.Get(faction)
        local classes = {}
        local members = {}

        for _, classData in pairs(ix.class.list) do
            if classData.faction == faction then
                local classMembers = ix.class.GetPlayers(classData.index)
                table.insert(classes, {
                    id = classData.id,
                    index = classData.index,
                    name = classData.name,
                    rank = classData.rank or 0,
                    pay = classData.pay or 0,
                    memberCount = #classMembers,
                    isAnchor = classData.isAnchor,
                    isDefault = classData.isDefault,
                    permissions = classData.permissions,
                })

                for _, ply in ipairs(classMembers) do
                    local char = ply:GetCharacter()
                    if char then
                        table.insert(members, {
                            name = char:GetName(),
                            className = classData.name,
                            rank = classData.rank or 0,
                            steamID = ply:SteamID(),
                        })
                    end
                end
            end
        end

        -- Sort classes by rank descending
        table.sort(classes, function(a, b) return a.rank > b.rank end)

        -- Send to client
        net.Start("ixFactionInfoOpen")
            net.WriteString(factionData.name)
            net.WriteTable(classes)
            net.WriteTable(members)
        net.Send(client)
    end,
})

-- Command: /VoteDropout
ix.command.Add("VoteDropout", {
    description = "Drop out of an active succession vote.",
    OnRun = function(self, client)
        local character = client:GetCharacter()
        if not character then return "@noCharacter" end

        local charID = character:GetID()

        -- Find if character is a candidate in any active vote
        for voteID, vote in pairs(ix.factions.activeVotes or {}) do
            if vote.candidates then
                for _, cand in ipairs(vote.candidates) do
                    if cand.char_id == charID and not cand.dropped then
                        cand.dropped = true

                        -- Check if only one candidate remains
                        local remaining = {}
                        for _, c in ipairs(vote.candidates) do
                            if not c.dropped then
                                table.insert(remaining, c)
                            end
                        end

                        if #remaining == 1 then
                            -- Auto-win for last candidate
                            ix.factions.EndVoteEarly(voteID, remaining[1].char_id)
                        elseif #remaining == 0 then
                            -- All dropped - fall to next rank
                            ix.factions.HandleNoValidCandidate(voteID)
                        end

                        client:NotifyLocalized("droppedFromVote")
                        ix.log.Add(client, "voteDropout")
                        return
                    end
                end
            end
        end

        return "@notACandidate"
    end,
})
