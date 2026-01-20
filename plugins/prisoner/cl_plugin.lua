--[[
    Prisoner System - Client Side

    Handles:
    - Blindness effect when gagged
    - Sentencing UI
    - Prison management UI
    - Prison card view UI
]]--

print("[Prisoner] cl_plugin.lua is loading...")

-- Blindness effect when gagged
function PLUGIN:RenderScreenspaceEffects()
    if LocalPlayer():GetNetVar("gagged") then
        DrawColorModify({
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -1,
            ["$pp_colour_contrast"] = 0,
            ["$pp_colour_colour"] = 0,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    end
end

-- Block HUD when gagged
function PLUGIN:HUDShouldDraw(name)
    if LocalPlayer():GetNetVar("gagged") then
        if name ~= "CHudGMod" then
            return false
        end
    end
end

-- Sentencing UI Panel
local PANEL = {}

function PANEL:Init()
    self:SetSize(400, 250)
    self:Center()
    self:SetTitle("Sentencing")
    self:MakePopup()

    self.target = nil

    -- Target name label
    self.nameLabel = self:Add("DLabel")
    self.nameLabel:SetPos(10, 30)
    self.nameLabel:SetSize(380, 20)
    self.nameLabel:SetFont("ixMediumFont")
    self.nameLabel:SetText("Sentencing: Unknown")

    -- Duration label
    local durLabel = self:Add("DLabel")
    durLabel:SetPos(10, 60)
    durLabel:SetSize(100, 20)
    durLabel:SetText("Duration (seconds):")

    -- Duration entry
    self.durationEntry = self:Add("DTextEntry")
    self.durationEntry:SetPos(120, 60)
    self.durationEntry:SetSize(270, 25)
    self.durationEntry:SetNumeric(true)
    self.durationEntry:SetText("300")

    -- Reason label
    local reasonLabel = self:Add("DLabel")
    reasonLabel:SetPos(10, 95)
    reasonLabel:SetSize(100, 20)
    reasonLabel:SetText("Reason:")

    -- Reason entry
    self.reasonEntry = self:Add("DTextEntry")
    self.reasonEntry:SetPos(10, 115)
    self.reasonEntry:SetSize(380, 60)
    self.reasonEntry:SetMultiline(true)
    self.reasonEntry:SetText("")

    -- Confirm button
    self.confirmButton = self:Add("DButton")
    self.confirmButton:SetPos(10, 185)
    self.confirmButton:SetSize(380, 40)
    self.confirmButton:SetText("Confirm Sentence")
    self.confirmButton.DoClick = function()
        self:SubmitSentence()
    end
end

function PANEL:SetTarget(target)
    self.target = target
    if IsValid(target) then
        self.nameLabel:SetText("Sentencing: " .. target:Name())
    end
end

function PANEL:SubmitSentence()
    if not IsValid(self.target) then
        self:Close()
        return
    end

    local duration = tonumber(self.durationEntry:GetValue()) or 0
    local reason = self.reasonEntry:GetValue()

    if duration < 1 then
        Derma_Message("Duration must be at least 1 second.", "Error", "OK")
        return
    end

    if reason == "" then
        reason = "No reason specified"
    end

    net.Start("ixPrisonerSentenceSubmit")
    net.WriteEntity(self.target)
    net.WriteUInt(duration, 32)
    net.WriteString(reason)
    net.SendToServer()

    self:Close()
end

vgui.Register("ixSentencingPanel", PANEL, "DFrame")

-- Prison Management UI Panel
PANEL = {}

function PANEL:Init()
    self:SetSize(400, 350)
    self:Center()
    self:SetTitle("Prison Management")
    self:MakePopup()

    self.target = nil

    -- Prisoner name
    self.nameLabel = self:Add("DLabel")
    self.nameLabel:SetPos(10, 30)
    self.nameLabel:SetSize(380, 20)
    self.nameLabel:SetFont("ixMediumFont")
    self.nameLabel:SetText("Prisoner: Unknown")

    -- Sentence info
    self.infoLabel = self:Add("DLabel")
    self.infoLabel:SetPos(10, 55)
    self.infoLabel:SetSize(380, 100)
    self.infoLabel:SetWrap(true)
    self.infoLabel:SetAutoStretchVertical(true)
    self.infoLabel:SetText("Loading...")

    -- Adjust label
    local adjustLabel = self:Add("DLabel")
    adjustLabel:SetPos(10, 165)
    adjustLabel:SetSize(200, 20)
    adjustLabel:SetText("Adjust sentence (+/- seconds):")

    -- Adjust entry
    self.adjustEntry = self:Add("DTextEntry")
    self.adjustEntry:SetPos(10, 185)
    self.adjustEntry:SetSize(270, 25)
    self.adjustEntry:SetText("0")

    -- Apply adjustment button
    self.adjustButton = self:Add("DButton")
    self.adjustButton:SetPos(290, 185)
    self.adjustButton:SetSize(100, 25)
    self.adjustButton:SetText("Apply")
    self.adjustButton.DoClick = function()
        self:ApplyAdjustment()
    end

    -- Release button
    self.releaseButton = self:Add("DButton")
    self.releaseButton:SetPos(10, 230)
    self.releaseButton:SetSize(380, 40)
    self.releaseButton:SetText("Release Now")
    self.releaseButton:SetColor(Color(255, 100, 100))
    self.releaseButton.DoClick = function()
        self:ReleaseNow()
    end

    -- Close button
    self.closeButton = self:Add("DButton")
    self.closeButton:SetPos(10, 280)
    self.closeButton:SetSize(380, 30)
    self.closeButton:SetText("Close")
    self.closeButton.DoClick = function()
        self:Close()
    end
end

function PANEL:SetTarget(target)
    self.target = target
    if not IsValid(target) then return end

    self.nameLabel:SetText("Prisoner: " .. target:Name())

    local character = target:GetCharacter()
    if not character then return end

    local sentence = character:GetData("sentence")
    if sentence then
        local remaining = math.max(0, sentence.duration - (sentence.timeServed or 0))
        local info = string.format(
            "Original Sentence: %d seconds\n" ..
            "Time Served: %d seconds\n" ..
            "Time Remaining: %d seconds\n\n" ..
            "Reason: %s\n" ..
            "Judge: %s\n" ..
            "Date: %s",
            sentence.duration,
            sentence.timeServed or 0,
            remaining,
            sentence.reason or "Unknown",
            sentence.judge or "Unknown",
            sentence.date or "Unknown"
        )
        self.infoLabel:SetText(info)
    else
        self.infoLabel:SetText("No sentence data found.")
    end
end

function PANEL:ApplyAdjustment()
    if not IsValid(self.target) then
        self:Close()
        return
    end

    local adjustment = tonumber(self.adjustEntry:GetValue()) or 0
    if adjustment == 0 then return end

    net.Start("ixPrisonerAdjust")
    net.WriteEntity(self.target)
    net.WriteInt(adjustment, 32)
    net.SendToServer()

    -- Refresh panel
    timer.Simple(0.5, function()
        if IsValid(self) and IsValid(self.target) then
            self:SetTarget(self.target)
        end
    end)
end

function PANEL:ReleaseNow()
    if not IsValid(self.target) then
        self:Close()
        return
    end

    Derma_Query(
        "Are you sure you want to release " .. self.target:Name() .. "?",
        "Confirm Release",
        "Yes", function()
            net.Start("ixPrisonerRelease")
            net.WriteEntity(self.target)
            net.SendToServer()
            self:Close()
        end,
        "No", function() end
    )
end

vgui.Register("ixPrisonerManagePanel", PANEL, "DFrame")

-- Prison Card View Panel
PANEL = {}

function PANEL:Init()
    self:SetSize(350, 280)
    self:Center()
    self:SetTitle("Prison Sentence Card")
    self:MakePopup()

    -- Card background
    self.cardPanel = self:Add("DPanel")
    self.cardPanel:SetPos(10, 30)
    self.cardPanel:SetSize(330, 230)
    self.cardPanel.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 255))
        draw.RoundedBox(4, 2, 2, w - 4, h - 4, Color(80, 80, 80, 255))

        -- Header
        draw.RoundedBoxEx(4, 2, 2, w - 4, 30, Color(200, 100, 0, 255), true, true, false, false)
        draw.SimpleText("PRISON SENTENCE CARD", "ixMediumFont", w / 2, 17, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Info label
    self.infoLabel = self.cardPanel:Add("DLabel")
    self.infoLabel:SetPos(15, 45)
    self.infoLabel:SetSize(300, 170)
    self.infoLabel:SetWrap(true)
    self.infoLabel:SetAutoStretchVertical(true)
    self.infoLabel:SetFont("ixSmallFont")
    self.infoLabel:SetText("")
end

function PANEL:SetCardData(data)
    local text = string.format(
        "Prisoner: %s\n\n" ..
        "Sentence: %s seconds\n\n" ..
        "Reason:\n%s\n\n" ..
        "Sentenced by: %s\n" ..
        "Date: %s",
        data.prisoner or "Unknown",
        data.duration or "0",
        data.reason or "None",
        data.judge or "Unknown",
        data.date or "Unknown"
    )
    self.infoLabel:SetText(text)
end

vgui.Register("ixPrisonCardPanel", PANEL, "DFrame")

-- Network receivers
net.Receive("ixPrisonerSentence", function()
    local target = net.ReadEntity()

    if IsValid(ix.gui.sentencing) then
        ix.gui.sentencing:Remove()
    end

    ix.gui.sentencing = vgui.Create("ixSentencingPanel")
    ix.gui.sentencing:SetTarget(target)
end)

net.Receive("ixPrisonerManage", function()
    local target = net.ReadEntity()

    if IsValid(ix.gui.prisonerManage) then
        ix.gui.prisonerManage:Remove()
    end

    ix.gui.prisonerManage = vgui.Create("ixPrisonerManagePanel")
    ix.gui.prisonerManage:SetTarget(target)
end)

net.Receive("ixPrisonCardView", function()
    local data = net.ReadTable()

    if IsValid(ix.gui.prisonCard) then
        ix.gui.prisonCard:Remove()
    end

    ix.gui.prisonCard = vgui.Create("ixPrisonCardPanel")
    ix.gui.prisonCard:SetCardData(data)
end)
