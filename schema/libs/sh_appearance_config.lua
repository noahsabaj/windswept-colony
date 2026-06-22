--[[
    Appearance CONTENT/config: model->skin-tone map, hair/eye/build option lists,
    and age descriptors. Read at runtime by the helpers, vars, and description gen.

    Split from the former schema/libs/sh_physical.lua (PR-10 honesty rename);
    ws.physical -> ws.appearance. Public API + the registered char vars unchanged.
]]--

ws.appearance = ws.appearance or {}

-- ============================================================================
-- MODEL MAPPINGS
-- ============================================================================

-- Model name to skin tone options mapping
-- Black models get darker skin options
-- Asian models get specific options
-- White models get lighter skin options
ws.appearance.modelSkinTones = {
    -- Black models
    ["male_01"] = {"Brown", "Dark Brown", "Dark"},
    ["male_03"] = {"Brown", "Dark Brown", "Dark"},
    ["female_03"] = {"Brown", "Dark Brown", "Dark"},
    ["female_05"] = {"Brown", "Dark Brown", "Dark"},

    -- Asian models
    ["male_05"] = {"Fair", "Light", "Medium", "Tan"},
    ["female_04"] = {"Fair", "Light", "Medium", "Tan"},

    -- Default (white models)
    ["default"] = {"Pale", "Fair", "Light", "Medium", "Olive"}
}

-- Models that are locked to bald
ws.appearance.baldModels = {
    ["male_04"] = true
}

-- ============================================================================
-- DROPDOWN OPTIONS
-- ============================================================================

ws.appearance.hairColors = {
    "Black",
    "Dark Brown",
    "Brown",
    "Light Brown",
    "Blonde",
    "Strawberry Blonde",
    "Red/Auburn",
    "Gray",
    "White"
}

ws.appearance.hairTypes = {
    "Straight",
    "Wavy",
    "Curly",
    "Coily"
}

ws.appearance.hairLengths = {
    "Bald",
    "Very Short",
    "Short",
    "Medium",
    "Long"
}

ws.appearance.eyeColors = {
    "Brown",
    "Dark Brown",
    "Blue",
    "Green",
    "Hazel",
    "Gray",
    "Amber"
}

ws.appearance.facialHairOptions = {
    "None",
    "Stubble",
    "Mustache",
    "Goatee",
    "Short Beard",
    "Full Beard"
}

-- ============================================================================
-- BUILD THRESHOLDS (BMI-based)
-- ============================================================================

ws.appearance.buildThresholds = {
    {max = 18.5, name = "thin"},
    {max = 25, name = "average"},
    {max = 30, name = "stocky"},
    {max = 999, name = "heavyset"}
}

-- ============================================================================
-- AGE DESCRIPTORS
-- ============================================================================

ws.appearance.ageDescriptors = {
    {max = 19, desc = "late teens"},
    {max = 24, desc = "early twenties"},
    {max = 29, desc = "late twenties"},
    {max = 34, desc = "early thirties"},
    {max = 39, desc = "late thirties"},
    {max = 55, desc = "middle age"},
    {max = 70, desc = "later years"},
    {max = 999, desc = "twilight years"}
}
