--[[
    RADIO COMMANDS

    /Radio <message> - Transmit a message on your radio frequency
    /R <message> - Shortcut for /Radio
    /SetFreq <frequency> - Set your radio frequency (format: ###.#)
]]--

-- /Radio <message> command
do
    local COMMAND = {}
    COMMAND.arguments = ix.type.text

    -- Calculate speaking time from message length (15 chars/sec average)
    local function GetSpeakingTime(message)
        return math.max(0.5, string.len(message) / 15)
    end

    function COMMAND:OnRun(client, message)
        local character = client:GetCharacter()
        local radios = character:GetInventory():GetItemsByUniqueID("handheld_radio", true)
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
                ix.radioMessageLength = string.len(message)

                ix.chat.Send(client, "radio", message)
                ix.chat.Send(client, "radio_eavesdrop", message)

                ix.radioMessageLength = nil
            else
                return "@notNow"
            end
        elseif #radios > 0 then
            return "@radioNotOn"
        else
            return "@radioRequired"
        end
    end

    ix.command.Add("Radio", COMMAND)
    ix.command.Add("R", COMMAND)  -- Shortcut
end

-- /SetFreq <frequency> command
do
    local COMMAND = {}
    COMMAND.arguments = ix.type.text

    function COMMAND:OnRun(client, frequency)
        local character = client:GetCharacter()
        local inventory = character:GetInventory()
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

    ix.command.Add("SetFreq", COMMAND)
end

-- ============================================================================
-- DISABLE DESCRIPTION EDITING
-- Players cannot manually edit their physical description
-- Description is generated from physical attributes during character creation
-- ============================================================================

ix.command.Add("CharDesc", {
    description = "@cmdCharDesc",
    OnCheckAccess = function(self, client)
        return false, "descEditDisabled"
    end,
    OnRun = function(self, client, description)
        return "@descEditDisabled"
    end
})
