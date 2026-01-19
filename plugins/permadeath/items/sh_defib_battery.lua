--[[
    Defibrillator Battery

    Consumable item that recharges a defibrillator to full capacity.
]]--

ITEM.name = "Defibrillator Battery"
ITEM.description = "A high-capacity battery pack compatible with portable defibrillators. Restores a defibrillator to full charge when used."
ITEM.model = "models/items/battery.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Medical"
ITEM.price = 100

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

ITEM.functions.Use = {
    name = "Charge Defibrillator",
    tip = "Use this battery to recharge a defibrillator in your inventory.",
    icon = "icon16/lightning_add.png",
    OnRun = function(item)
        local client = item.player
        local character = client:GetCharacter()

        if not character then
            return false
        end

        local inventory = character:GetInventory()
        if not inventory then
            client:NotifyLocalized("noDefibToCharge")
            return false
        end

        -- Find a defibrillator that needs charging
        local foundDefib = nil
        for _, invItem in pairs(inventory:GetItems()) do
            if invItem.uniqueID == "defibrillator" then
                if invItem:GetCharges() < invItem.maxCharges then
                    foundDefib = invItem
                    break
                end
            end
        end

        if not foundDefib then
            client:NotifyLocalized("noDefibToCharge")
            return false
        end

        -- Charge the defibrillator
        foundDefib:SetCharges(foundDefib.maxCharges)
        client:NotifyLocalized("defibCharged")

        -- Consume the battery
        return true
    end,
    OnCanRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end

        local character = client:GetCharacter()
        if not character then return false end

        local inventory = character:GetInventory()
        if not inventory then return false end

        -- Check if there's a defibrillator that needs charging
        for _, invItem in pairs(inventory:GetItems()) do
            if invItem.uniqueID == "defibrillator" then
                if invItem:GetCharges() < invItem.maxCharges then
                    return true
                end
            end
        end

        return false
    end
}

-- ============================================================================
-- CLIENT
-- ============================================================================

if CLIENT then
    function ITEM:PopulateTooltip(tooltip)
        local hintRow = tooltip:AddRow("hint")
        hintRow:SetText("Use to fully recharge a defibrillator")
        hintRow:SizeToContents()
    end
end
