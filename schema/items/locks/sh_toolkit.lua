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
ITEM.model = "models/props_c17/tools_wrench01a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Tools"
ITEM.noBusiness = true
ITEM.class = "ix_toolkit"
ITEM.weaponCategory = "toolkit"
ITEM.base = "base_equippable"

-- Equippable configuration
ITEM.equipWeaponClass = "ix_toolkit"
ITEM.equipPlayerKey = "ixToolkitItem"
ITEM.equipNotifyKey = "toolkitEquipped"
ITEM.equipSound = "physics/metal/metal_box_impact_soft1.wav"
ITEM.equipTip = "Hold the toolkit to work on doors and locks."
ITEM.unequipTip = "Put the toolkit away."

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
        if item:GetData("equipped") then
            ix.constants.DrawEquippedIndicator(w, h)
        end

        local durability = item:GetData("durability", item:GetMaxDurability())
        local durPercent = durability / item:GetMaxDurability()
        ix.constants.DrawDurabilityBar(w, h, durPercent, ix.constants.GetChargeColor(durPercent * 100, 75, 50, 25))
    end

    function ITEM:PopulateTooltip(tooltip)
        local sizeConfig = self:GetSizeConfig()
        local durability = self:GetDurability()
        local maxDurability = self:GetMaxDurability()

        -- Size/Speed
        local speedDesc = "Medium"
        if sizeConfig.doorInstallMultiplier > 1 then
            speedDesc = "Slow"
        elseif sizeConfig.doorInstallMultiplier < 1 then
            speedDesc = "Fast"
        end

        ix.constants.AddTooltipRow(tooltip, "size", "Size: " .. sizeConfig.name .. " (" .. speedDesc .. ")", Color(80, 80, 100))

        -- Quality/Durability
        local durPercent = (durability / maxDurability) * 100
        ix.constants.AddTooltipRow(tooltip, "durability", "Durability: " .. math.floor(durability) .. "/" .. maxDurability, ix.constants.GetChargeColorDark(durPercent, 75, 50, 25))
    end
end

-- ============================================================================
-- HOOKS
-- ============================================================================

-- Initialize new toolkits with default durability
function ITEM:OnInstanced(invID, x, y)
    if not self:GetData("durability") then
        self:SetData("durability", self:GetMaxDurability())
    end
end
