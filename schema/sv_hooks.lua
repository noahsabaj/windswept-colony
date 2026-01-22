--[[
    Windswept Colony RP - Server Hooks
]]--

-- ============================================================================
-- LADDER INTEGRATION
-- ============================================================================

-- When a player receives weapon_ladder_yl (from picking up deployed ladder),
-- create an inventory item instead of just having the weapon
function Schema:WeaponEquip(weapon, client)
    if not IsValid(weapon) or weapon:GetClass() ~= "weapon_ladder_yl" then return end
    if not IsValid(client) then return end

    local character = client:GetCharacter()
    if not character then return end

    -- If they already have an equipped ladder item, it's from our Equip function
    if client.ixLadderItem and client.ixLadderItem:GetData("equipped") then
        return
    end

    -- They picked up a ladder from the world - add to inventory
    local inventory = character:GetInventory()
    if not inventory then return end

    -- Try to add ladder item to inventory
    local canFit = inventory:FindEmptySlot(4, 4) -- ladder is 4x4
    if canFit then
        inventory:Add("ladder", 1, {equipped = true})

        -- Find the item we just added and link it
        timer.Simple(0.1, function()
            if not IsValid(client) then return end
            for _, item in pairs(inventory:GetItems()) do
                if item.uniqueID == "ladder" and item:GetData("equipped") and not item.linkedToWeapon then
                    item.linkedToWeapon = true
                    client.ixLadderItem = item
                    if IsValid(weapon) then
                        weapon.ixItem = item
                    end
                    break
                end
            end
        end)
    else
        -- No room in inventory - drop the weapon as entity
        client:StripWeapon("weapon_ladder_yl")
        client:NotifyLocalized("ladderNoRoom")
    end
end

-- Monitor equipped ladder items - if weapon disappears, item was deployed
timer.Create("ixLadderDeployCheck", 0.5, 0, function()
    for _, client in player.Iterator() do
        local item = client.ixLadderItem
        if item and item:GetData("equipped") then
            -- Item is marked as equipped but check if weapon still exists
            if not client:HasWeapon("weapon_ladder_yl") then
                -- Weapon was stripped (ladder deployed) - remove item from inventory
                local character = client:GetCharacter()
                if character then
                    local inventory = character:GetInventory()
                    if inventory then
                        inventory:Remove(item:GetID())
                    end
                end
                client.ixLadderItem = nil
            end
        end
    end
end)

-- ============================================================================
-- CHARACTER CREATION
-- ============================================================================

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
