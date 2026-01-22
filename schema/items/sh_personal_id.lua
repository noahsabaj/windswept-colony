--[[
    Personal ID

    Every colonist has one. It's your identity in Redrock City.
    Given to all characters on creation - the one "magical" item,
    because you're born with an identity.

    Displays physical attributes set during character creation.
    Can be viewed as a visual ID card or shown to other players.
]]--

ITEM.name = "Personal ID"
ITEM.model = Model("models/weapons/helios/id_cards/w_idcard.mdl")
ITEM.description = "A colonial identification card."
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Documents"
ITEM.noBusiness = true -- Cannot be purchased, given on character creation

-- ID Card models: https://steamcommunity.com/sharedfiles/filedetails/?id=2179653848
if SERVER then
    util.AddNetworkString("ixShowPersonalID")
    resource.AddWorkshop("2179653848")
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

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local isEquipped = item:GetData("equipped")

        -- Draw equipped indicator (green dot)
        if isEquipped then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS - EQUIP/UNEQUIP
-- ============================================================================

ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the ID card in your hand.",
    icon = "icon16/vcard.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing ID card from this player
        if client.ixPersonalIDItem and client.ixPersonalIDItem ~= item then
            local oldItem = client.ixPersonalIDItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing ID SWEP if any
        if client:HasWeapon("ix_personalid") then
            client:StripWeapon("ix_personalid")
        end

        -- Give the SWEP
        local weapon = client:Give("ix_personalid")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_personalid")
        end

        client.ixPersonalIDItem = item
        item:SetData("equipped", true)

        client:EmitSound("physics/cardboard/cardboard_box_impact_soft1.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        return true
    end
}

ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the ID card away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_personalid") then
            client:StripWeapon("ix_personalid")
        end

        client.ixPersonalIDItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/cardboard/cardboard_box_impact_soft1.wav", 50, 90)

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equipped") == true
    end
}

-- ============================================================================
-- HOOKS
-- ============================================================================

function ITEM.postHooks.drop(item, result)
    if item:GetData("equipped") then
        local client = item:GetOwner()
        if IsValid(client) then
            if client:HasWeapon("ix_personalid") then
                client:StripWeapon("ix_personalid")
            end
            client.ixPersonalIDItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_personalid") then
                oldOwner:StripWeapon("ix_personalid")
            end
            oldOwner.ixPersonalIDItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("idCardEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_personalid", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixPersonalIDItem = self
        end
    end
end
