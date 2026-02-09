--[[
    Stationary Radio Entity - Client
]]--

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

-- Store reference to open UI panel
local activePanel = nil
local activeEntity = nil

-- Close active panel
local function ClosePanel()
    if IsValid(activePanel) then
        activePanel:Remove()
    end
    activePanel = nil

    if IsValid(activeEntity) then
        net.Start("ixStationaryRadioClose")
        net.WriteEntity(activeEntity)
        net.SendToServer()
    end
    activeEntity = nil
end

-- Create channel row
local function CreateChannelRow(parent, channelNum, ent)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(5, 5, 5, 0)
    row:SetTall(32)
    row:SetBackgroundColor(Color(40, 40, 40))

    -- Channel label
    local label = vgui.Create("DLabel", row)
    label:SetPos(8, 6)
    label:SetText("CH" .. channelNum)
    label:SetFont("ixSmallFont")
    label:SizeToContents()

    -- Frequency controls
    local freqPanel = vgui.Create("DPanel", row)
    freqPanel:SetPos(50, 4)
    freqPanel:SetSize(100, 24)
    freqPanel:SetBackgroundColor(Color(0, 0, 0, 0))

    local btnLeft = vgui.Create("DButton", freqPanel)
    btnLeft:SetPos(0, 0)
    btnLeft:SetSize(20, 24)
    btnLeft:SetText("<")
    btnLeft:SetFont("ixSmallFont")
    btnLeft.DoClick = function()
        local getter = ent["GetCh" .. channelNum .. "Freq"]
        if not getter then return end

        local currentFreq = getter(ent) or "100.0"
        local newFreq = ix.radio.DecrementFrequency(currentFreq)

        net.Start("ixStationaryRadioConfig")
        net.WriteEntity(ent)
        net.WriteUInt(channelNum, 3)
        net.WriteString("freq")
        net.WriteString(newFreq)
        net.SendToServer()
    end

    local freqLabel = vgui.Create("DLabel", freqPanel)
    freqLabel:SetPos(22, 4)
    freqLabel:SetSize(56, 16)
    freqLabel:SetContentAlignment(5) -- Center
    freqLabel:SetFont("ixSmallFont")

    local btnRight = vgui.Create("DButton", freqPanel)
    btnRight:SetPos(80, 0)
    btnRight:SetSize(20, 24)
    btnRight:SetText(">")
    btnRight:SetFont("ixSmallFont")
    btnRight.DoClick = function()
        local getter = ent["GetCh" .. channelNum .. "Freq"]
        if not getter then return end

        local currentFreq = getter(ent) or "100.0"
        local newFreq = ix.radio.IncrementFrequency(currentFreq)

        net.Start("ixStationaryRadioConfig")
        net.WriteEntity(ent)
        net.WriteUInt(channelNum, 3)
        net.WriteString("freq")
        net.WriteString(newFreq)
        net.SendToServer()
    end

    -- TX toggle
    local btnTX = vgui.Create("DButton", row)
    btnTX:SetPos(160, 4)
    btnTX:SetSize(60, 24)
    btnTX:SetFont("ixSmallFont")
    btnTX.DoClick = function()
        local getter = ent["GetCh" .. channelNum .. "TX"]
        if not getter then return end

        local newValue = not getter(ent)

        net.Start("ixStationaryRadioConfig")
        net.WriteEntity(ent)
        net.WriteUInt(channelNum, 3)
        net.WriteString("tx")
        net.WriteBool(newValue)
        net.SendToServer()
    end

    -- RX toggle
    local btnRX = vgui.Create("DButton", row)
    btnRX:SetPos(225, 4)
    btnRX:SetSize(60, 24)
    btnRX:SetFont("ixSmallFont")
    btnRX.DoClick = function()
        local getter = ent["GetCh" .. channelNum .. "RX"]
        if not getter then return end

        local newValue = not getter(ent)

        net.Start("ixStationaryRadioConfig")
        net.WriteEntity(ent)
        net.WriteUInt(channelNum, 3)
        net.WriteString("rx")
        net.WriteBool(newValue)
        net.SendToServer()
    end

    -- Volume label
    local volLabel = vgui.Create("DLabel", row)
    volLabel:SetPos(295, 6)
    volLabel:SetText("VOL")
    volLabel:SetFont("ixSmallFont")
    volLabel:SizeToContents()

    -- Volume slider
    local volSlider = vgui.Create("DSlider", row)
    volSlider:SetPos(325, 8)
    volSlider:SetSize(100, 16)
    volSlider:SetLockY(0.5)

    volSlider.OnValueChanged = function(self, x, y)
        local vol = math.floor(x * 100)

        net.Start("ixStationaryRadioConfig")
        net.WriteEntity(ent)
        net.WriteUInt(channelNum, 3)
        net.WriteString("vol")
        net.WriteUInt(vol, 7)
        net.SendToServer()
    end

    -- Think function to update display
    row.Think = function()
        if not IsValid(ent) then return end

        -- Update frequency display
        local getter = ent["GetCh" .. channelNum .. "Freq"]
        if getter then
            freqLabel:SetText(getter(ent) or "100.0")
        end

        -- Update TX button
        local txGetter = ent["GetCh" .. channelNum .. "TX"]
        if txGetter then
            local txOn = txGetter(ent)
            btnTX:SetText(txOn and "TX: ON" or "TX: OFF")
            if txOn then
                btnTX:SetTextColor(Color(255, 100, 100))
            else
                btnTX:SetTextColor(ix.constants.COLOR_UI_NEUTRAL)
            end
        end

        -- Update RX button
        local rxGetter = ent["GetCh" .. channelNum .. "RX"]
        if rxGetter then
            local rxOn = rxGetter(ent)
            btnRX:SetText(rxOn and "RX: ON" or "RX: OFF")
            if rxOn then
                btnRX:SetTextColor(Color(100, 255, 100))
            else
                btnRX:SetTextColor(ix.constants.COLOR_UI_NEUTRAL)
            end
        end

        -- Update volume slider
        local volGetter = ent["GetCh" .. channelNum .. "Vol"]
        if volGetter and not volSlider:IsEditing() then
            local vol = volGetter(ent) or 50
            volSlider:SetSlideX(vol / 100)
        end
    end

    return row
end

-- Create the main UI panel
local function OpenStationaryRadioUI(ent)
    if not IsValid(ent) then return end

    -- Close any existing panel
    ClosePanel()

    activeEntity = ent

    -- Create main frame
    local frame = vgui.Create("DFrame")
    frame:SetSize(450, 300)
    frame:Center()
    frame:SetTitle("DISPATCH CONSOLE")
    frame:SetDraggable(true)
    frame:MakePopup()
    frame:SetBackgroundBlur(true)

    frame.OnClose = function()
        ClosePanel()
    end

    activePanel = frame

    -- Channel rows container
    local channelContainer = vgui.Create("DPanel", frame)
    channelContainer:Dock(TOP)
    channelContainer:SetTall(150)
    channelContainer:DockMargin(5, 5, 5, 5)
    channelContainer:SetBackgroundColor(Color(30, 30, 30))

    -- Create 4 channel rows
    for i = 1, 4 do
        CreateChannelRow(channelContainer, i, ent)
    end

    -- Bottom panel for text input and mic
    local bottomPanel = vgui.Create("DPanel", frame)
    bottomPanel:Dock(BOTTOM)
    bottomPanel:SetTall(80)
    bottomPanel:DockMargin(5, 0, 5, 5)
    bottomPanel:SetBackgroundColor(Color(30, 30, 30))

    -- Text input
    local textEntry = vgui.Create("DTextEntry", bottomPanel)
    textEntry:SetPos(10, 10)
    textEntry:SetSize(420, 30)
    textEntry:SetPlaceholderText("Type message here...")
    textEntry:SetFont("ixSmallFont")

    textEntry.OnEnter = function(self)
        local msg = self:GetValue()
        if msg and msg ~= "" then
            net.Start("ixStationaryRadioTransmit")
            net.WriteEntity(ent)
            net.WriteString(msg)
            net.SendToServer()

            self:SetValue("")
        end
    end

    -- Transmit button
    local btnTransmit = vgui.Create("DButton", bottomPanel)
    btnTransmit:SetPos(260, 45)
    btnTransmit:SetSize(80, 28)
    btnTransmit:SetText("TRANSMIT")
    btnTransmit:SetFont("ixSmallFont")
    btnTransmit.DoClick = function()
        local msg = textEntry:GetValue()
        if msg and msg ~= "" then
            net.Start("ixStationaryRadioTransmit")
            net.WriteEntity(ent)
            net.WriteString(msg)
            net.SendToServer()

            textEntry:SetValue("")
        end
    end

    -- Mic toggle button
    local btnMic = vgui.Create("DButton", bottomPanel)
    btnMic:SetPos(350, 45)
    btnMic:SetSize(80, 28)
    btnMic:SetFont("ixSmallFont")

    btnMic.DoClick = function()
        if not IsValid(ent) then return end

        local newState = not ent:GetMicOn()

        net.Start("ixStationaryRadioMic")
        net.WriteEntity(ent)
        net.WriteBool(newState)
        net.SendToServer()
    end

    btnMic.Think = function(self)
        if not IsValid(ent) then return end

        local micOn = ent:GetMicOn()
        self:SetText(micOn and "MIC: ON" or "MIC: OFF")

        if micOn then
            self:SetTextColor(Color(255, 100, 100))
        else
            self:SetTextColor(ix.constants.COLOR_UI_NEUTRAL)
        end
    end

    -- Close panel if entity becomes invalid
    frame.Think = function(self)
        if not IsValid(ent) then
            ClosePanel()
            return
        end

        -- Also close if we're no longer the user
        if ent:GetUser() ~= LocalPlayer() then
            self:Remove()
            activePanel = nil
            activeEntity = nil
        end
    end
end

-- Network receiver to open UI
net.Receive("ixStationaryRadioOpen", function()
    local ent = net.ReadEntity()
    OpenStationaryRadioUI(ent)
end)

-- Close panel when dying or disconnecting
hook.Add("PlayerDeath", "ixStationaryRadioClose", function(victim)
    if victim == LocalPlayer() and IsValid(activePanel) then
        ClosePanel()
    end
end)

hook.Add("OnReloaded", "ixStationaryRadioClose", function()
    if IsValid(activePanel) then
        activePanel:Remove()
        activePanel = nil
        activeEntity = nil
    end
end)
