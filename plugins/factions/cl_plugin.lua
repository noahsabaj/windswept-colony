--[[
    Factions Plugin - Client-Side
    Handles faction invite popups and UI
]]--

-- Handle faction invite
net.Receive("ixFactionInvite", function()
    local factionName = net.ReadString()
    local className = net.ReadString()
    local inviterName = net.ReadString()
    local factionID = net.ReadUInt(8)
    local classIndex = net.ReadUInt(16)

    -- Remove existing invite panel
    if IsValid(ix.gui.factionInvite) then
        ix.gui.factionInvite:Remove()
    end

    -- Create invite panel
    ix.gui.factionInvite = vgui.Create("ixFactionInvitePanel")
    ix.gui.factionInvite:SetData({
        factionName = factionName,
        className = className,
        inviterName = inviterName,
        factionID = factionID,
        classIndex = classIndex,
    })
end)

-- Handle faction info panel open
net.Receive("ixFactionInfoOpen", function()
    local factionName = net.ReadString()
    local classes = net.ReadTable()
    local members = net.ReadTable()

    if IsValid(ix.gui.factionInfo) then
        ix.gui.factionInfo:Remove()
    end

    ix.gui.factionInfo = vgui.Create("ixFactionInfoPanel")
    ix.gui.factionInfo:SetData(factionName, classes, members)
end)

-- Handle ballot UI open
net.Receive("ixBallotOpen", function()
    local ent = net.ReadEntity()
    local hasVote = net.ReadBool()

    if IsValid(ix.gui.ballot) then
        ix.gui.ballot:Remove()
    end

    local voteInfo = nil
    if hasVote then
        voteInfo = net.ReadTable()
    end

    ix.gui.ballot = vgui.Create("ixBallotPanel")
    ix.gui.ballot:SetStation(ent)
    ix.gui.ballot:SetVoteInfo(voteInfo)
end)

-- Handle vote started notification
net.Receive("ixVoteStarted", function()
    local factionName = net.ReadString()
    local positionName = net.ReadString()
    local endsAt = net.ReadUInt(32)

    local remaining = endsAt - os.time()
    local hours = math.floor(remaining / 3600)

    LocalPlayer():ChatPrint(string.format(
        "[Faction] A succession vote has started for %s in %s. Vote ends in %d hours. Visit a ballot station to cast your vote.",
        positionName,
        factionName,
        hours
    ))
end)

-- Handle vote reminder
net.Receive("ixVoteReminder", function()
    local positionName = net.ReadString()
    local hoursLeft = net.ReadUInt(8)

    LocalPlayer():ChatPrint(string.format(
        "[Faction] Reminder: The vote for %s ends in %d hour(s). Visit a ballot station if you haven't voted yet.",
        positionName,
        hoursLeft
    ))
end)

-- Handle vote ended notification
net.Receive("ixVoteEnded", function()
    local positionName = net.ReadString()
    local winnerName = net.ReadString()
    local voteCount = net.ReadUInt(16)

    LocalPlayer():ChatPrint(string.format(
        "[Faction] The succession vote for %s has concluded. %s has been elected with %d approval(s).",
        positionName,
        winnerName,
        voteCount
    ))
end)
