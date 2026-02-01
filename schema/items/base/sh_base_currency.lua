--[[
    Base Currency Item

    Shared base class for all stackable currency items (cash, coins, etc.).
    Provides Split, Merge, Give, and optional Destroy functionality.

    Configuration options (set in child items):
    - ITEM.currencyValue: cents per unit (100 for dollars, 1 for cents)
    - ITEM.unitName: singular name ("dollar", "cent")
    - ITEM.unitNamePlural: plural name ("dollars", "cents")
    - ITEM.unitSymbol: display symbol ("$", "¢")
    - ITEM.symbolPrefix: true for "$50", false for "50¢"
    - ITEM.canDestroy: whether this currency can be destroyed (default false)
]]--

ITEM.name = "Currency"
ITEM.description = "A form of currency."
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Currency"
ITEM.noBusiness = true
ITEM.isCurrency = true

-- Configuration defaults (override in child items)
ITEM.currencyValue = 1
ITEM.unitName = "unit"
ITEM.unitNamePlural = "units"
ITEM.unitSymbol = ""
ITEM.symbolPrefix = true
ITEM.canDestroy = false

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetQuantity()
    return self:GetData("quantity", 1)
end

function ITEM:FormatAmount(amount)
    if self.symbolPrefix then
        return self.unitSymbol .. amount
    else
        return amount .. self.unitSymbol
    end
end

function ITEM:GetName()
    return self:FormatAmount(self:GetQuantity())
end

function ITEM:GetDescription()
    local quantity = self:GetQuantity()
    if quantity == 1 then
        return "A single CEG " .. self.unitName .. "."
    else
        return quantity .. " CEG " .. self.unitNamePlural .. "."
    end
end

function ITEM:CanTransfer(oldInventory, newInventory, newX, newY)
    return true
end

-- ============================================================================
-- SPLIT FUNCTION
-- ============================================================================

ITEM.functions.Split = {
    name = "Split Stack",
    icon = "icon16/cut.png",
    OnRun = function(item)
        local quantity = item:GetQuantity()
        if quantity <= 1 then
            item.player:Notify("Cannot split a single " .. item.unitName .. ".")
            return false
        end

        -- Open split dialog on client
        -- The type string is used by the client to display appropriate text
        local currencyType = item.currencyValue == 100 and "cash" or "coins"
        net.Start("ixCurrencySplit")
            net.WriteUInt(item:GetID(), 32)
            net.WriteUInt(quantity, 16)
            net.WriteString(currencyType)
        net.Send(item.player)
        return false
    end,
    OnCanRun = function(item)
        return item:GetQuantity() > 1
    end
}

-- ============================================================================
-- MERGE ALL FUNCTION
-- ============================================================================

ITEM.functions.MergeAll = {
    name = "Merge All",
    icon = "icon16/arrow_join.png",
    OnRun = function(item)
        local inventory = item.player:GetCharacter():GetInventory()
        local currentQuantity = item:GetQuantity()
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
            if otherItem.uniqueID == item.uniqueID and otherItem:GetID() ~= item:GetID() then
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
        if item:GetQuantity() >= ix.currency.MAX_STACK then
            return false
        end

        local inventory = item.player:GetCharacter():GetInventory()
        for _, otherItem in pairs(inventory:GetItems()) do
            if otherItem.uniqueID == item.uniqueID and otherItem:GetID() ~= item:GetID() then
                return true
            end
        end
        return false
    end
}

-- ============================================================================
-- MERGE WITH FUNCTION
-- ============================================================================

ITEM.functions.MergeWith = {
    name = "Merge With...",
    icon = "icon16/arrow_in.png",
    OnRun = function(item)
        ix.currency.SendMergeSelectList(item.player, item)
        return false
    end,
    OnCanRun = function(item)
        -- Can only merge if not full and there are other stacks
        if item:GetQuantity() >= ix.currency.MAX_STACK then
            return false
        end

        local inventory = item.player:GetCharacter():GetInventory()
        for _, otherItem in pairs(inventory:GetItems()) do
            if otherItem.uniqueID == item.uniqueID and otherItem:GetID() ~= item:GetID() then
                return true
            end
        end
        return false
    end
}

-- ============================================================================
-- DESTROY FUNCTION (Optional - controlled by ITEM.canDestroy)
-- ============================================================================

ITEM.functions.Destroy = {
    name = "Destroy",
    tip = "Destroy this currency permanently.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        return false -- Handled via net message
    end,
    OnClick = function(item)
        local quantity = item:GetQuantity()

        Derma_StringRequest(
            "Destroy " .. item.name,
            "How many " .. item.unitNamePlural .. " do you want to destroy?",
            tostring(quantity),
            function(text)
                local amount = tonumber(text)
                if not amount or amount <= 0 then return end

                net.Start("ixMoneyDestroy")
                    net.WriteUInt(item:GetID(), 32)
                    net.WriteUInt(math.floor(amount), 32)
                net.SendToServer()
            end,
            nil,
            "Destroy",
            "Cancel"
        )

        return false
    end,
    OnCanRun = function(item)
        if not item.canDestroy then return false end
        if IsValid(item.entity) then return false end
        return true
    end
}

-- ============================================================================
-- GIVE FUNCTION
-- ============================================================================

ITEM.functions.Give = {
    name = "Give",
    tip = "Give currency to the person you're looking at.",
    icon = "icon16/user_go.png",
    OnRun = function(item)
        return false -- Handled via net message
    end,
    OnClick = function(item)
        local client = LocalPlayer()
        local target = Schema:GetLookAtPlayer(client, 100)

        if not IsValid(target) then
            client:NotifyLocalized("noTargetInFront")
            return false
        end

        local quantity = item:GetQuantity()

        Derma_StringRequest(
            "Give " .. item.name,
            "How many " .. item.unitNamePlural .. " do you want to give to " .. target:Nick() .. "?",
            tostring(quantity),
            function(text)
                local amount = tonumber(text)
                if not amount or amount <= 0 then return end

                net.Start("ixMoneyGive")
                    net.WriteUInt(item:GetID(), 32)
                    net.WriteUInt(math.floor(amount), 32)
                    net.WriteEntity(target)
                net.SendToServer()
            end,
            nil,
            "Give",
            "Cancel"
        )

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return CLIENT -- Only show on client
    end
}
