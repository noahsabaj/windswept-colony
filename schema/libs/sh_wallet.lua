--[[
    Wallet-Aware Currency Routing

    Provides ix.currency.AddToInventoryWithWallet() which routes money to wallets
    before falling back to main inventory.

    Priority:
    - Coins: coins-only wallet -> both wallet -> main inventory
    - Cash: cash-only wallet -> both wallet -> main inventory

    Wallets are sorted by current money amount (descending) within each priority tier.
]]

ix.wallet = ix.wallet or {}

if SERVER then
    -- Find all wallets in a player's main inventory
    function ix.wallet.GetWallets(client)
        local character = client:GetCharacter()
        if not character then return {} end

        local inventory = character:GetInventory()
        if not inventory then return {} end

        local wallets = {}
        for _, item in pairs(inventory:GetItems()) do
            if item.uniqueID == "wallet" then
                local invID = item:GetData("id")
                if invID then
                    local walletInv = ix.item.inventories[invID]
                    if walletInv then
                        table.insert(wallets, {
                            item = item,
                            inventory = walletInv,
                            designation = item:GetData("designation", "both")
                        })
                    end
                end
            end
        end

        return wallets
    end

    -- Calculate total money in a wallet inventory
    function ix.wallet.GetWalletMoney(walletInv)
        local total = 0
        for _, item in pairs(walletInv:GetItems()) do
            if item.isCurrency then
                local qty = item:GetData("quantity", 1)
                total = total + (qty * item.currencyValue)
            end
        end
        return total
    end

    -- Find best wallet for a currency type
    -- Returns wallet inventory or nil
    -- Priority: specialized wallet -> general (both) wallet
    function ix.wallet.FindBestWallet(client, currencyType)
        local wallets = ix.wallet.GetWallets(client)
        if #wallets == 0 then return nil end

        -- Cache item definition lookup (avoid repeated table access)
        local itemClass = currencyType == "cash" and "cash" or "coins"
        local itemDef = ix.item.list[itemClass]
        if not itemDef then return nil end

        local itemWidth = itemDef.width or 1
        local itemHeight = itemDef.height or 1

        -- First pass: find specialized and general wallets with pre-calculated money
        local specialized = {}
        local general = {}

        for _, wallet in ipairs(wallets) do
            -- Cache money amount during categorization (avoids recalculating during sort)
            wallet.cachedMoney = ix.wallet.GetWalletMoney(wallet.inventory)

            if wallet.designation == currencyType then
                specialized[#specialized + 1] = wallet
            elseif wallet.designation == "both" then
                general[#general + 1] = wallet
            end
        end

        -- Sort by cached money amount (descending - most money first)
        -- Only sort if more than 1 wallet in category
        local function sortByMoney(a, b)
            return a.cachedMoney > b.cachedMoney
        end

        if #specialized > 1 then
            table.sort(specialized, sortByMoney)
        end
        if #general > 1 then
            table.sort(general, sortByMoney)
        end

        -- Try specialized first (coins-only for coins, cash-only for cash)
        for i = 1, #specialized do
            local x, y = specialized[i].inventory:FindEmptySlot(itemWidth, itemHeight)
            if x and y then
                return specialized[i].inventory
            end
        end

        -- Then try general (both) wallets
        for i = 1, #general do
            local x, y = general[i].inventory:FindEmptySlot(itemWidth, itemHeight)
            if x and y then
                return general[i].inventory
            end
        end

        return nil
    end

    -- Add money to inventory with wallet routing
    -- This is the main function to use instead of ix.currency.AddToInventory
    -- Routes to wallets first, then falls back to main inventory
    function ix.currency.AddToInventoryWithWallet(client, cents)
        if cents <= 0 then return true end

        local character = client:GetCharacter()
        if not character then return false end

        local mainInv = character:GetInventory()
        if not mainInv then return false end

        -- Split into dollars and coins
        local dollars = math.floor(cents / 100)
        local coins = cents % 100

        local success = true

        -- Route dollars
        if dollars > 0 then
            local dollarCents = dollars * 100
            local cashWallet = ix.wallet.FindBestWallet(client, "cash")

            if cashWallet then
                -- Try wallet first
                if not ix.currency.AddToInventory(cashWallet, dollarCents) then
                    -- Overflow to main inventory
                    if not ix.currency.AddToInventory(mainInv, dollarCents) then
                        success = false
                    end
                end
            else
                -- No wallet, use main inventory
                if not ix.currency.AddToInventory(mainInv, dollarCents) then
                    success = false
                end
            end
        end

        -- Route coins
        if coins > 0 then
            local coinsWallet = ix.wallet.FindBestWallet(client, "coins")

            if coinsWallet then
                -- Try wallet first
                if not ix.currency.AddToInventory(coinsWallet, coins) then
                    -- Overflow to main inventory
                    if not ix.currency.AddToInventory(mainInv, coins) then
                        success = false
                    end
                end
            else
                -- No wallet, use main inventory
                if not ix.currency.AddToInventory(mainInv, coins) then
                    success = false
                end
            end
        end

        return success
    end
end
