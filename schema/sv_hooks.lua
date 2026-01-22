--[[
    Windswept Colony RP - Server Hooks
]]--

-- Generate physical description from structured attributes during character creation
function Schema:AdjustCreationPayload(client, payload, newPayload)
    -- Get physical attribute values from payload
    local age = tonumber(payload.physAge) or 25
    local height = tonumber(payload.physHeight) or 170
    local weight = tonumber(payload.physWeight) or 160
    local skinTone = payload.physSkinTone or "Medium"
    local hairColor = payload.physHairColor or "Brown"
    local hairType = payload.physHairType or "Straight"
    local hairLength = payload.physHairLength or "Medium"
    local eyeColor = payload.physEyeColor or "Brown"
    local facialHair = payload.physFacialHair or "None"

    -- Get the model path for gender detection
    -- Helix's model OnAdjust already sets newPayload.model to the actual path
    local modelPath = newPayload.model

    -- Calculate build from height and weight
    local build, bmi = ix.physical.CalculateBuild(height, weight)

    -- Get birth data
    local birthMonth = tonumber(payload.physBirthMonth) or 1
    local birthDay = tonumber(payload.physBirthDay) or 1
    local birthLocation = payload.physBirthLocation or "Unspecified"

    -- Build the physical data table
    local physicalData = {
        age = age,
        height = height,
        weight = weight,
        build = build,
        bmi = bmi,
        skinTone = skinTone,
        hairColor = hairColor,
        hairType = hairType,
        hairLength = hairLength,
        eyeColor = eyeColor,
        facialHair = facialHair,
        model = modelPath,
        birthMonth = birthMonth,
        birthDay = birthDay,
        birthLocation = birthLocation
    }

    -- Generate the description
    local description = ix.physical.GenerateDescription(physicalData)

    -- Set the generated description
    newPayload.description = description

    -- Store the physical data on the character for Personal ID and other uses
    newPayload.data = newPayload.data or {}
    newPayload.data.physical = physicalData
end
