--[[
    Toolkit

    A toolkit for installing/removing doors and locks.

    Size × Quality Matrix:
    | Size    | Speed     | Durability |
    |---------|-----------|------------|
    | Light   | Slow      | Varies     |
    | Medium  | Medium    | Varies     |
    | Heavy   | Fast      | Varies     |

    | Quality     | Durability |
    |-------------|------------|
    | Crude       | Low (50)   |
    | Standard    | Medium (100)|
    | High-Quality| High (200) |

    Controls when equipped:
    - RMB on door: Remove door (door must be unlocked or lockless)
    - RMB on lock: Remove lock (lock must be unlocked)
    - LMB on lock: Repair lock (requires metal in inventory)
]]--

ITEM.name = "Toolkit"
ITEM.description = "A toolkit for door and lock work."
ITEM.model = "models/props_c17/tools_wrench01a.mdl"  -- Placeholder
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Tools"
ITEM.noBusiness = true
ITEM.class = "ix_toolkit"
ITEM.weaponCategory = "toolkit"

-- Size configurations
ITEM.sizes = {
    light = {
        name = "Light",
        doorInstallMultiplier = 1.5,    -- 30s / 20s / 10s * 1.5
        lockInstallMultiplier = 1.5,    -- 9s / 6s / 3s * 1.5
        doorRemoveMultiplier = 1.5,
        lockRemoveMultiplier = 1.5,
    },
    medium = {
        name = "Medium",
        doorInstallMultiplier = 1.0,    -- Base times
        lockInstallMultiplier = 1.0,
        doorRemoveMultiplier = 1.0,
        lockRemoveMultiplier = 1.0,
    },
    heavy = {
        name = "Heavy",
        doorInstallMultiplier = 0.5,    -- 50% time
        lockInstallMultiplier = 0.5,
        doorRemoveMultiplier = 0.5,
        lockRemoveMultiplier = 0.5,
    }
}

-- Quality configurations
ITEM.qualities = {
    crude = {
        name = "Crude",
        maxDurability = 50,
    },
    standard = {
        name = "Standard",
        maxDurability = 100,
    },
    quality = {
        name = "High-Quality",
        maxDurability = 200,
    }
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetSize()
    return self:GetData("size", "medium")
end

function ITEM:GetQuality()
    return self:GetData("quality", "standard")
end

function ITEM:GetDurability()
    return self:GetData("durability", self:GetMaxDurability())
end

function ITEM:GetMaxDurability()
    local quality = self:GetQuality()
    return self.qualities[quality] and self.qualities[quality].maxDurability or 100
end

function ITEM:SetDurability(dur)
    self:SetData("durability", math.Clamp(dur, 0, self:GetMaxDurability()))
end

function ITEM:TakeDurabilityDamage(amount)
    local dur = self:GetDurability()
    dur = dur - amount
    if dur <= 0 then
        -- Toolkit breaks
        self:Remove()
        return true  -- Broke
    end
    self:SetDurability(dur)
    return false  -- Still usable
end

function ITEM:GetSizeConfig()
    local size = self:GetSize()
    return self.sizes[size] or self.sizes.medium
end

function ITEM:GetQualityConfig()
    local quality = self:GetQuality()
    return self.qualities[quality] or self.qualities.standard
end

-- For SWEP to read
function ITEM:GetDoorInstallMultiplier()
    return self:GetSizeConfig().doorInstallMultiplier
end

function ITEM:GetLockInstallMultiplier()
    return self:GetSizeConfig().lockInstallMultiplier
end

function ITEM:GetDoorRemoveMultiplier()
    return self:GetSizeConfig().doorRemoveMultiplier
end

function ITEM:GetLockRemoveMultiplier()
    return self:GetSizeConfig().lockRemoveMultiplier
end

-- Override GetName to show size and quality
function ITEM:GetName()
    local sizeConfig = self:GetSizeConfig()
    local qualityConfig = self:GetQualityConfig()
    return qualityConfig.name .. " " .. sizeConfig.name .. " Toolkit"
end

-- Override description
function ITEM:GetDescription()
    local sizeConfig = self:GetSizeConfig()
    local durability = self:GetDurability()
    local maxDurability = self:GetMaxDurability()

    local desc = "A toolkit for installing and removing doors and locks."
    desc = desc .. "\n\nSize: " .. sizeConfig.name
    desc = desc .. "\nDurability: " .. math.floor(durability) .. "/" .. maxDurability

    local speedDesc = "Medium"
    if sizeConfig.doorInstallMultiplier > 1 then
        speedDesc = "Slow"
    elseif sizeConfig.doorInstallMultiplier < 1 then
        speedDesc = "Fast"
    end
    desc = desc .. "\nSpeed: " .. speedDesc

    return desc
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local isEquipped = item:GetData("equipped")
        local durability = item:GetData("durability", item:GetMaxDurability())
        local maxDurability = item:GetMaxDurability()
        local durPercent = (durability / maxDurability) * 100

        -- Draw equipped indicator (green dot)
        if isEquipped then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end

        -- Draw durability bar
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(4, h - 12, w - 8, 8)

        local durWidth = ((w - 8) / 100) * durPercent
        local color
        if durPercent >= 75 then
            color = Color(50, 200, 50)
        elseif durPercent >= 50 then
            color = Color(200, 200, 50)
        elseif durPercent >= 25 then
            color = Color(255, 150, 50)
        else
            color = Color(200, 50, 50)
        end

        surface.SetDrawColor(color)
        surface.DrawRect(4, h - 12, durWidth, 8)
    end

    function ITEM:PopulateTooltip(tooltip)
        local sizeConfig = self:GetSizeConfig()
        local qualityConfig = self:GetQualityConfig()
        local durability = self:GetDurability()
        local maxDurability = self:GetMaxDurability()

        -- Size/Speed
        local speedDesc = "Medium"
        if sizeConfig.doorInstallMultiplier > 1 then
            speedDesc = "Slow"
        elseif sizeConfig.doorInstallMultiplier < 1 then
            speedDesc = "Fast"
        end

        local sizeRow = tooltip:AddRow("size")
        sizeRow:SetText("Size: " .. sizeConfig.name .. " (" .. speedDesc .. ")")
        sizeRow:SetBackgroundColor(Color(80, 80, 100))
        sizeRow:SizeToContents()

        -- Quality/Durability
        local durRow = tooltip:AddRow("durability")
        durRow:SetText("Durability: " .. math.floor(durability) .. "/" .. maxDurability)

        local durPercent = (durability / maxDurability) * 100
        if durPercent >= 75 then
            durRow:SetBackgroundColor(Color(50, 100, 50))
        elseif durPercent >= 50 then
            durRow:SetBackgroundColor(Color(100, 100, 50))
        elseif durPercent >= 25 then
            durRow:SetBackgroundColor(Color(150, 100, 50))
        else
            durRow:SetBackgroundColor(Color(150, 50, 50))
        end

        durRow:SizeToContents()
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Equip toolkit
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the toolkit to work on doors and locks.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing toolkit from this player
        if client.ixToolkitItem and client.ixToolkitItem ~= item then
            local oldItem = client.ixToolkitItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing toolkit SWEP if any
        if client:HasWeapon("ix_toolkit") then
            client:StripWeapon("ix_toolkit")
        end

        -- Set these BEFORE Give() so hooks see them
        client.ixToolkitItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("ix_toolkit")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_toolkit")
        end

        client:EmitSound("physics/metal/metal_box_impact_soft1.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        return true
    end
}

-- Unequip toolkit
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the toolkit away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_toolkit") then
            client:StripWeapon("ix_toolkit")
        end

        client.ixToolkitItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/metal/metal_box_impact_soft1.wav", 50, 90)

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
            if client:HasWeapon("ix_toolkit") then
                client:StripWeapon("ix_toolkit")
            end
            client.ixToolkitItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_toolkit") then
                oldOwner:StripWeapon("ix_toolkit")
            end
            oldOwner.ixToolkitItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("toolkitEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_toolkit", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixToolkitItem = self
        end
    end
end

-- Initialize new toolkits with default durability
function ITEM:OnInstanced(invID, x, y)
    if not self:GetData("durability") then
        self:SetData("durability", self:GetMaxDurability())
    end
end
