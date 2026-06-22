--[[
    Client frame visualization: receive synced frames and draw pulsing
    indicators on empty frames while holding the door-install tool.

    Split from the former schema/libs/sh_doors.lua god-file (PR-4 hygiene);
    public ws.doors.* API unchanged. See sh_doors.lua for the load order.
]]--

ws.doors = ws.doors or {}

ws.doors.clientFrames = ws.doors.clientFrames or {}

local FRAME_PULSE_DISTANCE = 240
local framePulseTime = 0

-- Receive frame data from server
net.Receive("wsDoorsSync", function()
    local count = net.ReadUInt(16)
    ws.doors.clientFrames = {}

    for i = 1, count do
        local mapID = net.ReadUInt(32)
        local pos = net.ReadVector()
        local ang = net.ReadAngle()
        local hasDoor = net.ReadBool()
        local disabled = net.ReadBool()

        ws.doors.clientFrames[mapID] = {
            pos = pos,
            ang = ang,
            hasDoor = hasDoor,
            disabled = disabled
        }
    end
end)

-- Draw pulsating indicators for empty frames when holding a door
hook.Add("PostDrawTranslucentRenderables", "wsDoorsFramePulse", function(_, bSkybox)
    if bSkybox then return end

    local ply = LocalPlayer()
    local weapon = ply:GetActiveWeapon()

    if not IsValid(weapon) then return end
    if weapon:GetClass() ~= "ws_door" then return end

    -- Animate pulse
    framePulseTime = framePulseTime + FrameTime() * 3
    local pulse = math.sin(framePulseTime) * 0.5 + 0.5

    -- Draw pulsating effect for empty frames
    for mapID, frameData in pairs(ws.doors.clientFrames) do
        if not frameData.hasDoor and not frameData.disabled then
            local dist = ply:GetPos():Distance(frameData.pos)
            if dist < FRAME_PULSE_DISTANCE then
                local alpha = 1 - (dist / FRAME_PULSE_DISTANCE)
                alpha = alpha * pulse * 150

                -- Draw a pulsating rectangle at the frame position
                local pos = frameData.pos + Vector(0, 0, 40)

                render.SetColorMaterial()
                render.DrawSphere(pos, 16 + pulse * 8, 16, 16, Color(100, 200, 100, alpha))

                -- Draw vertical line for frame
                render.DrawLine(frameData.pos, frameData.pos + Vector(0, 0, 80), Color(100, 200, 100, alpha * 0.5), false)
            end
        end
    end
end)
