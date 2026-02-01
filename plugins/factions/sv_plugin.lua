--[[
    Factions Plugin - Server-Side
    Handles faction invites and related server logic
]]--

-- Handle faction invite response
net.Receive("ixFactionInviteResponse", function(len, ply)
    local accepted = net.ReadBool()

    if not accepted then
        -- Optionally notify inviter that invite was declined
        return
    end

    local factionID = net.ReadUInt(8)
    local classIndex = net.ReadUInt(16)

    local character = ply:GetCharacter()
    if not character then return end

    -- Verify player is still factionless
    if ply:Team() ~= TEAM_UNASSIGNED then
        ply:NotifyLocalized("alreadyInFaction")
        return
    end

    -- Verify class exists and belongs to faction
    local classData = ix.class.Get(classIndex)
    if not classData then
        ply:NotifyLocalized("classNoLongerExists")
        return
    end

    local factionData = ix.faction.Get(factionID)
    if not factionData then
        ply:NotifyLocalized("factionNoLongerExists")
        return
    end

    if classData.faction ~= factionID then
        ply:NotifyLocalized("classFactionMismatch")
        return
    end

    -- Check class limit
    if classData.limit and classData.limit > 0 then
        local members = ix.class.GetPlayers(classIndex)
        if #members >= classData.limit then
            ply:NotifyLocalized("classFull")
            return
        end
    end

    -- Join faction and class
    character:SetFaction(factionID)
    character:SetClass(classIndex)

    hook.Run("PlayerJoinedClass", ply, classIndex, nil)

    ply:NotifyLocalized("joinedFaction", factionData.name, classData.name)
    ix.log.Add(ply, "factionJoin", factionData.name, classData.name)
end)

-- Handle ballot submission
net.Receive("ixBallotSubmit", function(len, ply)
    local voteID = net.ReadUInt(32)
    local approvals = net.ReadTable()

    local character = ply:GetCharacter()
    if not character then return end

    local vote = ix.factions.activeVotes[voteID]
    if not vote then
        ply:NotifyLocalized("voteNoLongerActive")
        return
    end

    -- Check if already voted
    local query = mysql:Select("ix_faction_ballots")
    query:Where("vote_id", voteID)
    query:Where("char_id", character:GetID())
    query:Callback(function(result)
        if result and #result > 0 then
            ply:NotifyLocalized("alreadyVoted")
            return
        end

        -- Insert ballot
        local insertQuery = mysql:Insert("ix_faction_ballots")
        insertQuery:Insert("vote_id", voteID)
        insertQuery:Insert("char_id", character:GetID())
        insertQuery:Insert("approvals", util.TableToJSON(approvals))
        insertQuery:Insert("cast_at", os.time())
        insertQuery:Callback(function()
            ply:NotifyLocalized("ballotSubmitted")
        end)
        insertQuery:Execute()
    end)
    query:Execute()
end)

-- Handle ballot UI close
net.Receive("ixBallotClose", function(len, ply)
    local ent = net.ReadEntity()
    if IsValid(ent) and ent:GetClass() == "ix_ballot_station" then
        ent:SetInUse(false)
        ent:SetUser(nil)
    end
end)

-- Track candidate online time during votes
hook.Add("Think", "ixVoteCandidateTracking", function()
    if not ix.factions.activeVotes then return end
    if table.Count(ix.factions.activeVotes) == 0 then return end

    -- Run every second
    ix.factions.lastTrackTime = ix.factions.lastTrackTime or 0
    if CurTime() - ix.factions.lastTrackTime < 1 then return end
    ix.factions.lastTrackTime = CurTime()

    -- Build char ID -> true lookup table once per tick (O(n) instead of O(n*m) for candidate checks)
    local onlineCharIDs = {}
    for _, ply in player.Iterator() do
        local char = ply:GetCharacter()
        if char then
            onlineCharIDs[char:GetID()] = true
        end
    end

    for voteID, vote in pairs(ix.factions.activeVotes) do
        if vote.candidates then
            for _, cand in ipairs(vote.candidates) do
                if not cand.dropped and onlineCharIDs[cand.char_id] then
                    -- O(1) lookup instead of iterating all players per candidate
                    cand.online_time = (cand.online_time or 0) + 1
                end
            end
        end
    end
end)

-- Hook into permadeath for vote revocation
-- Uses PreCharacterDeleted because CharacterDeleted fires after character is already removed
hook.Add("PreCharacterDeleted", "ixVotePermakill", function(client, character)
    if not character then return end
    local charID = character:GetID()

    for voteID, vote in pairs(ix.factions.activeVotes or {}) do
        if vote.candidates then
            -- Remove as candidate
            for _, cand in ipairs(vote.candidates) do
                if cand.char_id == charID then
                    cand.dropped = true

                    -- Check remaining candidates
                    local remaining = {}
                    for _, c in ipairs(vote.candidates) do
                        if not c.dropped then
                            table.insert(remaining, c)
                        end
                    end

                    if #remaining == 1 then
                        ix.factions.EndVoteEarly(voteID, remaining[1].char_id)
                    elseif #remaining == 0 then
                        ix.factions.HandleNoValidCandidate(voteID)
                    end
                end
            end
        end

        -- Revoke ballot if they voted
        local query = mysql:Delete("ix_faction_ballots")
        query:Where("vote_id", voteID)
        query:Where("char_id", charID)
        query:Execute()
    end
end)
