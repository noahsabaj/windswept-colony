Schema.name = "Redrock City RP"
Schema.author = "kwabaj"
Schema.description = "A serious roleplay experience on the mining colony of Redrock."

-- Include netstream library (required for radio frequency dialog)
ws.util.Include("libs/thirdparty/sh_netstream2.lua")

-- Include birth data library (for Personal ID and character creation)
ws.util.Include("libs/sh_birthdata.lua")

-- Include physical description system (for character creation and Personal ID)
ws.util.Include("libs/sh_physical.lua")

-- Include door frame management library (for physical lock & key system)
ws.util.Include("libs/sh_doors.lua")

-- Include wallet system library (for currency routing to wallets)
ws.util.Include("libs/sh_wallet.lua")

-- Include radio utilities library (for handheld and stationary radios)
ws.util.Include("libs/sh_radio.lua")

-- Include document system library (for paper, writing tools, document containers)
ws.util.Include("libs/sh_documents.lua")



-- Schema Configuration
Schema.colony = Schema.colony or {}
Schema.colony.name = "Redrock City"
Schema.colony.planet = "Redrock"
Schema.colony.corporation = "Eagle Extraction Conglomerate"
Schema.colony.government = "Confederation of Earthly Governments"

-- Economy Configuration
Schema.economy = Schema.economy or {}
Schema.economy.eecCut = 0.70  -- 70% to Eagle Extraction
Schema.economy.adminCut = 0.30  -- 30% to Colonial Administration

-- Include other schema files
ws.util.Include("cl_schema.lua")
ws.util.Include("sv_schema.lua")
ws.util.Include("cl_hooks.lua")
ws.util.Include("sv_hooks.lua")
ws.util.Include("sh_configs.lua")
ws.util.Include("sh_commands.lua")
ws.util.Include("sh_options.lua")

-- ============================================================================
-- RADIO CHAT CLASSES
-- ============================================================================

-- Radio chat class (heard by players on same frequency with radio on)
do
    local CLASS = {}
    CLASS.color = Color(75, 150, 50)  -- Green
    CLASS.format = "%s radios in: \"%s\""

    -- Helper to get listener's active radio
    local function GetListenerRadio(listener)
        local listenerChar = listener:GetCharacter()
        if not listenerChar then return nil end

        local inventory = listenerChar:GetInventory()
        if not inventory then return nil end

        local radios = inventory:GetItemsByUniqueID("handheld_radio", true)
        for _, radio in ipairs(radios) do
            if radio:GetData("enabled") and radio:CanOperate() then
                return radio
            end
        end

        return nil
    end

    function CLASS:CanHear(speaker, listener)
        local listenerChar = listener:GetCharacter()
        if not listenerChar then return false end

        -- Quick check: if listener has no active radio, skip everything
        if not listenerChar:GetData("ixHasActiveRadio") then return false end

        local speakerChar = speaker:GetCharacter()
        if not speakerChar then return false end

        -- Check frequencies match
        local speakerFreq = speakerChar:GetData("frequency", "100.0")
        local listenerFreq = listenerChar:GetData("frequency", "100.0")

        if speakerFreq ~= listenerFreq then return false end

        -- Get listener's radio and verify it can operate
        local listenerRadio = GetListenerRadio(listener)
        if not listenerRadio then return false end

        -- Drain listener's battery for receiving (server-side only)
        if SERVER and ws.radioMessageLength then
            local speakingTime = math.max(0.5, ws.radioMessageLength / 15)
            listenerRadio:DrainActive(speakingTime)
        end

        return true
    end

    -- Custom OnChatAdd: pass nil chatType so unrecognized speakers show as "Unknown"
    -- (passing a chatType would show their physical description, which makes no sense over radio)
    function CLASS:OnChatAdd(speaker, text)
        local name = hook.Run("GetCharacterName", speaker) or speaker:Name()
        chat.AddText(self.color, string.format(self.format, name, text))
    end

    ws.chat.Register("radio", CLASS)
end

-- Radio eavesdrop (nearby players hear you talking into radio, but not on frequency)
do
    local CLASS = {}
    CLASS.color = Color(255, 255, 175)  -- Yellow
    CLASS.format = "%s radios in: \"%s\""

    function CLASS:GetColor(speaker, text)
        if LocalPlayer():GetEyeTrace().Entity == speaker then
            return Color(175, 255, 175)
        end
        return self.color
    end

    function CLASS:CanHear(speaker, listener)
        -- Don't double-send to people who can hear via radio
        if ws.chat.classes.radio:CanHear(speaker, listener) then
            return false
        end

        -- Only nearby players
        local chatRange = ws.config.Get("chatRange", 280)
        return (speaker:GetPos() - listener:GetPos()):LengthSqr() <= (chatRange * chatRange)
    end

    -- Custom OnChatAdd: pass nil chatType so unrecognized speakers show as "Unknown"
    function CLASS:OnChatAdd(speaker, text)
        local name = hook.Run("GetCharacterName", speaker) or speaker:Name()
        chat.AddText(self.color, string.format(self.format, name, text))
    end

    ws.chat.Register("radio_eavesdrop", CLASS)
end