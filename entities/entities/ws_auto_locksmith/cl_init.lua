--[[
    Locksmith Machine - Client

    Renders the machine with visual feedback.
]]--

include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    -- Draw "IN USE" indicator if someone is using it
    if self:GetInUse() then
        local pos = self:GetPos() + Vector(0, 0, 30)
        local ang = (LocalPlayer():GetPos() - pos):Angle()
        ang:RotateAroundAxis(ang:Up(), -90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        cam.Start3D2D(pos, ang, 0.1)
            draw.SimpleText("IN USE", "wsMediumFont", 0, 0, Color(255, 200, 50, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end

-- Draw usage hint when looking at it
-- Throttled eye trace to reduce per-frame overhead
local locksmithHintCache = {
    ent = nil,
    text1 = nil,
    text2 = nil,
    lastCheck = 0
}
local LOCKSMITH_HINT_INTERVAL = 0.1  -- Check every 0.1 seconds

hook.Add("HUDPaint", "wsLocksmithHint", function()
    local now = CurTime()

    -- Throttle eye trace check
    if now - locksmithHintCache.lastCheck >= LOCKSMITH_HINT_INTERVAL then
        locksmithHintCache.lastCheck = now

        local ply = LocalPlayer()
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity

        if not IsValid(ent) or ent:GetClass() ~= "ws_auto_locksmith" or ply:GetPos():DistToSqr(ent:GetPos()) > (150 * 150) then
            locksmithHintCache.ent = nil
            locksmithHintCache.text1 = nil
            locksmithHintCache.text2 = nil
            return
        end

        locksmithHintCache.ent = ent
        if ent:GetInUse() and ent:GetUser() ~= ply then
            locksmithHintCache.text1 = "Machine is in use"
            locksmithHintCache.text2 = nil
        else
            locksmithHintCache.text1 = "Press E to use Locksmith"
            locksmithHintCache.text2 = "Hold E to pick up"
        end
    end

    -- Draw cached result
    if locksmithHintCache.ent and locksmithHintCache.text1 then
        local scrW, scrH = ScrW(), ScrH()
        draw.SimpleText(locksmithHintCache.text1, "wsSmallFont", scrW / 2, scrH * 0.6, Color(255, 255, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if locksmithHintCache.text2 then
            draw.SimpleText(locksmithHintCache.text2, "wsSmallFont", scrW / 2, scrH * 0.6 + 20, Color(200, 200, 200, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end)

-- Open locksmith UI when server tells us to
net.Receive("wsLocksmithOpen", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    -- Open the locksmith UI
    if IsValid(ws.gui.locksmith) then
        ws.gui.locksmith:Remove()
    end

    ws.gui.locksmith = vgui.Create("wsLocksmithMenu")
    ws.gui.locksmith:SetStation(ent)
end)

-- Handle results from server
net.Receive("wsLocksmithResult", function()
    local resultType = net.ReadString()

    if resultType == "viewKeyings" then
        local count = net.ReadUInt(8)
        local keyings = {}
        for i = 1, count do
            table.insert(keyings, net.ReadString())
        end

        -- Show keyings popup
        local frame = vgui.Create("DFrame")
        frame:SetSize(300, 100 + count * 25)
        frame:SetTitle("Lock Keyings")
        frame:Center()
        frame:MakePopup()

        local y = 30
        for i, keying in ipairs(keyings) do
            local label = vgui.Create("DLabel", frame)
            label:SetPos(20, y)
            label:SetSize(260, 20)
            label:SetText(i .. ". " .. keying)
            label:SetTextColor(Color(255, 255, 255))
            y = y + 25
        end

        if count == 0 then
            local label = vgui.Create("DLabel", frame)
            label:SetPos(20, y)
            label:SetSize(260, 20)
            label:SetText("No keyings programmed.")
            label:SetTextColor(Color(150, 150, 150))
        end
    end
end)
