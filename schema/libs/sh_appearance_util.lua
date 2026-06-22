--[[
    Appearance helpers: model-name/skin-tone/bald/female lookups, unit conversions
    (cm<->imperial, lbs->kg), build calculation, age descriptor, model-path lookup.

    Split from the former schema/libs/sh_physical.lua (PR-10 honesty rename);
    ws.physical -> ws.appearance. Public API + the registered char vars unchanged.
]]--

ws.appearance = ws.appearance or {}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Extract model name from full path (e.g., "male_01" from "models/player/group01/male_01.mdl")
function ws.appearance.GetModelName(modelPath)
    if not modelPath then return nil end
    return string.match(modelPath, "(male_%d%d)%.mdl") or
           string.match(modelPath, "(female_%d%d)%.mdl")
end

-- Get skin tone options for a given model path
function ws.appearance.GetSkinTonesForModel(modelPath)
    local modelName = ws.appearance.GetModelName(modelPath)

    if modelName and ws.appearance.modelSkinTones[modelName] then
        return ws.appearance.modelSkinTones[modelName]
    end

    return ws.appearance.modelSkinTones["default"]
end

-- Check if a model is female
function ws.appearance.IsFemaleModel(modelPath)
    return modelPath and string.find(modelPath, "female") ~= nil
end

-- Check if a model is locked to bald
function ws.appearance.IsBaldModel(modelPath)
    local modelName = ws.appearance.GetModelName(modelPath)
    return modelName and ws.appearance.baldModels[modelName] or false
end

-- Convert height from cm to imperial (feet, inches)
function ws.appearance.CmToImperial(cm)
    local totalInches = cm / 2.54
    local feet = math.floor(totalInches / 12)
    local inches = math.floor(totalInches % 12 + 0.5) -- Round to nearest inch

    -- Handle edge case where rounding gives 12 inches
    if inches >= 12 then
        feet = feet + 1
        inches = 0
    end

    return feet, inches
end

-- Convert weight from lbs to kg
function ws.appearance.LbsToKg(lbs)
    return math.floor(lbs * 0.453592 + 0.5) -- Round to nearest kg
end

-- Calculate BMI and return build category
function ws.appearance.CalculateBuild(heightCm, weightLbs)
    local heightM = heightCm / 100
    local weightKg = weightLbs * 0.453592
    local bmi = weightKg / (heightM * heightM)

    for _, threshold in ipairs(ws.appearance.buildThresholds) do
        if bmi < threshold.max then
            return threshold.name, bmi
        end
    end

    return "heavyset", bmi
end

-- Get age descriptor text
function ws.appearance.GetAgeDescriptor(age)
    for _, entry in ipairs(ws.appearance.ageDescriptors) do
        if age <= entry.max then
            return entry.desc
        end
    end
    return "elderly"
end

-- Get model path from model index
function ws.appearance.GetModelPath(modelIndex)
    local models = ws.config.Get("factionlessModels") or {}
    local model = models[modelIndex]

    if istable(model) then
        return model[1]
    end

    return model
end
