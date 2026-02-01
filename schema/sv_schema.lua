--[[
    Windswept Colony RP - Server Schema
]]--

-- Workshop content that clients must download
resource.AddWorkshop("3582530445")  -- Prisoner Playermodels
resource.AddWorkshop("2868046966")  -- Defibrillator Models/Sounds
resource.AddWorkshop("2947598424")  -- Shaky Flashlight Models/Sounds
resource.AddWorkshop("3102372773")  -- Judge Gavel Models
resource.AddWorkshop("764395035")   -- Binoculars Models
resource.AddWorkshop("2840031720")  -- TFA Base (required for TFA weapons)
resource.AddWorkshop("3478998917")  -- TFA INS2 Weapons Pack (Model 10 revolver, etc.)
resource.AddWorkshop("1376312181")  -- TFA INS2 KA-BAR Combat Knife
resource.AddWorkshop("3624686503")  -- Citizen Clothing Overhaul
resource.AddWorkshop("741923773")   -- Assorted Coins

-- Database migrations
ix.util.Include("sv_migration.lua")

-- Network strings for wallet/money system
util.AddNetworkString("ixMoneyDestroy")
util.AddNetworkString("ixMoneyGive")
util.AddNetworkString("ixWalletGive")
util.AddNetworkString("ixCurrencySplit")        -- Server→Client: open split dialog
util.AddNetworkString("ixCurrencySplitConfirm") -- Client→Server: confirm split amount

-- Money destroy handler
net.Receive("ixMoneyDestroy", function(len, client)
    local itemID = net.ReadUInt(32)
    local amount = net.ReadUInt(32)

    local item = ix.item.instances[itemID]
    if not item then return end

    -- Validate ownership
    local character = client:GetCharacter()
    if not character then return end

    local inventory = character:GetInventory()
    if not inventory then return end

    -- Check item is in player's inventory
    if item:GetInventory() ~= inventory:GetID() then
        -- Check if it's in a bag owned by player
        local itemInv = ix.item.inventories[item:GetInventory()]
        if not itemInv or itemInv:GetOwner() ~= character:GetID() then
            return
        end
    end

    -- Validate it's a currency item
    if not item.isCurrency then return end

    local currentQty = item:GetData("quantity", 1)
    amount = math.min(amount, currentQty)

    if amount <= 0 then return end

    if amount >= currentQty then
        -- Destroy entire stack
        item:Remove()

        if item.currencyValue == 100 then
            client:NotifyLocalized("destroyedCash", "$" .. amount)
        else
            client:NotifyLocalized("destroyedCoins", amount .. "¢")
        end
    else
        -- Reduce stack
        item:SetData("quantity", currentQty - amount)

        if item.currencyValue == 100 then
            client:NotifyLocalized("destroyedCash", "$" .. amount)
        else
            client:NotifyLocalized("destroyedCoins", amount .. "¢")
        end
    end
end)

-- Money give handler
net.Receive("ixMoneyGive", function(len, client)
    local itemID = net.ReadUInt(32)
    local amount = net.ReadUInt(32)
    local target = net.ReadEntity()

    -- Validate item
    local item = ix.item.instances[itemID]
    if not item or not item.isCurrency then return end

    -- Validate giver
    local character = client:GetCharacter()
    if not character then return end

    local inventory = character:GetInventory()
    if not inventory then return end

    -- Check item ownership (in main inventory or owned bag)
    local itemInvID = item.invID
    if itemInvID ~= inventory:GetID() then
        local itemInv = ix.item.inventories[itemInvID]
        if not itemInv or itemInv:GetOwner() ~= character:GetID() then
            return
        end
    end

    -- Validate target
    if not IsValid(target) or not target:IsPlayer() then
        client:NotifyLocalized("targetNotValid")
        return
    end

    -- Check range
    if client:GetPos():DistToSqr(target:GetPos()) > (100 * 100) then
        client:NotifyLocalized("targetTooFar")
        return
    end

    -- Check target is alive
    if not target:Alive() then
        client:NotifyLocalized("targetNotAlive")
        return
    end

    -- Check target is not knocked
    local targetChar = target:GetCharacter()
    if not targetChar then
        client:NotifyLocalized("targetNotValid")
        return
    end

    if target:GetNetVar("ixKnocked", false) then
        client:NotifyLocalized("targetKnocked")
        return
    end

    -- Check target is not zip tied
    if target:GetNetVar("ixRestricted", false) then
        client:NotifyLocalized("targetRestrained")
        return
    end

    -- Validate amount
    local currentQty = item:GetData("quantity", 1)
    amount = math.min(amount, currentQty)
    if amount <= 0 then return end

    -- Calculate cents to give
    local centsToGive = amount * item.currencyValue

    -- Try to add to target's inventory (use wallet routing if available)
    local targetInv = targetChar:GetInventory()
    if not targetInv then
        client:NotifyLocalized("targetNoInventory")
        return
    end

    -- Use wallet-aware routing if available, otherwise fallback to standard
    local success
    if ix.currency.AddToInventoryWithWallet then
        success = ix.currency.AddToInventoryWithWallet(target, centsToGive)
    else
        success = ix.currency.AddToInventory(targetInv, centsToGive)
    end

    if not success then
        client:NotifyLocalized("targetInventoryFull")
        return
    end

    -- Remove from giver
    if amount >= currentQty then
        item:Remove()
    else
        item:SetData("quantity", currentQty - amount)
    end

    -- Notify both parties
    local moneyStr = item.currencyValue == 100 and ("$" .. amount) or (amount .. "¢")
    client:NotifyLocalized("gaveMoneyTo", moneyStr, target:Nick())
    target:NotifyLocalized("receivedMoneyFrom", moneyStr, client:Nick())
end)

-- Wallet give handler
net.Receive("ixWalletGive", function(len, client)
    local walletItemID = net.ReadUInt(32)
    local cents = net.ReadUInt(32)
    local target = net.ReadEntity()

    -- Validate wallet item
    local walletItem = ix.item.instances[walletItemID]
    if not walletItem or walletItem.uniqueID ~= "wallet" then return end

    -- Validate ownership
    local character = client:GetCharacter()
    if not character then return end

    local inventory = character:GetInventory()
    if not inventory then return end

    -- Check wallet is in player's main inventory
    if walletItem.invID ~= inventory:GetID() then return end

    -- Get wallet inventory
    local walletInvID = walletItem:GetData("id")
    if not walletInvID then return end

    local walletInv = ix.item.inventories[walletInvID]
    if not walletInv then return end

    -- Validate target
    if not IsValid(target) or not target:IsPlayer() then
        client:NotifyLocalized("targetNotValid")
        return
    end

    if client:GetPos():DistToSqr(target:GetPos()) > (100 * 100) then
        client:NotifyLocalized("targetTooFar")
        return
    end

    if not target:Alive() then
        client:NotifyLocalized("targetNotAlive")
        return
    end

    local targetChar = target:GetCharacter()
    if not targetChar then
        client:NotifyLocalized("targetNotValid")
        return
    end

    if target:GetNetVar("ixKnocked", false) then
        client:NotifyLocalized("targetKnocked")
        return
    end

    if target:GetNetVar("ixRestricted", false) then
        client:NotifyLocalized("targetRestrained")
        return
    end

    -- Calculate available money in wallet
    local available = ix.wallet and ix.wallet.GetWalletMoney and ix.wallet.GetWalletMoney(walletInv) or 0
    cents = math.min(cents, available)

    if cents <= 0 then
        client:NotifyLocalized("walletEmpty")
        return
    end

    -- Remove from wallet
    if not ix.currency.RemoveFromInventory(walletInv, cents) then
        client:NotifyLocalized("walletEmpty")
        return
    end

    -- Give to target (using wallet routing if available)
    local success
    if ix.currency.AddToInventoryWithWallet then
        success = ix.currency.AddToInventoryWithWallet(target, cents)
    else
        local targetInv = targetChar:GetInventory()
        success = targetInv and ix.currency.AddToInventory(targetInv, cents)
    end

    if not success then
        -- Refund if target can't receive
        ix.currency.AddToInventory(walletInv, cents)
        client:NotifyLocalized("targetInventoryFull")
        return
    end

    -- Notify both parties
    local dollars = math.floor(cents / 100)
    local remainingCents = cents % 100
    local moneyStr = string.format("$%d.%02d", dollars, remainingCents)

    client:NotifyLocalized("gaveMoneyTo", moneyStr, target:Nick())
    target:NotifyLocalized("receivedMoneyFrom", moneyStr, client:Nick())
end)

-- Currency split handler
net.Receive("ixCurrencySplitConfirm", function(len, client)
    local itemID = net.ReadUInt(32)
    local splitAmount = net.ReadUInt(16)

    -- Validate item
    local item = ix.item.instances[itemID]
    if not item or not item.isCurrency then return end

    -- Validate ownership
    local character = client:GetCharacter()
    if not character then return end

    local inventory = character:GetInventory()
    if not inventory then return end

    -- Check item ownership (in main inventory or owned bag)
    local itemInvID = item.invID
    if itemInvID ~= inventory:GetID() then
        local itemInv = ix.item.inventories[itemInvID]
        if not itemInv or itemInv:GetOwner() ~= character:GetID() then
            return
        end
    end

    -- Validate split amount
    local currentQty = item:GetData("quantity", 1)
    if splitAmount <= 0 or splitAmount >= currentQty then
        client:Notify("Invalid split amount.")
        return
    end

    -- Get the inventory the item is in (could be main inventory or a bag)
    local targetInv = ix.item.inventories[itemInvID]
    if not targetInv then return end

    -- Try to add new stack to the same inventory
    local success = targetInv:Add(item.uniqueID, 1, {
        quantity = splitAmount
    })

    if success then
        -- Reduce original stack
        item:SetData("quantity", currentQty - splitAmount)

        if item.currencyValue == 100 then
            client:Notify("Split off $" .. splitAmount .. " into a new stack.")
        else
            client:Notify("Split off " .. splitAmount .. "¢ into a new stack.")
        end
    else
        client:Notify("No room in inventory for new stack.")
    end
end)

-- Disable faction whitelist requirements
-- All factions are open for transfer without needing /PlyWhitelist first
-- Players start factionless (no faction) and admins use /PlyTransfer to assign factions
local playerMeta = FindMetaTable("Player")

function playerMeta:HasWhitelist(faction)
    -- Always return true - no whitelist restrictions
    return true
end

-- Give Personal ID to ALL new characters (moved from Civilians faction)
hook.Add("OnCharacterCreated", "ixWindsweptPersonalID", function(client, character)
    -- Generate a unique 5-digit ID number
    local id = string.format("%05d", math.random(1, 99999))
    local inventory = character:GetInventory()

    -- Store the ID on the character for reference
    character:SetData("personalID", id)

    -- Get physical data stored during character creation
    local physical = character:GetData("physical", {})

    -- Give them their Personal ID card with physical attributes
    inventory:Add("personal_id", 1, {
        ownerName = character:GetName(),
        id = id,
        physical = physical
    })
end)
