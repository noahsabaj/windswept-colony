--[[
    Ballot Panel
    Shows succession vote UI with candidate selection
    Approval voting - select all acceptable candidates
]]--

local PANEL = {}

local COLOR_BG = Color(35, 35, 40, 250)
local COLOR_HEADER = Color(50, 80, 120)
local COLOR_CANDIDATE = Color(50, 55, 60)
local COLOR_SELECTED = Color(60, 100, 60)

function PANEL:Init()
    self:SetSize(400, 450)
    self:SetTitle("")
    self:Center()
    self:MakePopup()
    self:SetDraggable(true)

    self.station = nil
    self.voteInfo = nil
    self.selectedCandidates = {}
end

function PANEL:SetStation(station)
    self.station = station
end

function PANEL:SetVoteInfo(voteInfo)
    self.voteInfo = voteInfo
    self:BuildUI()
end

function PANEL:BuildUI()
    -- Clear existing
    if self.container then
        self.container:Remove()
    end

    self.container = self:Add("DPanel")
    self.container:Dock(FILL)
    self.container:DockMargin(10, 40, 10, 10)
    self.container.Paint = function() end

    if not self.voteInfo then
        -- No active vote
        local label = self.container:Add("DLabel")
        label:Dock(FILL)
        label:SetText("No active votes in your faction.")
        label:SetFont("ixMediumFont")
        label:SetTextColor(Color(180, 180, 180))
        label:SetContentAlignment(5)
        return
    end

    if self.voteInfo.hasVoted then
        -- Already voted
        local label = self.container:Add("DLabel")
        label:Dock(TOP)
        label:SetTall(50)
        label:SetText("You have already cast your ballot.")
        label:SetFont("ixMediumFont")
        label:SetTextColor(Color(100, 180, 100))
        label:SetContentAlignment(5)

        -- Show time remaining
        local timeLabel = self.container:Add("DLabel")
        timeLabel:Dock(TOP)
        timeLabel:SetTall(30)
        timeLabel:SetFont("ixSmallFont")
        timeLabel:SetTextColor(Color(180, 180, 180))
        timeLabel:SetContentAlignment(5)
        timeLabel.Think = function(pnl)
            if not self.voteInfo then return end
            local remaining = self.voteInfo.endsAt - os.time()
            if remaining > 0 then
                local hours = math.floor(remaining / 3600)
                local mins = math.floor((remaining % 3600) / 60)
                pnl:SetText(string.format("Vote ends in: %dh %dm", hours, mins))
            else
                pnl:SetText("Vote has ended")
            end
        end
        return
    end

    -- Header
    local header = self.container:Add("DLabel")
    header:Dock(TOP)
    header:SetTall(40)
    header:SetText("EMERGENCY SUCCESSION VOTE")
    header:SetFont("ixMediumFont")
    header:SetTextColor(color_white)
    header:SetContentAlignment(5)

    -- Instructions
    local instructions = self.container:Add("DLabel")
    instructions:Dock(TOP)
    instructions:SetTall(40)
    instructions:SetText("Select all candidates you would accept as leader:")
    instructions:SetFont("ixSmallFont")
    instructions:SetTextColor(Color(200, 200, 200))
    instructions:SetContentAlignment(5)

    -- Time remaining (add before candidate list)
    local timeLabel = self.container:Add("DLabel")
    timeLabel:Dock(BOTTOM)
    timeLabel:DockMargin(0, 5, 0, 0)
    timeLabel:SetTall(20)
    timeLabel:SetFont("ixSmallFont")
    timeLabel:SetTextColor(Color(180, 180, 180))
    timeLabel:SetContentAlignment(5)
    timeLabel.Think = function(pnl)
        if not self.voteInfo then return end
        local remaining = self.voteInfo.endsAt - os.time()
        if remaining > 0 then
            local hours = math.floor(remaining / 3600)
            local mins = math.floor((remaining % 3600) / 60)
            pnl:SetText(string.format("Vote ends in: %dh %dm", hours, mins))
        else
            pnl:SetText("Vote has ended")
        end
    end

    -- Submit button
    self.submitBtn = self.container:Add("DButton")
    self.submitBtn:Dock(BOTTOM)
    self.submitBtn:SetTall(40)
    self.submitBtn:SetText("Submit Ballot")
    self.submitBtn:SetFont("ixMediumFont")
    self.submitBtn.Paint = function(pnl, w, h)
        local col = pnl:IsHovered() and Color(60, 120, 60) or Color(50, 100, 50)
        draw.RoundedBox(4, 0, 0, w, h, col)
        draw.SimpleText(pnl:GetText(), "ixMediumFont", w/2, h/2,
            color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.submitBtn.DoClick = function()
        self:SubmitBallot()
    end

    -- Candidate list
    self.candidateList = self.container:Add("DScrollPanel")
    self.candidateList:Dock(FILL)
    self.candidateList:DockMargin(0, 10, 0, 10)

    if self.voteInfo.candidates then
        for _, cand in ipairs(self.voteInfo.candidates) do
            local candPanel = self.candidateList:Add("DButton")
            candPanel:Dock(TOP)
            candPanel:DockMargin(5, 5, 5, 0)
            candPanel:SetTall(50)
            candPanel:SetText("")
            candPanel.charID = cand.charID
            candPanel.selected = false

            candPanel.Paint = function(pnl, w, h)
                local col = pnl.selected and COLOR_SELECTED or
                            (pnl:IsHovered() and Color(60, 65, 70) or COLOR_CANDIDATE)
                draw.RoundedBox(4, 0, 0, w, h, col)

                -- Checkbox
                local checkX = 15
                local checkY = h/2 - 10
                surface.SetDrawColor(80, 80, 90)
                surface.DrawOutlinedRect(checkX, checkY, 20, 20)

                if pnl.selected then
                    draw.SimpleText("X", "ixMediumFont", checkX + 10, checkY + 10,
                        Color(100, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                -- Name
                draw.SimpleText(cand.name, "ixMediumFont", 50, h/2,
                    color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            candPanel.DoClick = function(pnl)
                pnl.selected = not pnl.selected

                if pnl.selected then
                    self.selectedCandidates[pnl.charID] = true
                else
                    self.selectedCandidates[pnl.charID] = nil
                end
            end
        end
    end
end

function PANEL:SubmitBallot()
    if not self.voteInfo then return end

    local approvals = {}
    for charID, _ in pairs(self.selectedCandidates) do
        table.insert(approvals, charID)
    end

    net.Start("ixBallotSubmit")
        net.WriteUInt(self.voteInfo.voteID, 32)
        net.WriteTable(approvals)
    net.SendToServer()

    self:Remove()
end

function PANEL:Think()
    -- Close if too far from station
    if IsValid(self.station) then
        local dist = LocalPlayer():GetPos():Distance(self.station:GetPos())
        if dist > 200 then
            self:Remove()
        end
    end
end

function PANEL:OnRemove()
    if IsValid(self.station) then
        net.Start("ixBallotClose")
            net.WriteEntity(self.station)
        net.SendToServer()
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, COLOR_BG)

    -- Header bar
    draw.RoundedBoxEx(4, 0, 0, w, 35, COLOR_HEADER, true, true, false, false)
    draw.SimpleText("Ballot Station", "ixMediumFont", w/2, 17,
        color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(60, 60, 70)
    surface.DrawOutlinedRect(0, 0, w, h)
end

vgui.Register("ixBallotPanel", PANEL, "DFrame")
