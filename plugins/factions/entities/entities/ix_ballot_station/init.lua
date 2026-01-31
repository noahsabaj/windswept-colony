--[[
    Ballot Station Entity - Server
    Handles player interaction and vote lookup
]]--

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props/cs_militia/mailbox01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end

    self:SetInUse(false)
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local character = activator:GetCharacter()
    if not character then
        activator:NotifyLocalized("noCharacter")
        return
    end

    local faction = activator:Team()
    if not faction or faction == TEAM_UNASSIGNED then
        activator:NotifyLocalized("notInFaction")
        return
    end

    -- Check if faction is FACTION_PRISONERS
    local factionData = ix.faction.Get(faction)
    if factionData and factionData.uniqueID == "prisoners" then
        activator:NotifyLocalized("prisonersCannotVote")
        return
    end

    -- Check for active vote in player's faction
    local activeVote = nil
    for voteID, vote in pairs(ix.factions.activeVotes or {}) do
        if vote.factionID == faction then
            activeVote = vote
            activeVote.id = voteID
            break
        end
    end

    -- Gather vote info
    if activeVote then
        -- Check if already voted (async query)
        local query = mysql:Select("ix_faction_ballots")
        query:Where("vote_id", activeVote.id)
        query:Where("char_id", character:GetID())
        query:Callback(function(result)
            local hasVoted = result and #result > 0

            local voteInfo = {
                voteID = activeVote.id,
                hasVoted = hasVoted,
                candidates = {},
                endsAt = activeVote.endsAt or (os.time() + 86400),
                timeRemaining = (activeVote.endsAt or (os.time() + 86400)) - os.time(),
            }

            if activeVote.candidates then
                for _, cand in ipairs(activeVote.candidates) do
                    if not cand.dropped then
                        table.insert(voteInfo.candidates, {
                            charID = cand.char_id,
                            name = cand.name,
                        })
                    end
                end
            end

            -- Send to client
            net.Start("ixBallotOpen")
                net.WriteEntity(self)
                net.WriteBool(true)
                net.WriteTable(voteInfo)
            net.Send(activator)
        end)
        query:Execute()
    else
        -- No active vote
        net.Start("ixBallotOpen")
            net.WriteEntity(self)
            net.WriteBool(false)
        net.Send(activator)
    end
end
