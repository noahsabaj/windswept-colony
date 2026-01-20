--[[
    Prisoner System Plugin

    Comprehensive arrest, surrender, and incarceration system.
    - Hands Up weapon for surrender indication
    - Zip Ties for restraining players
    - Gag system for silencing/blinding restrained players
    - Gavel tool for judges to sentence prisoners
    - Prison Card item showing sentence details
    - Timed sentences with pause on disconnect
    - Area integration for cell spawning and release
]]--

print("[Prisoner] sh_plugin.lua is loading...")

PLUGIN.name = "Prisoner System"
PLUGIN.author = "Windswept"
PLUGIN.description = "Arrest, surrender, and incarceration system with judge sentencing."

-- Register custom area types for prison cells and release point
function PLUGIN:SetupAreaProperties()
    ix.area.AddType("cell", "Prison Cell")
    ix.area.AddType("release", "Release Point")
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
