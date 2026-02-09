--[[
    Windswept Colony RP - Client Hooks
]]--

-- Disable the Business menu entirely
-- Items should come from realistic sources (vendors, NPCs, other players)
-- not spawned out of thin air from a menu
function Schema:BuildBusinessMenu()
    return false
end

-- Disable the Classes menu entirely
-- Players will not be able to change their class freely
-- They must go through roleplay processes to do so
-- Note: Unlike Business, Classes doesn't check a hook - we must remove it directly
hook.Remove("CreateMenuButtons", "ixClasses")

-- ============================================================================
-- PERSONAL ID NETWORKING
-- Receive ID card display from another player
-- ============================================================================

net.Receive("ixShowPersonalID", function()
    local data = net.ReadTable()

    -- Remove any existing recipient ID cards
    if IsValid(ix.gui.recipientIDCard) then
        ix.gui.recipientIDCard:Remove()
    end

    -- Create new ID card in recipient mode
    local card = vgui.Create("ixPersonalIDCard")
    card:SetData(data)
    card:SetRecipientMode()

    ix.gui.recipientIDCard = card
end)

-- ============================================================================
-- VOICE HUD REMOVAL
-- Anti-metagaming: Players don't magically know who is speaking
-- ============================================================================

function Schema:HUDShouldDraw(element)
    -- Hide the voice chat indicator (player names when speaking)
    if element == "CHudVoiceStatus" or element == "CHudVoiceSelfStatus" then
        return false
    end
end

-- ============================================================================
-- RADIO VOICE TRANSMISSION (H KEY)
-- Hold H to transmit voice over radio frequency
-- ============================================================================

local radioTransmitting = false
local wasHKeyDown = false

local function StopRadioTransmission()
    if not radioTransmitting then return end
    net.Start("ixRadioVoiceStop")
    net.SendToServer()
    radioTransmitting = false
end

hook.Add("Think", "ixRadioVoiceTransmit", function()
    local client = LocalPlayer()
    if not IsValid(client) then return end

    -- Don't process input when UI is open
    if vgui.CursorVisible() then
        StopRadioTransmission()
        wasHKeyDown = false
        return
    end

    local hKeyDown = input.IsKeyDown(KEY_H)

    -- Edge detection: key just pressed
    if hKeyDown and not wasHKeyDown then
        -- Check if we have an active radio
        local character = client:GetCharacter()
        if character and character:GetData("ixHasActiveRadio") then
            -- Check we can transmit (not knocked, gagged, restrained, dead)
            local canTransmit = client:Alive()
                and not client:GetNetVar("ixKnocked")
                and not client:GetNetVar("gagged")
                and not client:GetNetVar("ixRestricted")

            if canTransmit then
                net.Start("ixRadioVoiceStart")
                net.SendToServer()
                radioTransmitting = true
            end
        end
    -- Edge detection: key just released
    elseif not hKeyDown and wasHKeyDown then
        StopRadioTransmission()
    end

    wasHKeyDown = hKeyDown
end)

-- Stop transmitting on death/knockout
hook.Add("EntityNetworkedVarChanged", "ixRadioStopOnIncapacitate", function(ent, name, old, new)
    if ent ~= LocalPlayer() then return end

    if (name == "ixKnocked" or name == "gagged" or name == "ixRestricted") and new then
        StopRadioTransmission()
    end
end)

-- ============================================================================
-- VOICE AMPLITUDE SYNC
-- Send voice amplitude to server for distance calculations
-- VoiceVolume() only works client-side, so we must sync it
-- ============================================================================

local lastAmplitudeSent = 0
local AMPLITUDE_SEND_INTERVAL = 0.1

timer.Create("ixVoiceAmplitudeSync", AMPLITUDE_SEND_INTERVAL, 0, function()
    local client = LocalPlayer()
    if not IsValid(client) then return end

    if client:IsSpeaking() then
        local amp = client:VoiceVolume() or 0.5

        -- Only send if changed significantly (reduce network traffic)
        if math.abs(amp - lastAmplitudeSent) > 0.05 then
            net.Start("ixVoiceAmplitude")
            net.WriteFloat(amp)
            net.SendToServer()
            lastAmplitudeSent = amp
        end
    end
end)

-- ============================================================================
-- RADIO VOLUME SLIDER
-- ============================================================================

-- Custom slider dialog (GMod doesn't have Derma_SliderRequest)
local function OpenVolumeSlider(title, text, currentValue, minValue, maxValue, callback)
    local frame = vgui.Create("DFrame")
    frame:SetTitle(title)
    frame:SetSize(300, 140)
    frame:Center()
    frame:MakePopup()
    frame:SetBackgroundBlur(true)

    local label = vgui.Create("DLabel", frame)
    label:SetText(text)
    label:SetFont("DermaDefaultBold")
    label:SetPos(10, 30)
    label:SizeToContents()

    -- Use DSlider + DTextEntry for cleaner layout
    local slider = vgui.Create("DSlider", frame)
    slider:SetPos(10, 55)
    slider:SetSize(200, 20)
    slider:SetLockY(0.5)
    slider:SetSlideX(currentValue / maxValue)

    local valueEntry = vgui.Create("DTextEntry", frame)
    valueEntry:SetPos(220, 55)
    valueEntry:SetSize(50, 20)
    valueEntry:SetNumeric(true)
    valueEntry:SetValue(tostring(currentValue))

    -- Sync slider to text entry
    slider.OnValueChanged = function(self, x, y)
        local val = math.Round(x * maxValue)
        valueEntry:SetValue(tostring(val))
    end

    -- Sync text entry to slider
    valueEntry.OnEnter = function(self)
        local val = math.Clamp(tonumber(self:GetValue()) or 0, minValue, maxValue)
        self:SetValue(tostring(val))
        slider:SetSlideX(val / maxValue)
    end

    local okButton = vgui.Create("DButton", frame)
    okButton:SetText("OK")
    okButton:SetPos(200, 95)
    okButton:SetSize(80, 25)
    okButton.DoClick = function()
        local val = math.Clamp(tonumber(valueEntry:GetValue()) or 0, minValue, maxValue)
        callback(val)
        frame:Close()
    end

    local cancelButton = vgui.Create("DButton", frame)
    cancelButton:SetText("Cancel")
    cancelButton:SetPos(110, 95)
    cancelButton:SetSize(80, 25)
    cancelButton.DoClick = function()
        frame:Close()
    end
end

net.Receive("ixRadioVolume", function()
    local itemID = net.ReadUInt(32)
    local currentVolume = net.ReadUInt(7)

    OpenVolumeSlider(
        "Radio Volume",
        "Set receive volume (0-100%):",
        currentVolume,
        0,
        100,
        function(value)
            net.Start("ixRadioVolumeSet")
            net.WriteUInt(itemID, 32)
            net.WriteUInt(math.floor(value), 7)
            net.SendToServer()
        end
    )
end)