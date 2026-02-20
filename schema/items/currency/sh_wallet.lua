ITEM.name = "Wallet"
ITEM.description = "A container for your money and identification."
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Containers"
ITEM.price = 200 -- $2.00 in cents
ITEM.base = "base_container"

ITEM.invWidth = 5
ITEM.invHeight = 5
ITEM.inventoryFlag = "isWallet"

-- Wallet designation: "both", "cash", or "coins"
-- Stored in item data as "designation"

-- ============================================================================
-- DESCRIPTION
-- ============================================================================

function ITEM:GetDescription()
    local desc = self.description
    local designation = self:GetData("designation", "both")

    local designationText = {
        both = "Accepts all currency",
        cash = "Dollars only",
        coins = "Coins only"
    }

    desc = desc .. "\n\nMode: " .. (designationText[designation] or "All currency")

    -- Show contents value
    local invID = self:GetData("id")
    if invID then
        local inv = ix.item.inventories[invID]
        if inv then
            local total = 0
            for _, invItem in pairs(inv:GetItems()) do
                if invItem.isCurrency then
                    local qty = invItem:GetData("quantity", 1)
                    total = total + (qty * invItem.currencyValue)
                end
            end

            local dollars = math.floor(total / 100)
            local cents = total % 100
            if total > 0 then
                desc = desc .. string.format("\nContains: $%d.%02d", dollars, cents)
            else
                desc = desc .. "\nContains: Empty"
            end
        end
    end

    return desc
end

-- ============================================================================
-- COMBINE (drag items onto wallet)
-- ============================================================================

-- Custom combine: allows cash, coins, and personal_id (not a single type)
ITEM.functions.combine = {
    OnRun = function(item, data)
        local targetItem = ix.item.instances[data[1]]
        if not targetItem then return false end

        -- Only allow cash, coins, and personal_id
        if targetItem.uniqueID ~= "cash" and targetItem.uniqueID ~= "coins" and targetItem.uniqueID ~= "personal_id" then
            if item.player then
                item.player:NotifyLocalized("walletOnlyCurrency")
            end
            return false
        end

        -- Check designation for currency
        if targetItem.isCurrency then
            local designation = item:GetData("designation", "both")
            if designation == "cash" and targetItem.uniqueID ~= "cash" then
                if item.player then
                    item.player:NotifyLocalized("walletCashOnly")
                end
                return false
            elseif designation == "coins" and targetItem.uniqueID ~= "coins" then
                if item.player then
                    item.player:NotifyLocalized("walletCoinsOnly")
                end
                return false
            end
        end

        targetItem:Transfer(item:GetData("id"), nil, nil, item.player)
        return false
    end,
    OnCanRun = function(item, data)
        local index = item:GetData("id", "")
        if index then
            local inventory = ix.item.inventories[index]
            if inventory then
                return true
            end
        end
        return false
    end
}

-- ============================================================================
-- DESIGNATION FUNCTIONS
-- ============================================================================

ITEM.functions["Set: All Currency"] = {
    name = "Set: All Currency",
    tip = "Accept both dollars and coins.",
    icon = "icon16/coins.png",
    OnRun = function(item)
        item:SetData("designation", "both")
        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return item:GetData("designation", "both") ~= "both"
    end
}

ITEM.functions["Set: Dollars Only"] = {
    name = "Set: Dollars Only",
    tip = "Only accept dollar bills.",
    icon = "icon16/money.png",
    OnRun = function(item)
        item:SetData("designation", "cash")
        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return item:GetData("designation", "both") ~= "cash"
    end
}

ITEM.functions["Set: Coins Only"] = {
    name = "Set: Coins Only",
    tip = "Only accept coins.",
    icon = "icon16/money_dollar.png",
    OnRun = function(item)
        item:SetData("designation", "coins")
        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return item:GetData("designation", "both") ~= "coins"
    end
}

-- ============================================================================
-- MOVE MONEY INTO / EMPTY WALLET
-- ============================================================================

ITEM.functions["Move Money Into"] = {
    name = "Move Money Into",
    tip = "Move all compatible money from your inventory into this wallet.",
    icon = "icon16/arrow_down.png",
    OnRun = function(item)
        local client = item.player
        if not client then return false end

        local character, mainInv = ix.constants.GetCharacterInventory(client)
        if not character or not mainInv then return false end

        local walletInvID = item:GetData("id")
        if not walletInvID then return false end

        local walletInv = ix.item.inventories[walletInvID]
        if not walletInv then return false end

        local designation = item:GetData("designation", "both")
        local movedCash = 0
        local movedCoins = 0

        -- Find all money in main inventory
        local moneyItems = {}
        for _, invItem in pairs(mainInv:GetItems()) do
            if invItem.isCurrency then
                table.insert(moneyItems, invItem)
            end
        end

        -- Move compatible money
        for _, moneyItem in ipairs(moneyItems) do
            local canMove = false

            if designation == "both" then
                canMove = true
            elseif designation == "cash" and moneyItem.uniqueID == "cash" then
                canMove = true
            elseif designation == "coins" and moneyItem.uniqueID == "coins" then
                canMove = true
            end

            if canMove then
                local x, y = walletInv:FindEmptySlot(moneyItem.width, moneyItem.height)
                if x and y then
                    local qty = moneyItem:GetData("quantity", 1)
                    moneyItem:Transfer(walletInvID, x, y, client)

                    if moneyItem.uniqueID == "cash" then
                        movedCash = movedCash + qty
                    else
                        movedCoins = movedCoins + qty
                    end
                end
            end
        end

        -- Notify
        if movedCash > 0 or movedCoins > 0 then
            local parts = {}
            if movedCash > 0 then
                table.insert(parts, "$" .. movedCash)
            end
            if movedCoins > 0 then
                table.insert(parts, movedCoins .. "¢")
            end
            client:NotifyLocalized("movedMoneyInto", table.concat(parts, " and "))
        else
            client:NotifyLocalized("noMoneyToMove")
        end

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return item:GetData("id") ~= nil
    end
}

ITEM.functions["Empty Wallet"] = {
    name = "Empty Wallet",
    tip = "Empty wallet contents into your inventory.",
    icon = "icon16/arrow_up.png",
    OnRun = function(item)
        local client = item.player
        if not client then return false end

        local character, mainInv = ix.constants.GetCharacterInventory(client)
        if not character or not mainInv then return false end

        local walletInvID = item:GetData("id")
        if not walletInvID then return false end

        local walletInv = ix.item.inventories[walletInvID]
        if not walletInv then return false end

        local itemsToMove = {}
        for _, walletItem in pairs(walletInv:GetItems()) do
            table.insert(itemsToMove, walletItem)
        end

        local movedCount = 0
        local failedCount = 0

        for _, walletItem in ipairs(itemsToMove) do
            -- Try main inventory first
            local x, y = mainInv:FindEmptySlot(walletItem.width, walletItem.height)
            if x and y then
                walletItem:Transfer(mainInv:GetID(), x, y, client)
                movedCount = movedCount + 1
            else
                -- Try other wallets with compatible designation
                local found = false

                if walletItem.isCurrency then
                    for _, otherItem in pairs(mainInv:GetItems()) do
                        if otherItem.uniqueID == "wallet" and otherItem:GetID() ~= item:GetID() then
                            local otherDesignation = otherItem:GetData("designation", "both")
                            local compatible = false

                            if otherDesignation == "both" then
                                compatible = true
                            elseif otherDesignation == "cash" and walletItem.uniqueID == "cash" then
                                compatible = true
                            elseif otherDesignation == "coins" and walletItem.uniqueID == "coins" then
                                compatible = true
                            end

                            if compatible then
                                local otherInvID = otherItem:GetData("id")
                                if otherInvID then
                                    local otherInv = ix.item.inventories[otherInvID]
                                    if otherInv then
                                        local ox, oy = otherInv:FindEmptySlot(walletItem.width, walletItem.height)
                                        if ox and oy then
                                            walletItem:Transfer(otherInvID, ox, oy, client)
                                            movedCount = movedCount + 1
                                            found = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if not found then
                    failedCount = failedCount + 1
                end
            end
        end

        if movedCount > 0 then
            client:NotifyLocalized("emptiedWallet", movedCount)
        end

        if failedCount > 0 then
            client:NotifyLocalized("walletEmptyFailed", failedCount)
        end

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return item:GetData("id") ~= nil
    end
}

-- ============================================================================
-- GIVE FROM WALLET
-- ============================================================================

ITEM.functions.Give = {
    name = "Give",
    tip = "Give money from this wallet to the person you're looking at.",
    icon = "icon16/user_go.png",
    OnRun = function(item)
        return false -- Handled via net message
    end,
    OnClick = function(item)
        local client = LocalPlayer()
        local target = ix.util.GetLookAtPlayer(client, 100)

        if not IsValid(target) then
            client:NotifyLocalized("noTargetInFront")
            return false
        end

        -- Calculate total money in wallet
        local invID = item:GetData("id")
        if not invID then return false end

        local inv = ix.item.inventories[invID]
        if not inv then return false end

        local totalCents = 0
        for _, invItem in pairs(inv:GetItems()) do
            if invItem.isCurrency then
                local qty = invItem:GetData("quantity", 1)
                totalCents = totalCents + (qty * invItem.currencyValue)
            end
        end

        if totalCents == 0 then
            client:NotifyLocalized("walletEmpty")
            return false
        end

        local totalDollars = totalCents / 100

        Derma_StringRequest(
            "Give From Wallet",
            string.format("How much do you want to give to %s? (Max: $%.2f)", target:Nick(), totalDollars),
            string.format("%.2f", totalDollars),
            function(text)
                local amount = tonumber(text)
                if not amount or amount <= 0 then return end

                local cents = math.floor(amount * 100)

                net.Start("ixWalletGive")
                    net.WriteUInt(item:GetID(), 32)
                    net.WriteUInt(cents, 32)
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
        if not item:GetData("id") then return false end
        return CLIENT
    end
}

-- ============================================================================
-- WALLET RESTRICTION (custom - allows cash, coins, personal_id + designation)
-- ============================================================================

hook.Add("CanTransferItem", "ixWalletRestriction", function(transferItem, curInv, inventory)
    if inventory and inventory.vars and inventory.vars.isWallet then
        -- Only allow cash, coins, and personal_id
        if transferItem.uniqueID ~= "cash" and transferItem.uniqueID ~= "coins" and transferItem.uniqueID ~= "personal_id" then
            return false
        end

        -- Check wallet designation for money
        if transferItem.isCurrency then
            -- Find the wallet item that owns this inventory
            local walletItem = nil
            for _, item in pairs(ix.item.instances) do
                if item.uniqueID == "wallet" and item:GetData("id") == inventory:GetID() then
                    walletItem = item
                    break
                end
            end

            if walletItem then
                local designation = walletItem:GetData("designation", "both")

                if designation == "cash" and transferItem.uniqueID ~= "cash" then
                    return false
                elseif designation == "coins" and transferItem.uniqueID ~= "coins" then
                    return false
                end
            end
        end
    end
end)
