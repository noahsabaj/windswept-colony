--[[
    Redrock City RP
    
    SETTING:
    The year is 2200. After humanity settled Venus in 2089, Earth's governments
    unified into the Confederation of Earthly Governments (CEG). The CEG licenses
    uninhabited planets to mining corporations for resource extraction.
    
    Redrock is one such planet - a hostile world where planet-wide windstorms
    blast the surface, and radiation makes surface life impossible.
    Humanity survives in underground cities and deep ravines.
    
    Eagle Extraction Conglomerate (EEC) holds the mining license. They appointed
    a Head Foreman to oversee operations. But the CEG mandates democratic
    governance for civilian protection - requiring elected positions for Governor,
    Commissioner, and Union President.
    
    ECONOMY:
    All money comes from carbon ore sales. Miners dig, trucks haul to surface,
    cargo barges sell off-world. 70% goes to EEC (wages, equipment, corporate).
    30% goes to Planetary Colonial Administration (Governor's budget, Security).
    
    POWER STRUCTURE:
    
    THE CONFEDERATION (Server Owner - Invisible)
        │
        ├── Licenses the planet, protects union rights
        ├── Can oust any official (nuclear option)
        └── Appoints the Head Foreman
                │
    ════════════╪════════════════════════════════════════
                │
        HEAD FOREMAN (Appointed, Termless)
        Representative of Eagle Extraction Conglomerate
        Controls 70% - pays wages, runs payroll
                │
                │ ...but will they obey?
                ▼
    ┌───────────────────────────────────────────────────┐
    │              REDROCK CITY                         │
    │                                                   │
    │   GOVERNOR ◄────► COMMISSIONER ◄────► UNION       │
    │   (Elected)       (Elected)       PRESIDENT       │
    │   3 weeks         3 weeks         (Elected)       │
    │                                   3 weeks         │
    │   Controls 30%    Funded by       (union only)    │
    │   colonial budget Governor                        │
    │                                                   │
    │   Appoints:       Appoints:       Appoints:       │
    │   - Lt. Governor  - Deputies      - Vice Pres     │
    │   - Judge         - Sergeants     - Secretary     │
    │   - Quartermaster - Officers      - Treasurer     │
    │                                   - Enforcers     │
    └───────────────────────────────────────────────────┘
                        ▲
                        │
                   CIVILIANS
                 (Default Faction)
              They vote. They labor.
              They spend kegs.
]]--

Schema.name = "Redrock City RP"
Schema.author = "kwabaj"
Schema.description = "A serious roleplay experience on the mining colony of Redrock."

-- Include netstream library (required for radio frequency dialog)
ix.util.Include("libs/thirdparty/sh_netstream2.lua")

-- Include birth data library (for Personal ID and character creation)
ix.util.Include("libs/sh_birthdata.lua")

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
    "Governor",
    "Commissioner",
    "Union President"
}

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
    CLASS.format = "%s radios in \"%s\""

    function CLASS:CanHear(speaker, listener)
        local listenerChar = listener:GetCharacter()
        if not listenerChar then return false end

        local inventory = listenerChar:GetInventory()
        if not inventory then return false end

        local speakerChar = speaker:GetCharacter()
        if not speakerChar then return false end

        local speakerFreq = speakerChar:GetData("frequency", "100.0")

        for _, radio in pairs(inventory:GetItemsByUniqueID("handheld_radio", true)) do
            if radio:GetData("enabled", false) then
                local listenerFreq = listenerChar:GetData("frequency", "100.0")
                if speakerFreq == listenerFreq then
                    return true
                end
            end
        end

        return false
    end

    function CLASS:OnChatAdd(speaker, text)
        chat.AddText(self.color, string.format(self.format, speaker:Name(), text))
    end

    ix.chat.Register("radio", CLASS)
end

-- Radio eavesdrop (nearby players hear you talking into radio, but not on frequency)
do
    local CLASS = {}
    CLASS.color = Color(255, 255, 175)  -- Yellow
    CLASS.format = "%s radios in \"%s\""

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

    function CLASS:OnChatAdd(speaker, text)
        chat.AddText(self.color, string.format(self.format, speaker:Name(), text))
    end

    ix.chat.Register("radio_eavesdrop", CLASS)
end