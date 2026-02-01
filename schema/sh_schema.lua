Schema.name = "Redrock City RP"
Schema.author = "kwabaj"
Schema.description = "A serious roleplay experience on the mining colony of Redrock."

-- Include netstream library (required for radio frequency dialog)
ix.util.Include("libs/thirdparty/sh_netstream2.lua")

-- Include birth data library (for Personal ID and character creation)
ix.util.Include("libs/sh_birthdata.lua")

-- Include physical description system (for character creation and Personal ID)
ix.util.Include("libs/sh_physical.lua")

-- Include door frame management library (for physical lock & key system)
ix.util.Include("libs/sh_doors.lua")

-- Include wallet system library (for currency routing to wallets)
ix.util.Include("libs/sh_wallet.lua")

-- Include centralized constants (must be early, before other files use them)
ix.util.Include("sh_constants.lua")

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

-- Election Configuration
Schema.elections = Schema.elections or {}
Schema.elections.termLength = 3 -- weeks
Schema.elections.positions = {
    "Mayor",
    "Commissioner",
    "Union President"
}

-- Get the player the client is looking at within range
function Schema:GetLookAtPlayer(client, maxRange)
    maxRange = maxRange or 100

    local trace = util.TraceLine({
        start = client:EyePos(),
        endpos = client:EyePos() + client:GetAimVector() * maxRange,
        filter = client
    })

    local target = trace.Entity
    if IsValid(target) and target:IsPlayer() then
        return target
    end

    return nil
end

-- Include other schema files
ix.util.Include("cl_schema.lua")
ix.util.Include("sv_schema.lua")
ix.util.Include("sh_hooks.lua")
ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_hooks.lua")
ix.util.Include("sh_configs.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("sh_options.lua")

-- ============================================================================
-- RADIO CHAT CLASSES
-- ============================================================================

-- Radio chat class (heard by players on same frequency with radio on)
do
    local CLASS = {}
    CLASS.color = Color(75, 150, 50)  -- Green
    CLASS.format = "%s radios in: \"%s\""

    function CLASS:CanHear(speaker, listener)
        local listenerChar = listener:GetCharacter()
        if not listenerChar then return false end

        -- Quick check: if listener has no active radio, skip everything
        -- This cache is set when radios are toggled on/off (only one radio can be active)
        if not listenerChar:GetData("ixHasActiveRadio") then return false end

        local speakerChar = speaker:GetCharacter()
        if not speakerChar then return false end

        -- Check frequencies match
        local speakerFreq = speakerChar:GetData("frequency", "100.0")
        local listenerFreq = listenerChar:GetData("frequency", "100.0")

        return speakerFreq == listenerFreq
    end

    -- Custom OnChatAdd: pass nil chatType so unrecognized speakers show as "Unknown"
    -- (passing a chatType would show their physical description, which makes no sense over radio)
    function CLASS:OnChatAdd(speaker, text)
        local name = hook.Run("GetCharacterName", speaker) or speaker:Name()
        chat.AddText(self.color, string.format(self.format, name, text))
    end

    ix.chat.Register("radio", CLASS)
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
        if ix.chat.classes.radio:CanHear(speaker, listener) then
            return false
        end

        -- Only nearby players
        local chatRange = ix.config.Get("chatRange", 280)
        return (speaker:GetPos() - listener:GetPos()):LengthSqr() <= (chatRange * chatRange)
    end

    -- Custom OnChatAdd: pass nil chatType so unrecognized speakers show as "Unknown"
    function CLASS:OnChatAdd(speaker, text)
        local name = hook.Run("GetCharacterName", speaker) or speaker:Name()
        chat.AddText(self.color, string.format(self.format, name, text))
    end

    ix.chat.Register("radio_eavesdrop", CLASS)
end