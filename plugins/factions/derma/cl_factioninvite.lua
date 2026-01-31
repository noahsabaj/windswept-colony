--[[
    Faction Invite Panel
    Shows popup when player receives a faction invitation
    15 second timeout with accept/decline buttons
]]--

local PANEL = {}

local COLOR_BG = Color(35, 35, 40, 245)
local COLOR_HEADER = Color(50, 100, 150)
local COLOR_ACCEPT = Color(60, 140, 60)
local COLOR_DECLINE = Color(140, 60, 60)

function PANEL:Init()
    self.timeout = 15
    self.startTime = CurTime()

    self:SetSize(350, 180)
    self:Center()
    self:MakePopup()
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(false)
end

function PANEL:SetData(data)
    self.data = data

    -- Header
    self.header = self:Add("DPanel")
    self.header:Dock(TOP)
    self.header:SetTall(40)
    self.header.Paint = function(pnl, w, h)
        draw.RoundedBoxEx(4, 0, 0, w, h, COLOR_HEADER, true, true, false, false)
        draw.SimpleText("FACTION INVITE", "ixMediumFont", w/2, h/2,
            color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Content
    self.content = self:Add("DPanel")
    self.content:Dock(FILL)
    self.content:DockMargin(15, 15, 15, 15)
    self.content.Paint = function() end

    local text = string.format(
        "You have been invited to join\n%s as %s\n\nInvited by: %s",
        data.factionName,
        data.className,
        data.inviterName
    )

    self.label = self.content:Add("DLabel")
    self.label:Dock(TOP)
    self.label:SetTall(60)
    self.label:SetText(text)
    self.label:SetFont("ixSmallFont")
    self.label:SetTextColor(color_white)
    self.label:SetContentAlignment(5)

    -- Timer label (added before buttons so it appears above them)
    self.timerLabel = self.content:Add("DLabel")
    self.timerLabel:Dock(BOTTOM)
    self.timerLabel:SetTall(20)
    self.timerLabel:DockMargin(0, 5, 0, 5)
    self.timerLabel:SetFont("ixSmallFont")
    self.timerLabel:SetTextColor(Color(180, 180, 180))
    self.timerLabel:SetContentAlignment(5)

    -- Buttons
    self.buttonPanel = self.content:Add("DPanel")
    self.buttonPanel:Dock(BOTTOM)
    self.buttonPanel:SetTall(35)
    self.buttonPanel.Paint = function() end

    self.acceptBtn = self.buttonPanel:Add("DButton")
    self.acceptBtn:SetText("Accept")
    self.acceptBtn:Dock(LEFT)
    self.acceptBtn:SetWide(140)
    self.acceptBtn:SetFont("ixSmallFont")
    self.acceptBtn.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, pnl:IsHovered() and COLOR_ACCEPT or Color(50, 120, 50))
        draw.SimpleText(pnl:GetText(), "ixSmallFont", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.acceptBtn.DoClick = function()
        net.Start("ixFactionInviteResponse")
            net.WriteBool(true)
            net.WriteUInt(self.data.factionID, 8)
            net.WriteUInt(self.data.classIndex, 16)
        net.SendToServer()
        self:Remove()
    end

    self.declineBtn = self.buttonPanel:Add("DButton")
    self.declineBtn:SetText("Decline")
    self.declineBtn:Dock(RIGHT)
    self.declineBtn:SetWide(140)
    self.declineBtn:SetFont("ixSmallFont")
    self.declineBtn.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, pnl:IsHovered() and COLOR_DECLINE or Color(120, 50, 50))
        draw.SimpleText(pnl:GetText(), "ixSmallFont", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.declineBtn.DoClick = function()
        net.Start("ixFactionInviteResponse")
            net.WriteBool(false)
        net.SendToServer()
        self:Remove()
    end
end

function PANEL:Think()
    local elapsed = CurTime() - self.startTime
    local remaining = math.max(0, self.timeout - elapsed)

    if self.timerLabel and IsValid(self.timerLabel) then
        self.timerLabel:SetText(string.format("Auto-decline in: %ds", math.ceil(remaining)))
    end

    if remaining <= 0 then
        net.Start("ixFactionInviteResponse")
            net.WriteBool(false)
        net.SendToServer()
        self:Remove()
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, COLOR_BG)
    surface.SetDrawColor(80, 80, 90)
    surface.DrawOutlinedRect(0, 0, w, h)
end

vgui.Register("ixFactionInvitePanel", PANEL, "DFrame")
