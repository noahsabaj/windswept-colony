ITEM.name = "Cash"
ITEM.description = "CEG Dollar bills."
ITEM.model = "models/props_junk/cardboard_box004a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Currency"
ITEM.noBusiness = true
ITEM.isCurrency = true
ITEM.currencyValue = 100  -- cents per unit (1 bill = $1 = 100 cents)

-- Stack data stored in item:GetData("quantity", 1)
-- Max 100 bills per stack = $100 per slot

function ITEM:GetName()
    local quantity = self:GetData("quantity", 1)
    return "$" .. quantity
end

function ITEM:GetDescription()
    local quantity = self:GetData("quantity", 1)
    if quantity == 1 then
        return "A single CEG dollar bill."
    else
        return quantity .. " CEG dollar bills."
    end
end

function ITEM:CanTransfer(oldInventory, newInventory, newX, newY)
    return true
end

ITEM.functions.Split = {
    name = "Split Stack",
    icon = "icon16/cut.png",
    OnRun = function(item)
        local quantity = item:GetData("quantity", 1)
        if quantity <= 1 then
            item.player:Notify("Cannot split a single bill.")
            return false
        end

        -- Open split dialog on client
        net.Start("ixCurrencySplit")
            net.WriteUInt(item:GetID(), 32)
            net.WriteUInt(quantity, 16)
            net.WriteString("cash")
        net.Send(item.player)
        return false
    end,
    OnCanRun = function(item)
        return item:GetData("quantity", 1) > 1
    end
}

ITEM.functions.MergeAll = {
    name = "Merge All",
    icon = "icon16/arrow_join.png",
    OnRun = function(item)
        local inventory = item.player:GetCharacter():GetInventory()
        local currentQuantity = item:GetData("quantity", 1)
        local maxStack = ix.currency.MAX_STACK
        local canAdd = maxStack - currentQuantity

        if canAdd <= 0 then
            item.player:Notify("This stack is already full.")
            return false
        end

        -- Find other stacks of the same currency type
        local mergedTotal = 0
        local itemsToRemove = {}

        for _, otherItem in pairs(inventory:GetItems()) do
            if otherItem.uniqueID == item.uniqueID and otherItem:GetID() != item:GetID() then
                local otherQuantity = otherItem:GetData("quantity", 1)

                if canAdd >= otherQuantity then
                    -- Merge entire stack
                    mergedTotal = mergedTotal + otherQuantity
                    canAdd = canAdd - otherQuantity
                    table.insert(itemsToRemove, otherItem)
                elseif canAdd > 0 then
                    -- Partial merge
                    mergedTotal = mergedTotal + canAdd
                    otherItem:SetData("quantity", otherQuantity - canAdd)
                    canAdd = 0
                    break
                end

                if canAdd <= 0 then break end
            end
        end

        if mergedTotal == 0 then
            item.player:Notify("No stacks to merge.")
            return false
        end

        -- Update main stack
        item:SetData("quantity", currentQuantity + mergedTotal)

        -- Remove empty stacks
        for _, otherItem in ipairs(itemsToRemove) do
            otherItem:Remove()
        end

        item.player:Notify("Merged " .. mergedTotal .. " into stack.")
        return false
    end,
    OnCanRun = function(item)
        -- Can only merge if not full and there are other stacks
        if item:GetData("quantity", 1) >= ix.currency.MAX_STACK then
            return false
        end

        local inventory = item.player:GetCharacter():GetInventory()
        for _, otherItem in pairs(inventory:GetItems()) do
            if otherItem.uniqueID == item.uniqueID and otherItem:GetID() != item:GetID() then
                return true
            end
        end
        return false
    end
}

ITEM.functions.MergeWith = {
    name = "Merge With...",
    icon = "icon16/arrow_in.png",
    OnRun = function(item)
        ix.currency.SendMergeSelectList(item.player, item)
        return false
    end,
    OnCanRun = function(item)
        -- Can only merge if not full and there are other stacks
        if item:GetData("quantity", 1) >= ix.currency.MAX_STACK then
            return false
        end

        local inventory = item.player:GetCharacter():GetInventory()
        for _, otherItem in pairs(inventory:GetItems()) do
            if otherItem.uniqueID == item.uniqueID and otherItem:GetID() != item:GetID() then
                return true
            end
        end
        return false
    end
}
