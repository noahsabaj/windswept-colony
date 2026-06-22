--[[
    Server->client frame sync (full broadcast + per-player on join).

    Split from the former schema/libs/sh_doors.lua god-file (PR-4 hygiene);
    public ws.doors.* API unchanged. See sh_doors.lua for the load order.
]]--

ws.doors = ws.doors or {}

-- Sync frame data to a client
function ws.doors.SyncToPlayer(ply)
    local count = table.Count(ws.doors.frames)
    if count == 0 then return end

    net.Start("wsDoorsSync")
        net.WriteUInt(count, 16)
        for mapID, frameData in pairs(ws.doors.frames) do
            net.WriteUInt(mapID, 32)
            net.WriteVector(frameData.pos)
            net.WriteAngle(frameData.ang)
            net.WriteBool(frameData.hasDoor or false)
            net.WriteBool(frameData.disabled or false)
        end
    net.Send(ply)
end

-- Sync frame data to all clients
function ws.doors.SyncToAll()
    local count = table.Count(ws.doors.frames)
    if count == 0 then return end

    net.Start("wsDoorsSync")
        net.WriteUInt(count, 16)
        for mapID, frameData in pairs(ws.doors.frames) do
            net.WriteUInt(mapID, 32)
            net.WriteVector(frameData.pos)
            net.WriteAngle(frameData.ang)
            net.WriteBool(frameData.hasDoor or false)
            net.WriteBool(frameData.disabled or false)
        end
    net.Broadcast()
end

-- Sync when player joins
hook.Add("PlayerInitialSpawn", "wsDoorsSyncOnJoin", function(ply)
    -- Delay to ensure everything is loaded
    timer.Simple(3, function()
        if IsValid(ply) then
            ws.doors.SyncToPlayer(ply)
        end
    end)
end)
