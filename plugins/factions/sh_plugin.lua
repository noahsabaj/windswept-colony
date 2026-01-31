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

-- Include server and client files
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_commands.lua")
ix.util.Include("sv_succession.lua")
ix.util.Include("sv_migration.lua")
