--[[
    Radio Frequency Picker UI

    Custom digit-spinner for setting radio frequency.
    Format: ###.# (e.g., 456.3)

    Uses font-based dynamic sizing for proper scaling.
]]--

if SERVER then return end

-- Colors (matching Personal ID card style)
local COLOR_BACKGROUND = Color(35, 35, 35, 250)
local COLOR_DIGIT_BG = Color(50, 50, 50)
local COLOR_DIGIT_BORDER = Color(80, 80, 80)
local COLOR_ARROW = Color(255, 255, 255, 150)
local COLOR_ARROW_HOVER = Color(255, 255, 255, 255)
local COLOR_TEXT = Color(255, 255, 255)
local COLOR_DECIMAL = ws.constants.COLOR_UI_NEUTRAL

local PANEL = {}

function PANEL:Init()
    self.digits = {0, 0, 0, 0}  -- ###.#
    self.confirmedDigits = {0, 0, 0, 0}  -- Last confirmed state

    -- Calculate sizes based on fonts
    surface.SetFont("wsBigFont")
    local digitTextW, digitTextH = surface.GetTextSize("0")

    surface.SetFont("wsMediumFont")
    local _, arrowTextH = surface.GetTextSize("▲")
    local _, headerTextH = surface.GetTextSize("Set Frequency")

    surface.SetFont("wsSmallFont")
    local _, buttonTextH = surface.GetTextSize("Confirm")

    -- Store computed sizes
    self.digitSize = math.max(digitTextW, digitTextH) + ScreenScale(12)  -- Digit box size with padding
    self.arrowHeight = arrowTextH + ScreenScale(4)  -- Arrow clickable area
    self.headerHeight = headerTextH + ScreenScale(8)  -- Header with padding
    self.buttonHeight = buttonTextH + ScreenScale(10)  -- Button height
    self.padding = ScreenScale(8)  -- General padding
    self.digitSpacing = ScreenScale(6)  -- Space between digits
    self.decimalWidth = ScreenScale(10)  -- Space for decimal point

    -- Calculate total width needed
    local digitAreaWidth = (self.digitSize * 4) + (self.digitSpacing * 3) + self.decimalWidth
    local panelWidth = digitAreaWidth + (self.padding * 4)

    -- Calculate total height
    local digitAreaHeight = self.arrowHeight + self.digitSize + self.arrowHeight
    local panelHeight = self.headerHeight + self.padding + digitAreaHeight + self.padding + self.buttonHeight + self.padding

    self:SetSize(panelWidth, panelHeight)
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(false)
    self:MakePopup()
    self:Center()

    self:BuildUI()
end

function PANEL:BuildUI()
    -- Header
    self.header, self.closeBtn = ws.constants.CreateHeaderBar(self, "Set Frequency", self.headerHeight, function()
        self:Remove()
    end)

    -- Digit area container
    local digitAreaHeight = self.arrowHeight + self.digitSize + self.arrowHeight
    self.digitArea = self:Add("DPanel")
    self.digitArea:Dock(TOP)
    self.digitArea:DockMargin(self.padding, self.padding, self.padding, 0)
    self.digitArea:SetTall(digitAreaHeight)

    local digitSize = self.digitSize
    local digitSpacing = self.digitSpacing
    local decimalWidth = self.decimalWidth
    local arrowHeight = self.arrowHeight

    self.digitArea.Paint = function(pnl, w, h)
        -- Draw decimal point between 3rd and 4th digit
        local totalWidth = (digitSize * 4) + (digitSpacing * 3) + decimalWidth
        local decimalX = (w - totalWidth) / 2 + (digitSize * 3) + (digitSpacing * 3) + (decimalWidth / 2)
        local decimalY = arrowHeight + digitSize - ScreenScale(4)

        draw.SimpleText("•", "wsBigFont", decimalX, decimalY, COLOR_DECIMAL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Create digit spinners
    self.digitPanels = {}
    self:CreateDigitSpinners()

    -- Button area
    self.buttonArea = self:Add("DPanel")
    self.buttonArea:Dock(BOTTOM)
    self.buttonArea:DockMargin(self.padding, 0, self.padding, self.padding)
    self.buttonArea:SetTall(self.buttonHeight)
    self.buttonArea.Paint = function() end

    -- Calculate button width based on text
    surface.SetFont("wsSmallFont")
    local cancelW = surface.GetTextSize("Cancel")
    local resetW = surface.GetTextSize("Reset")
    local confirmW = surface.GetTextSize("Confirm")
    local buttonPadding = ScreenScale(10)
    local buttonWidth = math.max(cancelW, resetW, confirmW) + buttonPadding * 2

    -- Cancel button
    self.cancelBtn = self.buttonArea:Add("DButton")
    self.cancelBtn:SetText("Cancel")
    self.cancelBtn:SetFont("wsSmallFont")
    self.cancelBtn:SetTextColor(ws.constants.COLOR_UI_NEUTRAL)
    self.cancelBtn:Dock(LEFT)
    self.cancelBtn:SetWide(buttonWidth)
    self.cancelBtn.Paint = function(btn, w, h)
        local bg = btn:IsHovered() and Color(60, 60, 60) or Color(45, 45, 45)
        draw.RoundedBox(4, 0, 0, w, h, bg)
        surface.SetDrawColor(80, 80, 80)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    self.cancelBtn.DoClick = function()
        -- Revert to last confirmed
        for i = 1, 4 do
            self.digits[i] = self.confirmedDigits[i]
        end
        surface.PlaySound("buttons/button10.wav")
    end

    -- Confirm button
    self.confirmBtn = self.buttonArea:Add("DButton")
    self.confirmBtn:SetText("Confirm")
    self.confirmBtn:SetFont("wsSmallFont")
    self.confirmBtn:SetTextColor(ws.constants.COLOR_UI_NEUTRAL)
    self.confirmBtn:Dock(RIGHT)
    self.confirmBtn:SetWide(buttonWidth)
    self.confirmBtn.Paint = function(btn, w, h)
        local bg = btn:IsHovered() and Color(40, 70, 40) or Color(30, 58, 30)
        draw.RoundedBox(4, 0, 0, w, h, bg)
        surface.SetDrawColor(60, 100, 60)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    self.confirmBtn.DoClick = function()
        local freq = self:GetFrequencyString()
        ws.command.Send("SetFreq", freq)

        -- Update confirmed state
        for i = 1, 4 do
            self.confirmedDigits[i] = self.digits[i]
        end

        surface.PlaySound("buttons/button9.wav")
        self:Remove()
    end

    -- Reset button (center)
    self.resetBtn = self.buttonArea:Add("DButton")
    self.resetBtn:SetText("Reset")
    self.resetBtn:SetFont("wsSmallFont")
    self.resetBtn:SetTextColor(ws.constants.COLOR_UI_NEUTRAL)
    self.resetBtn:Dock(FILL)
    self.resetBtn:DockMargin(self.digitSpacing, 0, self.digitSpacing, 0)
    self.resetBtn.Paint = function(btn, w, h)
        local bg = btn:IsHovered() and Color(60, 60, 60) or Color(45, 45, 45)
        draw.RoundedBox(4, 0, 0, w, h, bg)
        surface.SetDrawColor(80, 80, 80)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    self.resetBtn.DoClick = function()
        for i = 1, 4 do
            self.digits[i] = 0
        end
        surface.PlaySound("buttons/button10.wav")
    end
end

function PANEL:SetFrequency(freqString)
    -- Parse "###.#" format into digits
    local d1, d2, d3, d4 = freqString:match("(%d)(%d)(%d)%.(%d)")
    if d1 then
        self.digits = {tonumber(d1), tonumber(d2), tonumber(d3), tonumber(d4)}
        self.confirmedDigits = {tonumber(d1), tonumber(d2), tonumber(d3), tonumber(d4)}
    end
end

function PANEL:GetFrequencyString()
    return string.format("%d%d%d.%d", self.digits[1], self.digits[2], self.digits[3], self.digits[4])
end

function PANEL:CreateDigitSpinners()
    local digitSize = self.digitSize
    local digitSpacing = self.digitSpacing
    local decimalWidth = self.decimalWidth
    local arrowHeight = self.arrowHeight
    local totalWidth = (digitSize * 4) + (digitSpacing * 3) + decimalWidth

    -- Position digits when panel is laid out
    self.digitArea.PerformLayout = function(pnl, w, h)
        local xPos = (w - totalWidth) / 2

        for i = 1, 4 do
            if IsValid(self.digitPanels[i]) then
                self.digitPanels[i]:SetPos(xPos, 0)
                xPos = xPos + digitSize + digitSpacing

                -- Add decimal space after 3rd digit
                if i == 3 then
                    xPos = xPos + decimalWidth - digitSpacing  -- Replace spacing with decimal width
                end
            end
        end
    end

    for i = 1, 4 do
        local digitPanel = self.digitArea:Add("DPanel")
        digitPanel:SetSize(digitSize, arrowHeight + digitSize + arrowHeight)
        digitPanel.digitIndex = i
        digitPanel.parent = self

        digitPanel.Paint = function(pnl, w, h)
            local midY = arrowHeight

            -- Up arrow
            local upHovered = pnl.upHovered
            local upColor = upHovered and COLOR_ARROW_HOVER or COLOR_ARROW
            draw.SimpleText("▲", "wsMediumFont", w/2, arrowHeight/2, upColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Digit box
            draw.RoundedBox(4, 0, midY, w, digitSize, COLOR_DIGIT_BG)
            surface.SetDrawColor(COLOR_DIGIT_BORDER)
            surface.DrawOutlinedRect(0, midY, w, digitSize)

            -- Digit text
            local digit = pnl.parent.digits[pnl.digitIndex] or 0
            draw.SimpleText(tostring(digit), "wsBigFont", w/2, midY + digitSize/2, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Down arrow
            local downY = midY + digitSize
            local downHovered = pnl.downHovered
            local downColor = downHovered and COLOR_ARROW_HOVER or COLOR_ARROW
            draw.SimpleText("▼", "wsMediumFont", w/2, downY + arrowHeight/2, downColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        digitPanel.OnCursorMoved = function(pnl, x, y)
            pnl.upHovered = y < arrowHeight
            pnl.downHovered = y > arrowHeight + digitSize
        end

        digitPanel.OnCursorExited = function(pnl)
            pnl.upHovered = false
            pnl.downHovered = false
        end

        digitPanel.OnMousePressed = function(pnl, keyCode)
            if keyCode ~= MOUSE_LEFT then return end

            local _, y = pnl:CursorPos()
            local idx = pnl.digitIndex

            if y < arrowHeight then
                -- Up arrow clicked
                pnl.parent.digits[idx] = (pnl.parent.digits[idx] + 1) % 10
                surface.PlaySound("buttons/lightswitch2.wav")
            elseif y > arrowHeight + digitSize then
                -- Down arrow clicked
                pnl.parent.digits[idx] = (pnl.parent.digits[idx] - 1) % 10
                if pnl.parent.digits[idx] < 0 then
                    pnl.parent.digits[idx] = 9
                end
                surface.PlaySound("buttons/lightswitch2.wav")
            end
        end

        self.digitPanels[i] = digitPanel
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, COLOR_BACKGROUND)
    surface.SetDrawColor(60, 60, 60, 255)
    surface.DrawOutlinedRect(0, 0, w, h)
end

function PANEL:OnKeyCodePressed(key)
    if key == KEY_ESCAPE then
        self:Remove()
        return true
    end
end

vgui.Register("wsRadioFrequency", PANEL, "DFrame")
