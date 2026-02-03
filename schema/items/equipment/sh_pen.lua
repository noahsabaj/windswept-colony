--[[
    Pen

    A ballpoint pen for writing on paper.
    Ink-based, cannot be erased. Can be used for signatures.
    Ink capacity: 1000 characters.

    NOT equippable - just needs to be in inventory to write.
]]--

ITEM.name = "Pen (Blue)"
ITEM.description = "A ballpoint pen with blue ink."
ITEM.model = "models/props_lab/clipboard.mdl"  -- Placeholder
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Equipment"

-- Ink capacity
ITEM.maxInk = 1000

-- Ink color (RGB) - default blue
ITEM.inkColor = {100, 100, 200}

-- ============================================================================
-- INK MANAGEMENT
-- ============================================================================

function ITEM:GetInk()
    return self:GetData("ink", self.maxInk)
end

function ITEM:HasInk()
    return self:GetInk() > 0
end

function ITEM:UseInk(amount)
    local current = self:GetInk()
    local newAmount = math.max(0, current - amount)
    self:SetData("ink", newAmount)
    return newAmount
end

function ITEM:Refill(amount)
    local current = self:GetInk()
    local newAmount = math.min(self.maxInk, current + amount)
    self:SetData("ink", newAmount)
    return newAmount
end

function ITEM:GetInkPercent()
    return self:GetInk() / self.maxInk
end

function ITEM:GetInkColor()
    return self.inkColor or {100, 100, 200}  -- Default blue
end

-- ============================================================================
-- DESCRIPTION
-- ============================================================================

function ITEM:GetDescription()
    local ink = self:GetInk()
    local desc = self.description .. "\n"

    if ink == 0 then
        desc = desc .. "Ink: EMPTY (needs refill)"
    else
        desc = desc .. string.format("Ink: %d/%d characters", ink, self.maxInk)
    end

    return desc
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        -- Ink level bar
        local ink = item:GetData("ink", item.maxInk)
        local inkPercent = ink / item.maxInk
        local barW = w - 4
        local barH = 3
        local barX = 2
        local barY = h - 5

        -- Background
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(barX, barY, barW, barH)

        -- Ink level (pen color)
        if inkPercent > 0 then
            local color = item:GetInkColor()
            surface.SetDrawColor(color[1], color[2], color[3], 255)
            surface.DrawRect(barX, barY, barW * inkPercent, barH)
        end
    end
end

-- ============================================================================
-- COMBINE (for ink cartridge refill)
-- ============================================================================

ITEM.functions.combine = {
    OnRun = function(item, data)
        local targetItem = ix.item.instances[data[1]]
        if not targetItem then return false end

        -- Only allow ink cartridge
        if targetItem.uniqueID ~= "ink_cartridge" then
            return false
        end

        -- Refill pen
        local current = item:GetInk()
        if current >= item.maxInk then
            if item.player then
                item.player:NotifyLocalized("penAlreadyFull")
            end
            return false
        end

        -- Refill and consume cartridge
        item:Refill(item.maxInk)
        targetItem:Remove()

        if item.player then
            item.player:NotifyLocalized("penRefilled")
        end

        return false
    end,
    OnCanRun = function(item, data)
        local targetItem = ix.item.instances[data[1]]
        if not targetItem then return false end
        return targetItem.uniqueID == "ink_cartridge"
    end
}
