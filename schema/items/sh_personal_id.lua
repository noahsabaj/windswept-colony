--[[
    Personal ID

    Every colonist has one. It's your identity in Redrock City.
    Given to all characters on creation - the one "magical" item,
    because you're born with an identity.

    Displays physical attributes set during character creation.
    Can be viewed as a visual ID card or shown to other players.
]]--

ITEM.name = "Personal ID"
ITEM.model = Model("models/props_c17/paper01.mdl")
ITEM.description = "A colonial identification card."
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Documents"
ITEM.noBusiness = true -- Cannot be purchased, given on character creation

-- Register network string for showing ID to other players
if SERVER then
    util.AddNetworkString("ixShowPersonalID")
end

-- Build the data table for the ID card UI
function ITEM:GetIDCardData()
    local physical = self:GetData("physical", {})

    -- Determine sex from model
    local sex = "M"
    if physical.model and ix.physical.IsFemaleModel(physical.model) then
        sex = "F"
    end

    -- Format date of birth
    local dob = "Unknown"
    if physical.birthMonth and physical.birthDay and physical.age then
        dob = ix.birthdata.FormatDate(physical.birthMonth, physical.birthDay, physical.age)
    end

    return {
        ownerName = self:GetData("ownerName", "Unknown"),
        id = self:GetData("id", "00000"),
        model = physical.model,
        skin = physical.skin or 0,
        bodygroups = physical.bodygroups,
        sex = sex,
        dob = dob,
        birthLocation = physical.birthLocation or "Unspecified",
        age = physical.age,
        height = physical.height,
        weight = physical.weight,
        build = physical.build,
        eyeColor = physical.eyeColor,
        hairColor = physical.hairColor,
        hairType = physical.hairType,
        hairLength = physical.hairLength,
        skinTone = physical.skinTone
    }
end

function ITEM:GetDescription()
    local id = self:GetData("id", "00000")
    local ownerName = self:GetData("ownerName", "Unknown")
    local physical = self:GetData("physical", {})

    -- Determine sex from model
    local sex = "M"
    if physical.model and ix.physical.IsFemaleModel(physical.model) then
        sex = "F"
    end

    local lines = {
        "Colonial Identification Card",
        string.rep("-", 32),
        "Name: " .. ownerName,
        "ID#: " .. id,
        "Sex: " .. sex,
    }

    -- Add birth info if available
    if physical.birthMonth and physical.birthDay and physical.age then
        local dob = ix.birthdata.FormatDate(physical.birthMonth, physical.birthDay, physical.age)
        table.insert(lines, "DOB: " .. dob)
    end

    if physical.birthLocation then
        table.insert(lines, "Origin: " .. physical.birthLocation)
    end

    -- Add physical attributes if available
    if next(physical) then
        table.insert(lines, string.rep("-", 32))

        -- Age
        if physical.age then
            table.insert(lines, "Age: " .. physical.age)
        end

        -- Height (imperial + metric)
        if physical.height then
            local feet, inches = ix.physical.CmToImperial(physical.height)
            table.insert(lines, string.format("Height: %d'%d\" (%dcm)", feet, inches, physical.height))
        end

        -- Weight (imperial + metric)
        if physical.weight then
            local kg = ix.physical.LbsToKg(physical.weight)
            table.insert(lines, string.format("Weight: %dlbs (%dkg)", physical.weight, kg))
        end

        -- Build
        if physical.build then
            local buildDisplay = physical.build:sub(1,1):upper() .. physical.build:sub(2)
            table.insert(lines, "Build: " .. buildDisplay)
        end

        table.insert(lines, string.rep("-", 32))

        -- Eyes
        if physical.eyeColor then
            table.insert(lines, "Eyes: " .. physical.eyeColor)
        end

        -- Hair
        if physical.hairLength then
            if physical.hairLength == "Bald" then
                table.insert(lines, "Hair: Bald")
            elseif physical.hairColor and physical.hairType then
                table.insert(lines, string.format("Hair: %s, %s, %s",
                    physical.hairColor,
                    physical.hairType,
                    physical.hairLength
                ))
            end
        end

        -- Skin
        if physical.skinTone then
            table.insert(lines, "Skin: " .. physical.skinTone)
        end
    end

    return table.concat(lines, "\n")
end

-- View your own ID card
ITEM.functions.View = {
    name = "View",
    icon = "icon16/magnifier.png",
    OnRun = function(itemTable)
        -- This runs on server, we need to tell client to open UI
        return false -- Don't consume
    end,
    OnClick = function(itemTable)
        -- Client-side: open the ID card UI
        local data = itemTable:GetIDCardData()

        -- Remove any existing self-view ID card
        if IsValid(ix.gui.selfIDCard) then
            ix.gui.selfIDCard:Remove()
        end

        local card = vgui.Create("ixPersonalIDCard")
        card:SetData(data)
        card:SetSelfViewMode()

        ix.gui.selfIDCard = card

        return false -- Don't send to server
    end,
    OnCanRun = function(itemTable)
        return !IsValid(itemTable.entity) -- Only from inventory
    end
}

-- Show ID to player in front of you
ITEM.functions.ShowForward = {
    name = "Show Forward",
    icon = "icon16/user.png",
    OnRun = function(itemTable)
        local client = itemTable.player
        local physical = itemTable:GetData("physical", {})

        -- Trace to find player in front
        local traceData = {
            start = client:GetShootPos(),
            endpos = client:GetShootPos() + client:GetAimVector() * 128,
            filter = client
        }
        local target = util.TraceLine(traceData).Entity

        if IsValid(target) and target:IsPlayer() then
            -- Determine sex from model
            local sex = "M"
            if physical.model and ix.physical.IsFemaleModel(physical.model) then
                sex = "F"
            end

            -- Format date of birth
            local dob = "Unknown"
            if physical.birthMonth and physical.birthDay and physical.age then
                dob = ix.birthdata.FormatDate(physical.birthMonth, physical.birthDay, physical.age)
            end

            -- Build data table for network
            local data = {
                ownerName = itemTable:GetData("ownerName", "Unknown"),
                id = itemTable:GetData("id", "00000"),
                model = physical.model,
                skin = physical.skin or 0,
                bodygroups = physical.bodygroups,
                sex = sex,
                dob = dob,
                birthLocation = physical.birthLocation or "Unspecified",
                age = physical.age,
                height = physical.height,
                weight = physical.weight,
                build = physical.build,
                eyeColor = physical.eyeColor,
                hairColor = physical.hairColor,
                hairType = physical.hairType,
                hairLength = physical.hairLength,
                skinTone = physical.skinTone
            }

            -- Send to target player
            net.Start("ixShowPersonalID")
                net.WriteTable(data)
            net.Send(target)

            -- Notify the player who showed the ID
            client:NotifyLocalized("idCardShown", target:Name())
        else
            client:NotifyLocalized("idCardNotValid")
        end

        return false -- Don't consume the item
    end,
    OnCanRun = function(itemTable)
        return !IsValid(itemTable.entity) -- Only from inventory
    end
}
