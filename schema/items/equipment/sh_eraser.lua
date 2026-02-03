--[[
    Eraser

    A rubber eraser for erasing pencil marks from papers.
    Durability: 500 characters worth of erasing.

    NOT equippable - just needs to be in inventory to erase.
]]--

ITEM.name = "Eraser"
ITEM.description = "A rubber eraser for erasing pencil marks."
ITEM.model = "models/props_lab/box01a.mdl"  -- Placeholder (small box)
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Equipment"

-- Eraser properties
ITEM.maxDurability = 500

-- ============================================================================
-- DURABILITY MANAGEMENT
-- ============================================================================

function ITEM:GetDurability()
    return self:GetData("durability", self.maxDurability)
end

function ITEM:HasDurability()
    return self:GetDurability() > 0
end

function ITEM:UseDurability(amount)
    local current = self:GetDurability()
    local newAmount = math.max(0, current - amount)
    self:SetData("durability", newAmount)
    return newAmount
end

function ITEM:GetDurabilityPercent()
    return self:GetDurability() / self.maxDurability
end

-- ============================================================================
-- DESCRIPTION
-- ============================================================================

function ITEM:GetDescription()
    local durability = self:GetDurability()
    local desc = "A rubber eraser for erasing pencil marks.\n"

    if durability == 0 then
        desc = desc .. "Durability: WORN OUT (unusable)"
    else
        desc = desc .. string.format("Durability: %d/%d", durability, self.maxDurability)
    end

    return desc
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        -- Durability bar
        local durability = item:GetData("durability", item.maxDurability)
        local durPercent = durability / item.maxDurability
        local barW = w - 4
        local barH = 3
        local barX = 2
        local barY = h - 5

        -- Background
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(barX, barY, barW, barH)

        -- Durability level (pink)
        if durPercent > 0 then
            surface.SetDrawColor(255, 150, 180, 255)
            surface.DrawRect(barX, barY, barW * durPercent, barH)
        end
    end
end
