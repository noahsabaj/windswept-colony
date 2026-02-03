--[[
    Pencil with Eraser

    A wooden pencil with an eraser on top.
    Can erase pencil writing from papers.
    Lead capacity: 500 characters.
]]--

ITEM.name = "Pencil with Eraser"
ITEM.description = "A wooden pencil with an eraser on top."
ITEM.model = "models/props_lab/bindergreen.mdl"  -- Placeholder
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Equipment"

ITEM.base = "base_equippable"
ITEM.equipWeaponClass = "ix_pencil"
ITEM.equipPlayerKey = "ixPencilItem"
ITEM.equipNotifyKey = "pencilEquipped"
ITEM.equipTip = "Hold the pencil in your hand."
ITEM.unequipTip = "Put the pencil away."

-- Pencil properties
ITEM.maxLead = 500
ITEM.hasEraser = true

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

-- Check if can erase
function ITEM:CanErase()
    return self.hasEraser
end

-- Override CanEquip from base
function ITEM:CanEquip()
    if not self:HasLead() then
        if CLIENT then
            LocalPlayer():NotifyLocalized("pencilOutOfLead")
        end
        return false
    end
    return true
end

-- ============================================================================
-- DESCRIPTION
-- ============================================================================

function ITEM:GetDescription()
    local lead = self:GetLead()
    local desc = "A wooden pencil with an eraser on top.\n"

    if lead == 0 then
        desc = desc .. "Lead: EMPTY (unusable)"
    else
        desc = desc .. string.format("Lead: %d/%d characters", lead, self.maxLead)
    end

    desc = desc .. "\n\nCan erase pencil writing from papers."

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

        -- Eraser indicator (pink dot top-left)
        surface.SetDrawColor(255, 150, 180, 200)
        surface.DrawRect(6, 6, 6, 6)

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
