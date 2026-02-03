--[[
    Pencil (No Eraser)

    A wooden pencil without an eraser.
    Pencil writing can be erased by others with an eraser.
    Lead capacity: 500 characters.

    NOT equippable - just needs to be in inventory to write.
]]--

ITEM.name = "Pencil"
ITEM.description = "A wooden pencil without an eraser."
ITEM.model = "models/props_lab/bindergreen.mdl"  -- Placeholder
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Equipment"

-- Pencil properties
ITEM.maxLead = 500
ITEM.hasEraser = false

-- ============================================================================
-- LEAD MANAGEMENT
-- ============================================================================

function ITEM:GetLead()
    return self:GetData("lead", self.maxLead)
end

function ITEM:HasLead()
    return self:GetLead() > 0
end

function ITEM:UseLead(amount)
    local current = self:GetLead()
    local newAmount = math.max(0, current - amount)
    self:SetData("lead", newAmount)
    return newAmount
end

function ITEM:GetLeadPercent()
    return self:GetLead() / self.maxLead
end

-- ============================================================================
-- DESCRIPTION
-- ============================================================================

function ITEM:GetDescription()
    local lead = self:GetLead()
    local desc = "A wooden pencil without an eraser.\n"

    if lead == 0 then
        desc = desc .. "Lead: EMPTY (unusable)"
    else
        desc = desc .. string.format("Lead: %d/%d characters", lead, self.maxLead)
    end

    desc = desc .. "\n\nPencil writing can be erased."

    return desc
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        -- Lead level bar
        local lead = item:GetData("lead", item.maxLead)
        local leadPercent = lead / item.maxLead
        local barW = w - 4
        local barH = 3
        local barX = 2
        local barY = h - 5

        -- Background
        surface.SetDrawColor(50, 50, 50, 200)
        surface.DrawRect(barX, barY, barW, barH)

        -- Lead level (gray)
        if leadPercent > 0 then
            surface.SetDrawColor(150, 150, 150, 255)
            surface.DrawRect(barX, barY, barW * leadPercent, barH)
        end
    end
end
