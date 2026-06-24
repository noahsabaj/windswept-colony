--[[
    Birth Data (Colony content)

    The generic Gregorian-calendar math now lives in the framework
    (gamemode/core/libs/sh_birthdata.lua). This file only overrides the setting-specific bits.
]]--

ws.birthdata = ws.birthdata or {}

-- Year-2200 Colony setting
ws.birthdata.CURRENT_YEAR = 2200

-- Birth-place options for the Colony setting
ws.birthdata.locations = {
    "North America, Earth",
    "South America, Earth",
    "Europe, Earth",
    "Asia, Earth",
    "Africa, Earth",
    "Australia, Earth",
    "Antarctica, Earth",
    "Mars",
    "Venus",
    "Luna (Earth's Moon)",
    "Phobos",
    "Deimos",
    "Kuiper Belt",
    "Unspecified",
    "Redrock City"
}
