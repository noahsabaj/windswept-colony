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
resource.AddWorkshop("635535045")   -- Handheld Radio Model (c_model + w_model)

-- Disable TFA weapon inspection menu (opens on C key)
-- This menu shows weapon stats, damage graphs, and allows swapping ammo types
-- which violates our scarcity principle (nothing appears from nowhere)
RunConsoleCommand("sv_tfa_cmenu", "0")

-- Centralized network string registry (schema + entities)
ix.util.Include("sv_netstrings.lua")

-- Document system server handlers
ix.util.Include("sv_documents.lua")

-- Validate a give target (valid player, in range, alive, not incapacitated)
-- Returns targetChar on success, nil on failure (notifications sent to client)
local function ValidateGiveTarget(client, target)
    if not IsValid(target) or not target:IsPlayer() then
        client:NotifyLocalized("targetNotValid")
        return nil
    end

    if not ix.constants.CanInteract(client, target) then
        client:NotifyLocalized("targetTooFar")
        return nil
    end

    if not target:Alive() then
        client:NotifyLocalized("targetNotAlive")
        return nil
    end

    local targetChar = target:GetCharacter()
    if not targetChar then
        client:NotifyLocalized("targetNotValid")
        return nil
    end

    if target:GetNetVar("ixKnocked", false) then
        client:NotifyLocalized("targetKnocked")
        return nil
    end

    if target:GetNetVar("ixRestricted", false) then
        client:NotifyLocalized("targetRestrained")
        return nil
    end

    return targetChar
end

-- Wallet give handler
net.Receive("ixWalletGive", function(len, client)
    local walletItemID = net.ReadUInt(32)
    local cents = net.ReadUInt(32)
    local target = net.ReadEntity()

    -- Validate wallet item
    local walletItem = ix.item.instances[walletItemID]
    if not walletItem or walletItem.uniqueID ~= "wallet" then return end

    -- Validate ownership
    local character, inventory = ix.constants.GetCharacterInventory(client)
    if not character or not inventory then return end

    -- Check wallet is in player's main inventory
    if walletItem.invID ~= inventory:GetID() then return end

    -- Get wallet inventory
    local walletInvID = walletItem:GetData("id")
    if not walletInvID then return end

    local walletInv = ix.item.inventories[walletInvID]
    if not walletInv then return end

    -- Validate target
    local targetChar = ValidateGiveTarget(client, target)
    if not targetChar then return end

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
