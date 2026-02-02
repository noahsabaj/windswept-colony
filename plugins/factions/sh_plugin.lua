--[[
    Factions Plugin for Windswept

    Dynamic faction governance system featuring:
    - Runtime class CRUD (create/update/delete)
    - Rank hierarchy (0-255 scale)
    - 9-permission delegation system
    - Faction invites with accept/deny
    - Succession system with approval voting
    - Physical ballot stations for voting
]]--

PLUGIN.name = "Factions"
PLUGIN.author = "Windswept Team"
PLUGIN.description = "Dynamic faction governance with classes, permissions, and succession."

-- Initialize faction system namespace
ix.factions = ix.factions or {}
ix.factions.activeVotes = ix.factions.activeVotes or {}

-- Network strings
if SERVER then
    util.AddNetworkString("ixClassListSync")        -- Server->Client: Full class list
    util.AddNetworkString("ixClassCreated")         -- Server->Client: New class added
    util.AddNetworkString("ixClassUpdated")         -- Server->Client: Class modified
    util.AddNetworkString("ixClassDeleted")         -- Server->Client: Class removed
    util.AddNetworkString("ixFactionInvite")        -- Server->Client: Invite popup
    util.AddNetworkString("ixFactionInviteResponse")-- Client->Server: Accept/Decline
    util.AddNetworkString("ixFactionInfoOpen")      -- Server->Client: Open faction info panel
    util.AddNetworkString("ixVoteStarted")          -- Server->Client: New vote notification
    util.AddNetworkString("ixVoteReminder")         -- Server->Client: Hourly reminder
    util.AddNetworkString("ixVoteEnded")            -- Server->Client: Results notification
    util.AddNetworkString("ixBallotOpen")           -- Server->Client: Open ballot UI
    util.AddNetworkString("ixBallotSubmit")         -- Client->Server: Submit vote
    util.AddNetworkString("ixBallotClose")          -- Client->Server: Close ballot UI
end

-- Register log types (must be done after Helix initializes, server-only)
function PLUGIN:InitializedPlugins()
    if not SERVER then return end

    ix.log.AddType("succession", function(client, ...)
        local arg = {...}
        return string.format("%s transferred leadership to %s.", client:Name(), arg[1])
    end)

    ix.log.AddType("successionNone", function(client, ...)
        return string.format("%s resigned with no available successor.", client:Name())
    end)

    ix.log.AddType("successionAuto", function(client, ...)
        local arg = {...}
        return string.format("%s resigned; %s was auto-promoted.", client:Name(), arg[1])
    end)

    ix.log.AddType("successionVote", function(client, ...)
        return string.format("%s resigned, triggering a succession vote.", client:Name())
    end)

    ix.log.AddType("classCreate", function(client, ...)
        local arg = {...}
        return string.format("%s created class '%s' at rank %d.", client:Name(), arg[1], arg[2])
    end)

    ix.log.AddType("classDelete", function(client, ...)
        local arg = {...}
        return string.format("%s deleted class '%s'.", client:Name(), arg[1])
    end)

    ix.log.AddType("classUpdate", function(client, ...)
        local arg = {...}
        return string.format("%s updated class '%s' (%s = %s).", client:Name(), arg[1], arg[2], tostring(arg[3]))
    end)

    ix.log.AddType("classAssign", function(client, ...)
        local arg = {...}
        return string.format("%s assigned %s to class '%s'.", client:Name(), arg[1], arg[2])
    end)

    ix.log.AddType("permGrant", function(client, ...)
        local arg = {...}
        return string.format("%s granted '%s' permission to class '%s'.", client:Name(), arg[1], arg[2])
    end)

    ix.log.AddType("permRevoke", function(client, ...)
        local arg = {...}
        return string.format("%s revoked '%s' permission from class '%s'.", client:Name(), arg[1], arg[2])
    end)

    ix.log.AddType("factionJoin", function(client, ...)
        local arg = {...}
        return string.format("%s joined %s as %s.", client:Name(), arg[1], arg[2])
    end)

    ix.log.AddType("factionRemove", function(client, ...)
        local arg = {...}
        return string.format("%s removed %s from the faction.", client:Name(), arg[1])
    end)

    ix.log.AddType("factionResign", function(client, ...)
        local arg = {...}
        return string.format("%s resigned from class '%s'.", client:Name(), arg[1])
    end)

    ix.log.AddType("voteDropout", function(client, ...)
        return string.format("%s dropped out of the succession vote.", client:Name())
    end)
end

-- Include server and client files
ix.util.Include("sh_factionperms.lua")  -- Permission system (must load before commands)
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_commands.lua")
ix.util.Include("sv_succession.lua")
ix.util.Include("sv_migration.lua")
