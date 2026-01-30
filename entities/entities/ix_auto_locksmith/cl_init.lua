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
            draw.SimpleText("IN USE", "ixMediumFont", 0, 0, Color(255, 200, 50, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end

-- Draw usage hint when looking at it
hook.Add("HUDPaint", "ixLocksmithHint", function()
    local ply = LocalPlayer()
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid(ent) then return end
    if ent:GetClass() ~= "ix_auto_locksmith" then return end
    if ply:GetPos():Distance(ent:GetPos()) > 150 then return end

    local scrW, scrH = ScrW(), ScrH()
    local text = "Press E to use Locksmith"

    if ent:GetInUse() and ent:GetUser() ~= ply then
        text = "Machine is in use"
    end

    draw.SimpleText(text, "ixSmallFont", scrW / 2, scrH * 0.6, Color(255, 255, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- Open locksmith UI when server tells us to
net.Receive("ixLocksmithOpen", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    -- Open the locksmith UI
    if IsValid(ix.gui.locksmith) then
        ix.gui.locksmith:Remove()
    end

    ix.gui.locksmith = vgui.Create("ixLocksmithMenu")
    ix.gui.locksmith:SetStation(ent)
end)

-- Handle results from server
net.Receive("ixLocksmithResult", function()
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
