--[[
    Redrock City RP
    
    SETTING:
    The year is 2134. After humanity settled Venus in 2089, Earth's governments
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
    │   GOVERNOR ◄────► COMMISSIONER ◄────► UNION      │
    │   (Elected)       (Elected)       PRESIDENT      │
    │   3 weeks         3 weeks         (Elected)      │
    │                                   3 weeks        │
    │   Controls 30%    Funded by       (union only)   │
    │   colonial budget Governor                       │
    │                                                   │
    │   Appoints:       Appoints:       Appoints:      │
    │   - Lt. Governor  - Deputies      - Vice Pres    │
    │   - Judge         - Sergeants     - Secretary    │
    │   - Quartermaster - Officers      - Treasurer    │
    │                                   - Enforcers    │
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