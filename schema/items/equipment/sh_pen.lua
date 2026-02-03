--[[
    Pen

    A ballpoint pen for writing on paper.
    Ink-based, cannot be erased. Can be used for signatures.
    Ink capacity: 1000 characters.
]]--

ITEM.name = "Pen"
ITEM.description = "A ballpoint pen for writing documents."
ITEM.model = "models/props_lab/clipboard.mdl"  -- Placeholder
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Equipment"

ITEM.base = "base_equippable"
ITEM.equipWeaponClass = "ix_pen"
ITEM.equipPlayerKey = "ixPenItem"
ITEM.equipNotifyKey = "penEquipped"
ITEM.equipTip = "Hold the pen in your hand."
ITEM.unequipTip = "Put the pen away."

-- Ink capacity
ITEM.maxInk = 1000

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

-- Override CanEquip from base
function ITEM:CanEquip()
    if not self:HasInk() then
        if CLIENT then
            LocalPlayer():NotifyLocalized("penOutOfInk")
        end
        return false
    end
    return true
end

-- ============================================================================
-- DESCRIPTION
-- ============================================================================

function ITEM:GetDescription()
    local ink = self:GetInk()
    local desc = "A ballpoint pen for writing documents.\n"

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
        -- Equipped indicator (from base)
        if item:GetData("equipped") then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end

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

        -- Ink level (blue)
        if inkPercent > 0 then
            surface.SetDrawColor(100, 100, 200, 255)
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
