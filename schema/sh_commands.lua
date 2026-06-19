--[[
    RADIO COMMANDS

    /Radio <message> - Transmit a message on your radio frequency
    /R <message> - Shortcut for /Radio
    /SetFreq <frequency> - Set your radio frequency (format: ###.#)
]]--

-- /Radio <message> command
do
    local COMMAND = {}
    COMMAND.arguments = ws.type.text

    -- Calculate speaking time from message length (15 chars/sec average)
    local function GetSpeakingTime(message)
        return math.max(0.5, string.len(message) / 15)
    end

    function COMMAND:OnRun(client, message)
        local character, inventory = ws.constants.GetCharacterInventory(client)
        if not character or not inventory then return end

        local radios = inventory:GetItemsByUniqueID("handheld_radio", true)
        local activeRadio

        -- Find active radio
        for _, radio in ipairs(radios) do
            if radio:GetData("enabled", false) then
                activeRadio = radio
                break
            end
        end

        if activeRadio then
            -- Check radio has battery power
            if not activeRadio:CanOperate() then
                return "@radioNoBattery"
            end

            -- Block transmission if hands up (can still receive)
            local wep = client:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == "ix_handsup" then
                return "@radioHandsUp"
            end

            if not client:IsRestricted() then
                -- Calculate and drain battery for transmission
                local speakingTime = GetSpeakingTime(message)
                activeRadio:DrainActive(speakingTime)

                -- Store message info for receiver battery drain
                -- (receivers will drain in the chat class CanHear)
                ws.radioMessageLength = string.len(message)

                ws.chat.Send(client, "radio", message)
                ws.chat.Send(client, "radio_eavesdrop", message)

                ws.radioMessageLength = nil
            else
                return "@notNow"
            end
        elseif #radios > 0 then
            return "@radioNotOn"
        else
            return "@radioRequired"
        end
    end

    ws.command.Add("Radio", COMMAND)
    ws.command.Add("R", COMMAND)  -- Shortcut
end

-- /SetFreq <frequency> command
do
    local COMMAND = {}
    COMMAND.arguments = ws.type.text

    function COMMAND:OnRun(client, frequency)
        local character, inventory = ws.constants.GetCharacterInventory(client)
        if not character or not inventory then return end

        local radio = inventory:HasItem("handheld_radio")

        if radio then
            -- Validate frequency format (###.#)
            if string.match(frequency, "^%d%d%d%.%d$") then
                character:SetData("frequency", frequency)
                radio:SetData("frequency", frequency)
                client:Notify("Radio frequency set to " .. frequency)
            else
                return "@invalidFrequency"
            end
        else
            return "@radioRequired"
        end
    end

    ws.command.Add("SetFreq", COMMAND)
end

-- ============================================================================
-- DISABLE DESCRIPTION EDITING
-- Players cannot manually edit their physical description
-- Description is generated from physical attributes during character creation
-- ============================================================================

ws.command.Add("CharDesc", {
    description = "@cmdCharDesc",
    OnCheckAccess = function(self, client)
        return false, "descEditDisabled"
    end,
    OnRun = function(self, client, description)
        return "@descEditDisabled"
    end
})
