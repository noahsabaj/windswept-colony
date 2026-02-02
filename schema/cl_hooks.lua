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

hook.Add("Think", "ixRadioVoiceTransmit", function()
    local client = LocalPlayer()
    if not IsValid(client) then return end

    -- Don't process input when UI is open
    if vgui.CursorVisible() then
        if radioTransmitting then
            -- Stop transmission if UI opens
            net.Start("ixRadioVoiceStop")
            net.SendToServer()
            radioTransmitting = false
        end
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
        if radioTransmitting then
            net.Start("ixRadioVoiceStop")
            net.SendToServer()
            radioTransmitting = false
        end
    end

    wasHKeyDown = hKeyDown
end)

-- Stop transmitting on death/knockout
hook.Add("EntityNetworkedVarChanged", "ixRadioStopOnIncapacitate", function(ent, name, old, new)
    if ent ~= LocalPlayer() then return end

    if (name == "ixKnocked" or name == "gagged" or name == "ixRestricted") and new and radioTransmitting then
        net.Start("ixRadioVoiceStop")
        net.SendToServer()
        radioTransmitting = false
    end
end)

-- ============================================================================
-- RADIO VOLUME SLIDER
-- ============================================================================

net.Receive("ixRadioVolume", function()
    local itemID = net.ReadUInt(32)
    local currentVolume = net.ReadUInt(7)

    -- Create volume slider dialog
    Derma_SliderRequest(
        "Radio Volume",
        "Set receive volume (0-100%):",
        currentVolume,
        0,
        100,
        0,  -- decimals
        function(value)
            net.Start("ixRadioVolumeSet")
            net.WriteUInt(itemID, 32)
            net.WriteUInt(math.floor(value), 7)
            net.SendToServer()
        end
    )
end)