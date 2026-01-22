--[[
    Physical Description UI Components

    Custom derma panels for the physical attribute selection system.
    Used during character creation.

    Note: Labels are handled externally by Helix's character creation system.
    These panels only contain the controls themselves.

    Pattern follows ixNumSlider from Helix - no nested containers, direct docking.
]]--

-- ============================================================================
-- PHYSICAL SLIDER
-- A slider with dual-unit display (e.g., height in cm + ft'in")
-- Follows ixNumSlider pattern from Helix
-- ============================================================================

local PANEL = {}

AccessorFunc(PANEL, "displayMode", "DisplayMode", FORCE_STRING)
AccessorFunc(PANEL, "labelPadding", "LabelPadding", FORCE_NUMBER)

function PANEL:Init()
    self.displayMode = "number" -- number, height, weight, age
    self.labelPadding = 8

    surface.SetFont("ixMenuButtonFont")
    local totalWidth = surface.GetTextSize("000 lbs (000 kg)") + self.labelPadding
    local _, fontHeight = surface.GetTextSize("W@")

    -- Set panel height based on font (like ixTextEntry does)
    self:SetTall(fontHeight)

    -- Value display (right side) - follows ixNumSlider pattern
    self.label = self:Add("DLabel")
    self.label:Dock(RIGHT)
    self.label:SetWide(totalWidth)
    self.label:SetContentAlignment(5)
    self.label:SetFont("ixMenuButtonFont")
    self.label:SetTextColor(color_white)
    self.label.Paint = function(panel, width, height)
        surface.SetDrawColor(derma.GetColor("DarkerBackground", self))
        surface.DrawRect(0, 0, width, height)
    end

    -- Slider (fills remaining space) - follows ixNumSlider pattern
    self.slider = self:Add("ixSlider")
    self.slider:Dock(FILL)
    self.slider:DockMargin(0, 0, 4, 0)
    self.slider.OnValueChanged = function(panel)
        self:OnValueChanged()
    end
    self.slider.OnValueUpdated = function(panel)
        self:UpdateDisplay()
        self:OnValueUpdated()
    end
end

function PANEL:SetDisplayMode(mode)
    self.displayMode = mode
    self:UpdateDisplay()
end

function PANEL:SetHeightGetter(fn)
    self.heightGetter = fn
end

function PANEL:UpdateDisplay()
    local value = math.floor(self.slider:GetValue())
    local displayText = tostring(value)

    if self.displayMode == "height" then
        local feet, inches = ix.physical.CmToImperial(value)
        displayText = string.format("%d cm (%d'%d\")", value, feet, inches)
    elseif self.displayMode == "weight" then
        local kg = ix.physical.LbsToKg(value)
        displayText = string.format("%d lbs (%d kg)", value, kg)
    elseif self.displayMode == "age" then
        displayText = string.format("%d years", value)
    end

    self.label:SetText(displayText)
end

function PANEL:SetValue(value, bNoNotify)
    value = tonumber(value) or self.slider:GetMin()
    self.slider:SetValue(value, bNoNotify)
    self:UpdateDisplay()
end

function PANEL:GetValue()
    return self.slider:GetValue()
end

function PANEL:GetFraction()
    return self.slider:GetFraction()
end

function PANEL:SetMin(value)
    self.slider:SetMin(value)
end

function PANEL:SetMax(value)
    self.slider:SetMax(value)
end

function PANEL:GetMin()
    return self.slider:GetMin()
end

function PANEL:GetMax()
    return self.slider:GetMax()
end

function PANEL:SetDecimals(value)
    self.slider:SetDecimals(value)
end

function PANEL:GetDecimals()
    return self.slider:GetDecimals()
end

-- Called when slider is released
function PANEL:OnValueChanged()
end

-- Called while dragging
function PANEL:OnValueUpdated()
end

vgui.Register("ixPhysicalSlider", PANEL, "Panel")

-- ============================================================================
-- PHYSICAL DROPDOWN
-- A styled dropdown for physical attributes
-- ============================================================================

PANEL = {}

function PANEL:Init()
    self.options = {}
    self.currentValue = nil

    -- Set panel height based on font (like ixTextEntry does)
    surface.SetFont("ixMenuButtonFont")
    local _, fontHeight = surface.GetTextSize("W@")
    self:SetTall(fontHeight)

    -- Combo box - docks to fill entire panel
    self.combo = self:Add("DComboBox")
    self.combo:Dock(FILL)
    self.combo:SetFont("ixMenuButtonFont")
    self.combo:SetTextColor(color_white)
    self.combo:SetSortItems(false) -- Keep original order, don't sort alphabetically
    self.combo.OnSelect = function(panel, index, value, data)
        self.currentValue = value
        self:OnValueChanged()
    end

    -- Style the combo box
    self.combo.Paint = function(panel, width, height)
        surface.SetDrawColor(derma.GetColor("DarkerBackground", self))
        surface.DrawRect(0, 0, width, height)

        -- Draw border
        surface.SetDrawColor(60, 60, 60)
        surface.DrawOutlinedRect(0, 0, width, height)
    end

    -- Limit dropdown height so it scrolls instead of going off-screen
    local oldOpenMenu = self.combo.OpenMenu
    self.combo.OpenMenu = function(combo, ...)
        oldOpenMenu(combo, ...)
        if IsValid(combo.Menu) then
            combo.Menu:SetMaxHeight(300)
        end
    end
end

function PANEL:SetOptions(options)
    self.combo:Clear()
    self.options = options or {}

    for i, option in ipairs(self.options) do
        self.combo:AddChoice(option, option)
    end

    -- Select first option by default
    if #self.options > 0 then
        self.combo:ChooseOptionID(1)
        self.currentValue = self.options[1]
    end
end

function PANEL:SetValue(value)
    for i, option in ipairs(self.options) do
        if option == value then
            self.combo:ChooseOptionID(i)
            self.currentValue = value
            return
        end
    end
end

function PANEL:GetValue()
    return self.currentValue or self.options[1]
end

function PANEL:SetEnabled(enabled)
    self.combo:SetEnabled(enabled)

    if enabled then
        self.combo:SetTextColor(color_white)
    else
        self.combo:SetTextColor(Color(100, 100, 100))
    end
end

-- Called when selection changes
function PANEL:OnValueChanged()
end

vgui.Register("ixPhysicalDropdown", PANEL, "Panel")

-- ============================================================================
-- PHYSICAL BUILD DISPLAY
-- Shows calculated build based on height/weight (read-only)
-- ============================================================================

PANEL = {}

function PANEL:Init()
    self.build = "average"
    self.bmi = 22

    -- Set panel height based on font (like ixTextEntry does)
    surface.SetFont("ixMenuButtonFont")
    local _, fontHeight = surface.GetTextSize("W@")
    self:SetTall(fontHeight)

    -- Value display - fills entire panel
    self.valueLabel = self:Add("DLabel")
    self.valueLabel:Dock(FILL)
    self.valueLabel:SetFont("ixMenuButtonFont")
    self.valueLabel:SetTextColor(color_white)
    self.valueLabel:SetText("Average")
    self.valueLabel:SetContentAlignment(4) -- Left align
    self.valueLabel.Paint = function(panel, width, height)
        surface.SetDrawColor(derma.GetColor("DarkerBackground", self))
        surface.DrawRect(0, 0, width, height)
    end
end

function PANEL:SetBuild(build, bmi)
    self.build = build
    self.bmi = bmi

    local displayBuild = build:sub(1,1):upper() .. build:sub(2)
    self.valueLabel:SetText(string.format("%s (BMI: %.1f)", displayBuild, bmi))
end

function PANEL:GetBuild()
    return self.build
end

vgui.Register("ixPhysicalBuildDisplay", PANEL, "Panel")
