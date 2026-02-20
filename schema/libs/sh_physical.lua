--[[
    Physical Description System

    Handles structured physical attributes for character creation.
    Replaces free-form descriptions with objective, auto-generated text.

    Physical attributes are set at character creation and cannot be changed.
]]--

ix.physical = ix.physical or {}

-- ============================================================================
-- MODEL MAPPINGS
-- ============================================================================

-- Model name to skin tone options mapping
-- Black models get darker skin options
-- Asian models get specific options
-- White models get lighter skin options
ix.physical.modelSkinTones = {
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
ix.physical.baldModels = {
    ["male_04"] = true
}

-- ============================================================================
-- DROPDOWN OPTIONS
-- ============================================================================

ix.physical.hairColors = {
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

ix.physical.hairTypes = {
    "Straight",
    "Wavy",
    "Curly",
    "Coily"
}

ix.physical.hairLengths = {
    "Bald",
    "Very Short",
    "Short",
    "Medium",
    "Long"
}

ix.physical.eyeColors = {
    "Brown",
    "Dark Brown",
    "Blue",
    "Green",
    "Hazel",
    "Gray",
    "Amber"
}

ix.physical.facialHairOptions = {
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

ix.physical.buildThresholds = {
    {max = 18.5, name = "thin"},
    {max = 25, name = "average"},
    {max = 30, name = "stocky"},
    {max = 999, name = "heavyset"}
}

-- ============================================================================
-- AGE DESCRIPTORS
-- ============================================================================

ix.physical.ageDescriptors = {
    {max = 19, desc = "late teens"},
    {max = 24, desc = "early twenties"},
    {max = 29, desc = "late twenties"},
    {max = 34, desc = "early thirties"},
    {max = 39, desc = "late thirties"},
    {max = 55, desc = "middle age"},
    {max = 70, desc = "later years"},
    {max = 999, desc = "twilight years"}
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Extract model name from full path (e.g., "male_01" from "models/player/group01/male_01.mdl")
function ix.physical.GetModelName(modelPath)
    if not modelPath then return nil end
    return string.match(modelPath, "(male_%d%d)%.mdl") or
           string.match(modelPath, "(female_%d%d)%.mdl")
end

-- Get skin tone options for a given model path
function ix.physical.GetSkinTonesForModel(modelPath)
    local modelName = ix.physical.GetModelName(modelPath)

    if modelName and ix.physical.modelSkinTones[modelName] then
        return ix.physical.modelSkinTones[modelName]
    end

    return ix.physical.modelSkinTones["default"]
end

-- Check if a model is female
function ix.physical.IsFemaleModel(modelPath)
    return modelPath and string.find(modelPath, "female") ~= nil
end

-- Check if a model is locked to bald
function ix.physical.IsBaldModel(modelPath)
    local modelName = ix.physical.GetModelName(modelPath)
    return modelName and ix.physical.baldModels[modelName] or false
end

-- Convert height from cm to imperial (feet, inches)
function ix.physical.CmToImperial(cm)
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
function ix.physical.LbsToKg(lbs)
    return math.floor(lbs * 0.453592 + 0.5) -- Round to nearest kg
end

-- Calculate BMI and return build category
function ix.physical.CalculateBuild(heightCm, weightLbs)
    local heightM = heightCm / 100
    local weightKg = weightLbs * 0.453592
    local bmi = weightKg / (heightM * heightM)

    for _, threshold in ipairs(ix.physical.buildThresholds) do
        if bmi < threshold.max then
            return threshold.name, bmi
        end
    end

    return "heavyset", bmi
end

-- Get age descriptor text
function ix.physical.GetAgeDescriptor(age)
    for _, entry in ipairs(ix.physical.ageDescriptors) do
        if age <= entry.max then
            return entry.desc
        end
    end
    return "elderly"
end

-- Get model path from model index
function ix.physical.GetModelPath(modelIndex)
    local models = ix.config.Get("factionlessModels") or {}
    local model = models[modelIndex]

    if istable(model) then
        return model[1]
    end

    return model
end

-- ============================================================================
-- DESCRIPTION GENERATION (SERVER ONLY)
-- ============================================================================

if SERVER then
    function ix.physical.GenerateDescription(data)
        -- Determine article for build
        local buildArticle = (data.build == "average") and "An" or "A"

        -- Build hair description
        local hairDesc
        if data.hairLength == "Bald" then
            hairDesc = "a bald head"
        else
            hairDesc = string.lower(data.hairLength) .. ", " ..
                       string.lower(data.hairType) .. " " ..
                       string.lower(data.hairColor) .. " hair"
        end

        -- Build facial hair description
        local facialHairDesc = ""
        if data.facialHair and data.facialHair ~= "None" then
            if data.facialHair == "Stubble" then
                facialHairDesc = " with stubble on their face"
            else
                facialHairDesc = " with a " .. string.lower(data.facialHair)
            end
        end

        -- Convert height to imperial for description
        local feet, inches = ix.physical.CmToImperial(data.height)
        local heightStr = string.format("%d'%d\"", feet, inches)

        -- Get age descriptor
        local ageDesc = ix.physical.GetAgeDescriptor(data.age)

        -- Determine article for skin tone
        local skinArticle = string.sub(data.skinTone, 1, 1):match("[AEIOUaeiou]") and "an" or "a"

        -- Generate the description (gender-neutral)
        local description = string.format(
            "%s %s-built person with %s and %s eyes. They have %s %s complexion%s. They stand around %s and appear to be in their %s.",
            buildArticle,
            data.build,
            hairDesc,
            string.lower(data.eyeColor),
            skinArticle,
            string.lower(data.skinTone),
            facialHairDesc,
            heightStr,
            ageDesc
        )

        return description
    end
end

-- ============================================================================
-- CHARACTER VARIABLE REGISTRATION
-- ============================================================================

-- Age (18-128)
ix.char.RegisterVar("physAge", {
    field = "phys_age",
    fieldType = ix.type.number,
    default = 25,
    index = 10,
    category = "description",
    OnValidate = function(self, value, payload, client)
        value = tonumber(value)
        if not value or value < 18 or value > 128 then
            return false, "invalidAge"
        end
        return math.floor(value)
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalSlider")
        panel:Dock(TOP)
        panel:SetMin(18)
        panel:SetMax(128)
        panel:SetValue(payload.physAge or 25)
        panel:SetDecimals(0)
        panel:SetDisplayMode("age")
        panel.OnValueChanged = function(this)
            payload:Set("physAge", math.floor(this:GetValue()))
        end
        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        payload:Set("physAge", math.floor(panel:GetValue()))
    end
})

-- Height (147-198 cm)
ix.char.RegisterVar("physHeight", {
    field = "phys_height",
    fieldType = ix.type.number,
    default = 170,
    index = 11,
    category = "description",
    OnValidate = function(self, value, payload, client)
        value = tonumber(value)
        if not value or value < 147 or value > 198 then
            return false, "invalidHeight"
        end
        return math.floor(value)
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalSlider")
        panel:Dock(TOP)
        panel:SetMin(147)
        panel:SetMax(198)
        panel:SetValue(payload.physHeight or 170)
        panel:SetDecimals(0)
        panel:SetDisplayMode("height")
        panel.OnValueChanged = function(this)
            payload:Set("physHeight", math.floor(this:GetValue()))
        end
        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        payload:Set("physHeight", math.floor(panel:GetValue()))
    end
})

-- Weight (90-350 lbs)
ix.char.RegisterVar("physWeight", {
    field = "phys_weight",
    fieldType = ix.type.number,
    default = 160,
    index = 12,
    category = "description",
    OnValidate = function(self, value, payload, client)
        value = tonumber(value)
        if not value or value < 90 or value > 350 then
            return false, "invalidWeight"
        end
        return math.floor(value)
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalSlider")
        panel:Dock(TOP)
        panel:SetMin(90)
        panel:SetMax(350)
        panel:SetValue(payload.physWeight or 160)
        panel:SetDecimals(0)
        panel:SetDisplayMode("weight")
        panel.OnValueChanged = function(this)
            payload:Set("physWeight", math.floor(this:GetValue()))
        end
        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        payload:Set("physWeight", math.floor(panel:GetValue()))
    end
})

-- Skin Tone (model-dependent)
ix.char.RegisterVar("physSkinTone", {
    field = "phys_skin_tone",
    fieldType = ix.type.string,
    default = "Medium",
    index = 13,
    category = "description",
    OnValidate = function(self, value, payload, client)
        if not value or value == "" then
            return false, "invalidSkinTone"
        end
        return value
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalDropdown")
        panel:Dock(TOP)

        -- Get initial options based on current model
        local modelPath = ix.physical.GetModelPath(payload.model or 1)
        local options = ix.physical.GetSkinTonesForModel(modelPath)
        panel:SetOptions(options)

        panel.OnValueChanged = function(this)
            payload:Set("physSkinTone", this:GetValue())
        end

        -- Update options when model changes
        payload:AddHook("model", function(modelIndex)
            if not IsValid(panel) then return end
            local newModelPath = ix.physical.GetModelPath(modelIndex)
            local newOptions = ix.physical.GetSkinTonesForModel(newModelPath)
            panel:SetOptions(newOptions)
            payload:Set("physSkinTone", panel:GetValue())
        end)

        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        payload:Set("physSkinTone", panel:GetValue())
    end
})

-- Hair Color
ix.char.RegisterVar("physHairColor", {
    field = "phys_hair_color",
    fieldType = ix.type.string,
    default = "Brown",
    index = 14,
    category = "description",
    OnValidate = function(self, value, payload, client)
        -- Allow any value if bald (will be ignored in description)
        if payload.physHairLength == "Bald" then
            return value or "Brown"
        end
        if not value or not table.HasValue(ix.physical.hairColors, value) then
            return false, "invalidHairColor"
        end
        return value
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalDropdown")
        panel:Dock(TOP)
        panel:SetOptions(ix.physical.hairColors)
        panel:SetValue("Brown")

        panel.OnValueChanged = function(this)
            payload:Set("physHairColor", this:GetValue())
        end

        -- Hide when bald
        payload:AddHook("physHairLength", function(hairLength)
            if not IsValid(panel) then return end
            ix.charCreate.SetFieldVisible(panel, hairLength ~= "Bald")
        end)

        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        -- Check if model is bald-locked
        local modelPath = ix.physical.GetModelPath(payload.model or 1)
        if ix.physical.IsBaldModel(modelPath) then
            ix.charCreate.SetFieldVisible(panel, false)
        end
        payload:Set("physHairColor", panel:GetValue())
    end
})

-- Hair Type
ix.char.RegisterVar("physHairType", {
    field = "phys_hair_type",
    fieldType = ix.type.string,
    default = "Straight",
    index = 15,
    category = "description",
    OnValidate = function(self, value, payload, client)
        -- Allow any value if bald (will be ignored in description)
        if payload.physHairLength == "Bald" then
            return value or "Straight"
        end
        if not value or not table.HasValue(ix.physical.hairTypes, value) then
            return false, "invalidHairType"
        end
        return value
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalDropdown")
        panel:Dock(TOP)
        panel:SetOptions(ix.physical.hairTypes)
        panel:SetValue("Straight")

        panel.OnValueChanged = function(this)
            payload:Set("physHairType", this:GetValue())
        end

        -- Hide when bald
        payload:AddHook("physHairLength", function(hairLength)
            if not IsValid(panel) then return end
            ix.charCreate.SetFieldVisible(panel, hairLength ~= "Bald")
        end)

        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        -- Check if model is bald-locked
        local modelPath = ix.physical.GetModelPath(payload.model or 1)
        if ix.physical.IsBaldModel(modelPath) then
            ix.charCreate.SetFieldVisible(panel, false)
        end
        payload:Set("physHairType", panel:GetValue())
    end
})

-- Hair Length
ix.char.RegisterVar("physHairLength", {
    field = "phys_hair_length",
    fieldType = ix.type.string,
    default = "Medium",
    index = 16,
    category = "description",
    OnValidate = function(self, value, payload, client)
        if not value or not table.HasValue(ix.physical.hairLengths, value) then
            return false, "invalidHairLength"
        end
        return value
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalDropdown")
        panel:Dock(TOP)
        panel:SetOptions(ix.physical.hairLengths)
        panel:SetValue("Medium")

        panel.OnValueChanged = function(this)
            payload:Set("physHairLength", this:GetValue())
        end

        -- Lock to bald for bald models
        payload:AddHook("model", function(modelIndex)
            if not IsValid(panel) then return end
            local modelPath = ix.physical.GetModelPath(modelIndex)
            if ix.physical.IsBaldModel(modelPath) then
                panel:SetOptions({"Bald"})
                panel:SetEnabled(false)
                payload:Set("physHairLength", "Bald")
            else
                local currentValue = panel:GetValue()
                panel:SetOptions(ix.physical.hairLengths)
                panel:SetEnabled(true)
                -- If was "Bald" (from bald model), default to "Medium", otherwise preserve
                if currentValue == "Bald" then
                    panel:SetValue("Medium")
                else
                    panel:SetValue(currentValue)
                end
            end
        end)

        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        -- Check if model is bald-locked
        local modelPath = ix.physical.GetModelPath(payload.model or 1)
        if ix.physical.IsBaldModel(modelPath) then
            panel:SetOptions({"Bald"})
            panel:SetEnabled(false)
            payload:Set("physHairLength", "Bald")
        else
            payload:Set("physHairLength", panel:GetValue())
        end
    end
})

-- Eye Color
ix.char.RegisterVar("physEyeColor", {
    field = "phys_eye_color",
    fieldType = ix.type.string,
    default = "Brown",
    index = 17,
    category = "description",
    OnValidate = function(self, value, payload, client)
        if not value or not table.HasValue(ix.physical.eyeColors, value) then
            return false, "invalidEyeColor"
        end
        return value
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalDropdown")
        panel:Dock(TOP)
        panel:SetOptions(ix.physical.eyeColors)
        panel:SetValue("Brown")

        panel.OnValueChanged = function(this)
            payload:Set("physEyeColor", this:GetValue())
        end

        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        payload:Set("physEyeColor", panel:GetValue())
    end
})

-- Facial Hair
ix.char.RegisterVar("physFacialHair", {
    field = "phys_facial_hair",
    fieldType = ix.type.string,
    default = "None",
    index = 18,
    category = "description",
    OnValidate = function(self, value, payload, client)
        if not value or not table.HasValue(ix.physical.facialHairOptions, value) then
            return false, "invalidFacialHair"
        end
        return value
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalDropdown")
        panel:Dock(TOP)
        panel:SetOptions(ix.physical.facialHairOptions)
        panel:SetValue("None")

        panel.OnValueChanged = function(this)
            payload:Set("physFacialHair", this:GetValue())
        end

        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        payload:Set("physFacialHair", panel:GetValue())
    end
})

-- Birth Month (1-12)
ix.char.RegisterVar("physBirthMonth", {
    field = "phys_birth_month",
    fieldType = ix.type.number,
    default = 1,
    index = 19,
    category = "description",
    OnValidate = function(self, value, payload, client)
        value = tonumber(value)
        if not value or value < 1 or value > 12 then
            return false, "invalidBirthMonth"
        end
        return math.floor(value)
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixBirthDatePicker")
        panel:Dock(TOP)

        -- Store reference to update day validation when age changes
        payload:AddHook("physAge", function(age)
            if not IsValid(panel) then return end
            panel:SetAge(age)
        end)

        panel.OnValueChanged = function(this)
            payload:Set("physBirthMonth", this:GetMonth())
            payload:Set("physBirthDay", this:GetDay())
        end

        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        panel:SetAge(payload.physAge or 25)
        payload:Set("physBirthMonth", panel:GetMonth())
        payload:Set("physBirthDay", panel:GetDay())
    end
})

-- Birth Day (1-31, handled by month's picker)
ix.char.RegisterVar("physBirthDay", {
    field = "phys_birth_day",
    fieldType = ix.type.number,
    default = 1,
    index = 20,
    category = "description",
    bNoDisplay = true, -- Handled by physBirthMonth's picker
    OnValidate = function(self, value, payload, client)
        value = tonumber(value)
        local month = tonumber(payload.physBirthMonth) or 1
        local age = tonumber(payload.physAge) or 25
        local maxDay = ix.birthdata.GetMaxDay(month, age)

        if not value or value < 1 or value > maxDay then
            return false, "invalidBirthDay"
        end
        return math.floor(value)
    end
})

-- Birth Location
ix.char.RegisterVar("physBirthLocation", {
    field = "phys_birth_location",
    fieldType = ix.type.string,
    default = "Unspecified",
    index = 21,
    category = "description",
    OnValidate = function(self, value, payload, client)
        if not value or not ix.birthdata.IsValidLocation(value) then
            return false, "invalidBirthLocation"
        end
        return value
    end,
    OnDisplay = function(self, container, payload)
        local panel = container:Add("ixPhysicalDropdown")
        panel:Dock(TOP)
        panel:SetOptions(ix.birthdata.locations)
        panel:SetValue("Unspecified")

        panel.OnValueChanged = function(this)
            payload:Set("physBirthLocation", this:GetValue())
        end

        return panel
    end,
    OnPostSetup = function(self, panel, payload)
        if not IsValid(panel) then return end
        payload:Set("physBirthLocation", panel:GetValue())
    end
})

-- Override the default description variable to be non-editable
-- The description will be generated server-side from physical attributes
ix.char.RegisterVar("description", {
    field = "description",
    fieldType = ix.type.text,
    default = "",
    index = 99, -- Put at end (we don't show it anyway)
    bNoDisplay = true, -- Hide from character creation UI
    OnValidate = function(self, value, payload, client)
        -- Description is generated server-side, accept any value here
        -- It will be overwritten in AdjustCreationPayload
        return value or ""
    end
})
