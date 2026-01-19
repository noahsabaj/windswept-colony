--[[
    Defibrillator

    Medical device that significantly improves revival chances.
    Has 3-4 charges before needing to be recharged.
]]--

ITEM.name = "Defibrillator"
ITEM.description = "A portable automated external defibrillator (AED). Dramatically improves the chances of successfully reviving a knocked out patient. Requires periodic recharging."
ITEM.model = "models/props_lab/reciever01a.mdl"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Medical"
ITEM.price = 500

-- Maximum charges
ITEM.maxCharges = 4

-- Get current charges
function ITEM:GetCharges()
    return self:GetData("charges", self.maxCharges)
end

-- Set charges
function ITEM:SetCharges(charges)
    self:SetData("charges", math.Clamp(charges, 0, self.maxCharges))
end

-- Check if has any charge
function ITEM:HasCharge()
    return self:GetCharges() > 0
end

-- ============================================================================
-- CLIENT RENDERING
-- ============================================================================

if CLIENT then
    -- Draw charge indicator on item icon
    function ITEM:PaintOver(item, w, h)
        local charges = item:GetCharges()
        local maxCharges = item.maxCharges

        -- Draw charge bar background
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(4, h - 12, w - 8, 8)

        -- Draw charge level
        local chargeWidth = ((w - 8) / maxCharges) * charges
        local color = charges > 1 and Color(50, 200, 50) or Color(200, 50, 50)
        surface.SetDrawColor(color)
        surface.DrawRect(4, h - 12, chargeWidth, 8)

        -- Draw charge separators
        surface.SetDrawColor(0, 0, 0, 255)
        for i = 1, maxCharges - 1 do
            local x = 4 + ((w - 8) / maxCharges) * i
            surface.DrawRect(x - 1, h - 12, 2, 8)
        end
    end

    -- Add charge info to tooltip
    function ITEM:PopulateTooltip(tooltip)
        local charges = self:GetCharges()
        local maxCharges = self.maxCharges

        local chargeRow = tooltip:AddRow("charges")
        chargeRow:SetText(string.format("Charges: %d/%d", charges, maxCharges))

        if charges <= 0 then
            chargeRow:SetBackgroundColor(Color(150, 50, 50))
        elseif charges <= 1 then
            chargeRow:SetBackgroundColor(Color(150, 100, 50))
        else
            chargeRow:SetBackgroundColor(Color(50, 100, 50))
        end

        chargeRow:SizeToContents()

        -- Add usage hint
        local hintRow = tooltip:AddRow("hint")
        hintRow:SetText("Use to ready for revival (45-95% success rate)")
        hintRow:SizeToContents()
    end
end

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

ITEM.functions.Equip = {
    name = "Ready Defibrillator",
    tip = "Prepare the defibrillator for use on a knocked out patient.",
    icon = "icon16/heart.png",
    OnRun = function(item)
        local client = item.player

        if item:GetCharges() <= 0 then
            client:NotifyLocalized("defibNoCharge")
            return false
        end

        -- Mark player as having defib ready
        client.ixDefibReady = true
        client.ixDefibItem = item

        client:NotifyLocalized("defibReady")

        return false  -- Don't consume item
    end,
    OnCanRun = function(item)
        return item:GetCharges() > 0
    end
}

ITEM.functions.Unequip = {
    name = "Stow Defibrillator",
    tip = "Put the defibrillator away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        client.ixDefibReady = nil
        client.ixDefibItem = nil

        client:Notify("You stow the defibrillator.")

        return false
    end,
    OnCanRun = function(item)
        local client = item.player
        return client.ixDefibReady and client.ixDefibItem == item
    end
}

ITEM.functions.CheckCharge = {
    name = "Check Charge",
    tip = "Check the defibrillator's battery level.",
    icon = "icon16/lightning.png",
    OnRun = function(item)
        local client = item.player
        local charges = item:GetCharges()
        local maxCharges = item.maxCharges

        client:Notify(string.format("The defibrillator has %d/%d charges remaining.", charges, maxCharges))

        return false
    end
}

-- ============================================================================
-- HOOKS
-- ============================================================================

-- Clear defib ready state on drop
function ITEM:OnDrop()
    local client = self:GetOwner()
    if IsValid(client) and client.ixDefibItem == self then
        client.ixDefibReady = nil
        client.ixDefibItem = nil
    end
end

-- Clear defib ready state on transfer
function ITEM:OnTransferred(oldInventory, newInventory)
    local oldOwner = oldInventory and oldInventory:GetOwner()
    if IsValid(oldOwner) and oldOwner.ixDefibItem == self then
        oldOwner.ixDefibReady = nil
        oldOwner.ixDefibItem = nil
    end
end
