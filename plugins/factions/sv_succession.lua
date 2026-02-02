--[[
    Factions Plugin - Succession System
    Handles leader resignation, successor nomination, and approval voting
]]--

ix.factions = ix.factions or {}
ix.factions.activeVotes = ix.factions.activeVotes or {}

-- Handle anchor (rank 255) resignation
function ix.factions.HandleAnchorResignation(client, character, factionID, successorName)
    local factionData = ix.faction.Get(factionID)
    local classID = character:GetClass()
    local classData = ix.class.Get(classID)

    if not classData then
        return "@noClass"
    end

    if successorName and successorName ~= "" then
        -- Named successor
        local successor = nil
        for _, ply in player.Iterator() do
            local char = ply:GetCharacter()
            if char and string.lower(char:GetName()) == string.lower(successorName) then
                -- Must be in same faction
                if ply:Team() == factionID then
                    successor = {player = ply, character = char}
                end
                break
            end
        end

        if not successor then
            return "@successorNotFound"
        end

        -- Transfer leadership
        character:SetFaction(TEAM_UNASSIGNED)
        character:SetClass(nil)

        successor.character:SetClass(classID)
        hook.Run("PlayerJoinedClass", successor.player, classID, successor.character:GetClass())

        successor.player:NotifyLocalized("becameLeader", classData.name)
        client:NotifyLocalized("resigned")
        ix.log.Add(client, "succession", successor.character:GetName())

        return
    end

    -- No named successor - check candidates at next rank
    local nextRank = ix.class.FindNextRankDown(factionID, 255)
    if not nextRank then
        -- No one to succeed - faction becomes leaderless
        character:SetFaction(TEAM_UNASSIGNED)
        character:SetClass(nil)
        client:NotifyLocalized("resignedNoSuccessor")
        ix.log.Add(client, "successionNone")
        return
    end

    local candidates = ix.class.GetPlayersAtRank(factionID, nextRank)

    if not candidates or #candidates == 0 then
        -- Try next rank down recursively
        return ix.factions.HandleNoCandidate(client, character, factionID, nextRank)
    elseif #candidates == 1 then
        -- Single candidate - auto-promote
        local successor = candidates[1]

        character:SetFaction(TEAM_UNASSIGNED)
        character:SetClass(nil)

        successor.character:SetClass(classID)
        hook.Run("PlayerJoinedClass", successor.player, classID, successor.character:GetClass())

        successor.player:NotifyLocalized("autoPromoted", classData.name)
        client:NotifyLocalized("resigned")
        ix.log.Add(client, "successionAuto", successor.character:GetName())
    else
        -- Multiple candidates - trigger vote
        ix.factions.StartSuccessionVote(factionID, classID, candidates, character:GetID())

        character:SetFaction(TEAM_UNASSIGNED)
        character:SetClass(nil)

        client:NotifyLocalized("resignedVoteStarted")
        ix.log.Add(client, "successionVote")
    end
end

-- Handle case when no candidates at current rank
function ix.factions.HandleNoCandidate(client, character, factionID, currentRank)
    local classID = character:GetClass()
    local classData = ix.class.Get(classID)

    -- Find next rank down
    local nextRank = ix.class.FindNextRankDown(factionID, currentRank)
    if not nextRank then
        -- No one at any rank - faction becomes leaderless
        character:SetFaction(TEAM_UNASSIGNED)
        character:SetClass(nil)
        client:NotifyLocalized("resignedNoSuccessor")
        ix.log.Add(client, "successionNone")
        return
    end

    local candidates = ix.class.GetPlayersAtRank(factionID, nextRank)

    if not candidates or #candidates == 0 then
        -- Recurse to next rank
        return ix.factions.HandleNoCandidate(client, character, factionID, nextRank)
    elseif #candidates == 1 then
        -- Single candidate - auto-promote
        local successor = candidates[1]

        character:SetFaction(TEAM_UNASSIGNED)
        character:SetClass(nil)

        successor.character:SetClass(classID)
        hook.Run("PlayerJoinedClass", successor.player, classID, successor.character:GetClass())

        successor.player:NotifyLocalized("autoPromoted", classData.name)
        client:NotifyLocalized("resigned")
        ix.log.Add(client, "successionAuto", successor.character:GetName())
    else
        -- Multiple candidates - trigger vote
        ix.factions.StartSuccessionVote(factionID, classID, candidates, character:GetID())

        character:SetFaction(TEAM_UNASSIGNED)
        character:SetClass(nil)

        client:NotifyLocalized("resignedVoteStarted")
        ix.log.Add(client, "successionVote")
    end
end

-- Start a succession vote
function ix.factions.StartSuccessionVote(factionID, anchorClassID, candidates, departingCharID)
    local factionData = ix.faction.Get(factionID)
    local classData = ix.class.Get(anchorClassID)

    if not factionData or not classData then return end

    local candidateData = {}
    for _, cand in ipairs(candidates) do
        table.insert(candidateData, {
            char_id = cand.character:GetID(),
            name = cand.character:GetName(),
            online_time = 0,
            dropped = false,
        })
    end

    local now = os.time()

    -- Insert into database
    local query = mysql:Insert("ix_faction_votes")
    query:Insert("faction", factionData.uniqueID)
    query:Insert("vote_type", "succession")
    query:Insert("status", "active")
    query:Insert("started_at", now)
    query:Insert("ends_at", now + (24 * 60 * 60))  -- 24 hours
    query:Insert("candidates", util.TableToJSON(candidateData))
    query:Insert("results", util.TableToJSON({}))
    query:Insert("departing_char_id", departingCharID)
    query:Callback(function(result, status, lastID)
        if lastID then
            -- Store active vote in memory
            ix.factions.activeVotes[lastID] = {
                id = lastID,
                factionID = factionID,
                anchorClassID = anchorClassID,
                candidates = candidateData,
                startedAt = now,
                endsAt = now + (24 * 60 * 60),
            }

            -- Notify faction members
            ix.factions.NotifyVoteStarted(factionID, classData.name)

            -- Start timer for vote end
            timer.Create("ixVote_" .. lastID, 24 * 60 * 60, 1, function()
                ix.factions.EndVote(lastID)
            end)

            -- Start hourly reminder timer
            timer.Create("ixVoteReminder_" .. lastID, 60 * 60, 24, function()
                ix.factions.SendVoteReminders(lastID)
            end)

            print("[Factions] Started succession vote #" .. lastID .. " for " .. classData.name)
        end
    end)
    query:Execute()
end

-- End a vote and tally results
function ix.factions.EndVote(voteID)
    local vote = ix.factions.activeVotes[voteID]
    if not vote then return end

    -- Tally results from database
    local query = mysql:Select("ix_faction_ballots")
    query:Where("vote_id", voteID)
    query:Callback(function(result)
        local tallies = {}
        local validCandidates = {}

        -- Get candidates who met online requirement (30 min = 1800 seconds)
        if vote.candidates then
            for _, cand in ipairs(vote.candidates) do
                if not cand.dropped and (cand.online_time or 0) >= 1800 then
                    validCandidates[cand.char_id] = cand
                    tallies[cand.char_id] = 0
                end
            end
        end

        -- Count approvals (only for valid candidates)
        if result then
            for _, ballot in ipairs(result) do
                local approvals = util.JSONToTable(ballot.approvals) or {}
                for _, charID in ipairs(approvals) do
                    if tallies[charID] then
                        tallies[charID] = tallies[charID] + 1
                    end
                end
            end
        end

        -- Find winner (highest approvals, tenure tiebreaker)
        local winner = nil
        local highestApprovals = -1

        for charID, approvals in pairs(tallies) do
            if approvals > highestApprovals then
                highestApprovals = approvals
                winner = validCandidates[charID]
            elseif approvals == highestApprovals and winner then
                -- Tenure tiebreaker (lower char_id = older character)
                if charID < winner.char_id then
                    winner = validCandidates[charID]
                end
            end
        end

        if winner then
            ix.factions.ApplyVoteResult(voteID, winner.char_id, tallies)
        else
            -- No valid candidates - fall to next rank
            ix.factions.HandleNoValidCandidate(voteID)
        end
    end)
    query:Execute()
end

-- End vote early (single candidate remaining)
function ix.factions.EndVoteEarly(voteID, winnerCharID)
    local vote = ix.factions.activeVotes[voteID]
    if not vote then return end

    ix.factions.ApplyVoteResult(voteID, winnerCharID, {[winnerCharID] = 0})
end

-- Apply vote result - promote winner
function ix.factions.ApplyVoteResult(voteID, winnerCharID, tallies)
    local vote = ix.factions.activeVotes[voteID]
    if not vote then return end

    -- Update database with vote results
    local query = mysql:Update("ix_faction_votes")
    query:Update("status", "completed")
    query:Update("results", util.TableToJSON(tallies))
    query:Update("winner_char_id", winnerCharID)
    query:Update("anchor_class_id", vote.anchorClassID)  -- Store for offline promotion
    query:Where("id", voteID)
    query:Execute()

    -- Find winner player (may be offline)
    local winnerPlayer, winnerChar = nil, nil
    for _, ply in player.Iterator() do
        local char = ply:GetCharacter()
        if char and char:GetID() == winnerCharID then
            winnerPlayer = ply
            winnerChar = char
            break
        end
    end

    local classData = ix.class.Get(vote.anchorClassID)

    if winnerPlayer and winnerChar then
        -- Winner is online - promote immediately
        winnerChar:SetClass(vote.anchorClassID)
        hook.Run("PlayerJoinedClass", winnerPlayer, vote.anchorClassID, winnerChar:GetClass())

        if classData then
            winnerPlayer:NotifyLocalized("electedLeader", classData.name)
        end

        -- Mark promotion as applied
        local updateQuery = mysql:Update("ix_faction_votes")
        updateQuery:Update("promotion_applied", 1)
        updateQuery:Where("id", voteID)
        updateQuery:Execute()
    else
        -- Winner is offline - update character directly in database
        -- The class will be applied when they log in, and they'll be notified via PlayerLoadedCharacter hook
        -- DO NOT set promotion_applied = 1 here - that happens when they log in and are notified
        local charQuery = mysql:Update("ix_characters")
        charQuery:Update("class", vote.anchorClassID)
        charQuery:Where("id", winnerCharID)
        charQuery:Callback(function()
            print("[Factions] Updated offline character #" .. winnerCharID .. " to class " .. vote.anchorClassID .. " (will be notified on login)")
        end)
        charQuery:Execute()
    end

    -- Announce results
    local winnerName = "Unknown"
    if vote.candidates then
        for _, cand in ipairs(vote.candidates) do
            if cand.char_id == winnerCharID then
                winnerName = cand.name
                break
            end
        end
    end

    ix.factions.AnnounceResults(vote.factionID, tallies, winnerCharID, winnerName)

    -- Cleanup
    timer.Remove("ixVote_" .. voteID)
    timer.Remove("ixVoteReminder_" .. voteID)
    ix.factions.activeVotes[voteID] = nil

    print("[Factions] Vote #" .. voteID .. " completed. Winner: " .. winnerName)
end

-- Handle case when no candidates qualify
function ix.factions.HandleNoValidCandidate(voteID)
    local vote = ix.factions.activeVotes[voteID]
    if not vote then return end

    -- Update database
    local query = mysql:Update("ix_faction_votes")
    query:Update("status", "completed")
    query:Update("results", util.TableToJSON({}))
    query:Where("id", voteID)
    query:Execute()

    -- Notify faction that no one qualified
    for _, ply in player.Iterator() do
        if ply:Team() == vote.factionID then
            ply:ChatPrint("[Faction] The succession vote has ended with no valid candidates. The leadership position remains vacant.")
        end
    end

    -- Cleanup
    timer.Remove("ixVote_" .. voteID)
    timer.Remove("ixVoteReminder_" .. voteID)
    ix.factions.activeVotes[voteID] = nil
end

-- Notify faction members about vote start
function ix.factions.NotifyVoteStarted(factionID, positionName)
    local factionData = ix.faction.Get(factionID)
    if not factionData then return end

    for _, ply in player.Iterator() do
        if ply:Team() == factionID then
            net.Start("ixVoteStarted")
                net.WriteString(factionData.name)
                net.WriteString(positionName)
                net.WriteUInt(os.time() + (24 * 60 * 60), 32)
            net.Send(ply)
        end
    end
end

-- Send vote reminders to members who haven't voted
function ix.factions.SendVoteReminders(voteID)
    local vote = ix.factions.activeVotes[voteID]
    if not vote then return end

    local classData = ix.class.Get(vote.anchorClassID)
    local positionName = classData and classData.name or "Leader"

    -- Get list of members who haven't voted
    local query = mysql:Select("ix_faction_ballots")
    query:Where("vote_id", voteID)
    query:Callback(function(result)
        local voted = {}
        if result then
            for _, ballot in ipairs(result) do
                voted[ballot.char_id] = true
            end
        end

        local hoursLeft = math.floor((vote.endsAt - os.time()) / 3600)

        -- Notify members who haven't voted
        for _, ply in player.Iterator() do
            if ply:Team() == vote.factionID then
                local char = ply:GetCharacter()
                if char and not voted[char:GetID()] then
                    net.Start("ixVoteReminder")
                        net.WriteString(positionName)
                        net.WriteUInt(hoursLeft, 8)
                    net.Send(ply)
                end
            end
        end
    end)
    query:Execute()
end

-- Announce vote results to faction
function ix.factions.AnnounceResults(factionID, tallies, winnerCharID, winnerName)
    local classData = nil
    for voteID, vote in pairs(ix.factions.activeVotes or {}) do
        if vote.factionID == factionID then
            classData = ix.class.Get(vote.anchorClassID)
            break
        end
    end

    local positionName = classData and classData.name or "Leader"
    local voteCount = tallies[winnerCharID] or 0

    for _, ply in player.Iterator() do
        if ply:Team() == factionID then
            net.Start("ixVoteEnded")
                net.WriteString(positionName)
                net.WriteString(winnerName)
                net.WriteUInt(voteCount, 16)
            net.Send(ply)
        end
    end
end

-- Check for pending election promotions for a character
local function CheckPendingPromotion(client, character)
    if not IsValid(client) or not character then return end
    if client:GetCharacter() ~= character then return end  -- Character changed

    -- Ensure migration is complete before querying
    if not ix.factions.bootstrapComplete then
        timer.Simple(2, function()
            CheckPendingPromotion(client, character)
        end)
        return
    end

    local charID = character:GetID()

    -- Check if this character won a vote while offline (promotion_applied = 0 means they weren't notified)
    local query = mysql:Select("ix_faction_votes")
    query:Where("winner_char_id", charID)
    query:Where("status", "completed")
    query:Where("promotion_applied", 0)  -- Only if they haven't been notified
    query:Callback(function(result)
        if not result or #result == 0 then return end
        if not IsValid(client) then return end

        -- Found a vote they won while offline
        local row = result[1]
        local anchorClassID = row.anchor_class_id

        if anchorClassID then
            local classData = ix.class.Get(anchorClassID)
            if classData then
                -- Notify them of their promotion
                client:NotifyLocalized("electedLeader", classData.name)

                -- Fire the hook (class is already set from DB load)
                hook.Run("PlayerJoinedClass", client, anchorClassID, nil)
            end
        end

        -- Mark as applied so they don't get notified again
        local updateQuery = mysql:Update("ix_faction_votes")
        updateQuery:Update("promotion_applied", 1)
        updateQuery:Where("id", row.id)
        updateQuery:Execute()
    end)
    query:Execute()
end

-- Notify winners who were offline during vote completion
hook.Add("PlayerLoadedCharacter", "ixCheckPendingPromotion", function(client, character, lastChar)
    if not character then return end

    -- Wait for vote table migration to complete before querying promotion_applied column
    if not ix.factions.bootstrapComplete then
        -- Retry after migration should be complete
        timer.Simple(3, function()
            CheckPendingPromotion(client, character)
        end)
        return
    end

    CheckPendingPromotion(client, character)
end)

-- Load active votes from database on server start
hook.Add("InitPostEntity", "ixLoadActiveVotes", function()
    timer.Simple(6, function()  -- After migration runs
        local query = mysql:Select("ix_faction_votes")
        query:Where("status", "active")
        query:Callback(function(result)
            if not result then return end

            for _, row in ipairs(result) do
                local factionData = ix.faction.teams[row.faction]
                if factionData then
                    ix.factions.activeVotes[row.id] = {
                        id = row.id,
                        factionID = factionData.index,
                        anchorClassID = nil,  -- Would need to look up
                        candidates = util.JSONToTable(row.candidates) or {},
                        startedAt = row.started_at,
                        endsAt = row.ends_at,
                    }

                    -- Resume timer if vote hasn't ended
                    local remaining = row.ends_at - os.time()
                    if remaining > 0 then
                        timer.Create("ixVote_" .. row.id, remaining, 1, function()
                            ix.factions.EndVote(row.id)
                        end)
                    else
                        -- Vote should have ended, process it now
                        ix.factions.EndVote(row.id)
                    end
                end
            end

            if #result > 0 then
                print("[Factions] Loaded " .. #result .. " active vote(s) from database")
            end
        end)
        query:Execute()
    end)
end)
