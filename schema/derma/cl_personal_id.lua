--[[
    Personal ID UI Components

    Custom derma panels for Personal ID card display and birth date selection.
]]--

-- ============================================================================
-- BIRTH DATE PICKER
-- Month/Day spinners for character creation
-- ============================================================================

DEFINE_BASECLASS("Panel")
local PANEL = {}

function PANEL:Init()
    self.month = 1
    self.day = 1
    self.age = 25

    -- Set panel height based on font
    surface.SetFont("ixMenuButtonFont")
    local _, fontHeight = surface.GetTextSize("W@")
    self:SetTall(fontHeight)

    -- Day dropdown (RIGHT side) - uses ixPhysicalDropdown for consistent styling
    self.dayDropdown = self:Add("ixPhysicalDropdown")
    self.dayDropdown:Dock(RIGHT)
    self.dayDropdown:SetWide(80)
    self.dayDropdown.OnValueChanged = function()
        self.day = tonumber(self.dayDropdown:GetValue()) or 1
        self:OnValueChanged()
    end

    -- Populate days 1-31
    local dayOptions = {}
    for i = 1, 31 do
        dayOptions[i] = tostring(i)
    end
    self.dayDropdown:SetOptions(dayOptions)

    -- Spacer
    local spacer = self:Add("Panel")
    spacer:Dock(RIGHT)
    spacer:SetWide(8)

    -- Month dropdown (FILL remaining space)
    self.monthDropdown = self:Add("ixPhysicalDropdown")
    self.monthDropdown:Dock(FILL)
    self.monthDropdown.OnValueChanged = function()
        -- Find month index from name
        for i, name in ipairs(ix.birthdata.months) do
            if name == self.monthDropdown:GetValue() then
                self.month = i
                break
            end
        end
        self:UpdateDayOptions()
        self:OnValueChanged()
    end

    -- Populate months
    self.monthDropdown:SetOptions(ix.birthdata.months)
end

function PANEL:UpdateDayOptions()
    local maxDay = ix.birthdata.GetMaxDay(self.month, self.age)
    local currentDay = self.day

    -- Rebuild day options for current month
    local dayOptions = {}
    for i = 1, maxDay do
        dayOptions[i] = tostring(i)
    end
    self.dayDropdown:SetOptions(dayOptions)

    -- Keep current day if valid, otherwise use max
    if currentDay > maxDay then
        self.day = maxDay
    end
    self.dayDropdown:SetValue(tostring(self.day))
end

function PANEL:SetMonth(month)
    month = math.Clamp(tonumber(month) or 1, 1, 12)
    self.month = month
    self.monthDropdown:SetValue(ix.birthdata.months[month])
    self:UpdateDayOptions()
end

function PANEL:SetDay(day)
    local maxDay = ix.birthdata.GetMaxDay(self.month, self.age)
    day = math.Clamp(tonumber(day) or 1, 1, maxDay)
    self.day = day
    self.dayDropdown:SetValue(tostring(day))
end

function PANEL:SetAge(age)
    self.age = tonumber(age) or 25
    self:UpdateDayOptions()
end

function PANEL:GetMonth()
    return self.month
end

function PANEL:GetDay()
    return self.day
end

function PANEL:OnValueChanged()
    -- Override this
end

vgui.Register("ixBirthDatePicker", PANEL, "Panel")

-- ============================================================================
-- PERSONAL ID CARD
-- Visual ID card display using Helix tooltip row system for proper spacing
-- ============================================================================

DEFINE_BASECLASS("EditablePanel")

-- Colors
local COLOR_BACKGROUND = Color(35, 35, 35, 250)
local COLOR_HEADER = Color(30, 58, 95)
local COLOR_DIVIDER = Color(80, 80, 80)

local PANEL = {}

function PANEL:Init()
    self.data = {}
    self.isRecipientMode = false
    self.dismissFraction = 1 -- For countdown bar animation

    -- Main container with padding
    self.container = self:Add("DListLayout")
    self.container:Dock(FILL)
    self.container:DockMargin(0, 0, 0, 0)
end

function PANEL:AddHeader(text)
    local header = self.container:Add("DPanel")
    header:SetTall(36)
    header:Dock(TOP)
    header.text = text
    header.Paint = function(pnl, w, h)
        draw.RoundedBoxEx(4, 0, 0, w, h, COLOR_HEADER, true, true, false, false)

        surface.SetFont("ixMediumFont")
        local tw, th = surface.GetTextSize(pnl.text)
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(12, (h - th) / 2)
        surface.DrawText(pnl.text)
    end

    -- Close button
    local closeBtn = header:Add("DButton")
    closeBtn:SetSize(24, 24)
    closeBtn:Dock(RIGHT)
    closeBtn:DockMargin(0, 6, 6, 6)
    closeBtn:SetText("×")
    closeBtn:SetFont("ixMediumFont")
    closeBtn:SetTextColor(Color(200, 200, 200))
    closeBtn.Paint = function(btn, w, h)
        if btn:IsHovered() then
            surface.SetDrawColor(255, 255, 255, 30)
            surface.DrawRect(0, 0, w, h)
        end
    end
    closeBtn.DoClick = function()
        self:Remove()
    end

    self.closeButton = closeBtn
    return header
end

function PANEL:AddSubtitle(text)
    local row = self.container:Add("DLabel")
    row:SetFont("ixSmallFont")
    row:SetText(text)
    row:SetTextColor(Color(160, 160, 160))
    row:SetContentAlignment(4)
    row:Dock(TOP)
    row:DockMargin(12, 6, 12, 2)
    row:SizeToContents()
    row:SetTall(row:GetTall() + 4)
    return row
end

function PANEL:AddDivider()
    local divider = self.container:Add("DPanel")
    divider:SetTall(9)
    divider:Dock(TOP)
    divider:DockMargin(12, 4, 12, 4)
    divider.Paint = function(pnl, w, h)
        surface.SetDrawColor(COLOR_DIVIDER)
        surface.DrawRect(0, 4, w, 1)
    end
    return divider
end

function PANEL:AddTextRow(text)
    local row = self.container:Add("DLabel")
    row:SetFont("ixSmallFont")
    row:SetText(text)
    row:SetTextColor(Color(224, 224, 224))
    row:SetContentAlignment(4)
    row:Dock(TOP)
    row:DockMargin(12, 2, 12, 2)
    row:SizeToContents()
    row:SetTall(row:GetTall() + 6) -- Add vertical padding
    return row
end

function PANEL:AddSpacer(height)
    local spacer = self.container:Add("DPanel")
    spacer:SetTall(height or 8)
    spacer:Dock(TOP)
    spacer.Paint = function() end
    return spacer
end

function PANEL:SetData(data)
    self.data = data or {}

    -- Clear container
    self.container:Clear()

    -- Header
    self:AddHeader("Personal ID")

    -- Subtitle
    self:AddSubtitle("Colonial Identification Card")

    -- Divider
    self:AddDivider()

    -- Primary info
    self:AddTextRow("Name: " .. (data.ownerName or "Unknown"))
    self:AddTextRow("ID#: " .. (data.id or "00000"))
    self:AddTextRow("Sex: " .. (data.sex or "M"))
    self:AddTextRow("DOB: " .. (data.dob or "Unknown"))
    self:AddTextRow("Origin: " .. (data.birthLocation or "Unspecified"))

    -- Divider
    self:AddDivider()

    -- Physical info
    if data.age then
        self:AddTextRow("Age: " .. data.age)
    end

    if data.height then
        local feet, inches = ix.physical.CmToImperial(data.height)
        self:AddTextRow(string.format("Height: %d'%d\" (%dcm)", feet, inches, data.height))
    end

    if data.weight then
        local kg = ix.physical.LbsToKg(data.weight)
        self:AddTextRow(string.format("Weight: %dlbs (%dkg)", data.weight, kg))
    end

    if data.build then
        local buildStr = data.build:sub(1, 1):upper() .. data.build:sub(2)
        self:AddTextRow("Build: " .. buildStr)
    end

    -- Divider
    self:AddDivider()

    -- Appearance info
    if data.eyeColor then
        self:AddTextRow("Eyes: " .. data.eyeColor)
    end

    if data.hairLength then
        if data.hairLength == "Bald" then
            self:AddTextRow("Hair: Bald")
        elseif data.hairColor and data.hairType then
            self:AddTextRow(string.format("Hair: %s, %s, %s",
                data.hairColor,
                data.hairType,
                data.hairLength
            ))
        end
    end

    if data.skinTone then
        self:AddTextRow("Skin: " .. data.skinTone)
    end

    -- Bottom padding
    self:AddSpacer(8)

    -- Calculate size based on content (Helix-idiomatic pattern from ixTooltip)
    self:InvalidateLayout(true)

    -- Find max width needed - children already sized via SizeToContents()
    local maxWidth = 0
    local totalHeight = 0

    for _, child in ipairs(self.container:GetChildren()) do
        local left, top, right, bottom = child:GetDockMargin()
        local childWidth = child:GetWide() + left + right

        if childWidth > maxWidth then
            maxWidth = childWidth
        end

        totalHeight = totalHeight + child:GetTall() + top + bottom
    end

    maxWidth = math.max(maxWidth, 200) -- Reasonable minimum
    self:SetSize(maxWidth, totalHeight)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, COLOR_BACKGROUND)

    -- Border
    surface.SetDrawColor(60, 60, 60, 255)
    surface.DrawOutlinedRect(0, 0, w, h)

    -- Auto-dismiss countdown bar for recipient mode
    if self.isRecipientMode and self.dismissFraction > 0 then
        local barHeight = 3
        surface.SetDrawColor(40, 40, 40, 255)
        surface.DrawRect(0, h - barHeight, w, barHeight)
        surface.SetDrawColor(COLOR_HEADER.r, COLOR_HEADER.g, COLOR_HEADER.b, 255)
        surface.DrawRect(0, h - barHeight, w * self.dismissFraction, barHeight)
    end
end

function PANEL:SetSelfViewMode()
    self.isRecipientMode = false
    self:Center()
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)

    -- Play sound
    surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav")
end

function PANEL:SetRecipientMode()
    self.isRecipientMode = true

    -- Position bottom-right
    local scrW, scrH = ScrW(), ScrH()
    self:SetPos(scrW - self:GetWide() - 20, scrH - self:GetTall() - 20)

    -- Fully non-blocking
    self:SetMouseInputEnabled(true)

    -- Play sound
    surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav")

    -- Auto-dismiss animation (Helix-idiomatic pattern)
    self:CreateAnimation(10, {
        target = {dismissFraction = 0},
        easing = "linear",
        OnComplete = function(animation, panel)
            panel:Remove()
        end
    })
end

function PANEL:OnKeyCodePressed(key)
    if key == KEY_ESCAPE then
        self:Remove()
        return true
    end
end

vgui.Register("ixPersonalIDCard", PANEL, "EditablePanel")
