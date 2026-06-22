--[[
    Windswept Colony RP - Server Schema
]]--

-- Workshop content that clients must download
resource.AddWorkshop("3582530445")  -- Prisoner Playermodels
resource.AddWorkshop("2868046966")  -- Defibrillator Models/Sounds
resource.AddWorkshop("2947598424")  -- Extended Flashlight (VManip SWEP; provides the shaky_flashlight base)
resource.AddWorkshop("2155366756")  -- VManip (Base) — required base of the Shaky Flashlight SWEP
resource.AddWorkshop("3102372773")  -- Judge Gavel Models
resource.AddWorkshop("764395035")   -- Binoculars Models
resource.AddWorkshop("2840031720")  -- TFA Base (required for TFA weapons)
resource.AddWorkshop("3478998917")  -- TFA INS2 Weapons Pack (Model 10 revolver, etc.)
resource.AddWorkshop("2840032487")  -- TFA INS2 Shared Parts (required by the INS2 weapon pack)
resource.AddWorkshop("1376312181")  -- TFA INS2 KA-BAR Combat Knife
resource.AddWorkshop("3624686503")  -- Citizen Clothing Overhaul
resource.AddWorkshop("741923773")   -- Assorted Coins
resource.AddWorkshop("635535045")   -- Handheld Radio Model (c_model + w_model)

-- Disable TFA weapon inspection menu (opens on C key)
-- This menu shows weapon stats, damage graphs, and allows swapping ammo types
-- which violates our scarcity principle (nothing appears from nowhere)
RunConsoleCommand("sv_tfa_cmenu", "0")

-- Centralized network string registry (schema + entities)
ws.util.Include("sv_netstrings.lua")

-- Validate a give target (valid player, in range, alive, not incapacitated)
-- Returns targetChar on success, nil on failure (notifications sent to client)
local function ValidateGiveTarget(client, target)
    if not IsValid(target) or not target:IsPlayer() then
        client:NotifyLocalized("targetNotValid")
        return nil
    end

    if not ws.constants.CanInteract(client, target) then
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

    if target:GetNetVar("wsKnocked", false) then
        client:NotifyLocalized("targetKnocked")
        return nil
    end

    if target:GetNetVar("wsRestricted", false) then
        client:NotifyLocalized("targetRestrained")
        return nil
    end

    return targetChar
end

-- Wallet give handler. Migrated to ws.action: item = "wallet" + access = "owned" reproduces the
-- wallet-in-main-inventory ownership check; target + range = "none" + ValidateGiveTarget (which
-- carries its own per-failure notifications) reproduce the give-target validation; read() carries
-- the cents amount. Wire order is item, target, then cents (ws.action's fixed argument order).
ws.action.Register("wsWalletGive", {
    item = "wallet",
    access = "owned",
    target = true,
    range = "none",  -- ValidateGiveTarget does the CanInteract range check (with a "targetTooFar" notify)
    read = function() return net.ReadUInt(32) end,  -- cents
    onValidate = function(client, ctx)
        -- ValidateGiveTarget reproduces every target guard (player/range/alive/character/
        -- knocked/restrained) along with its per-failure notifications.
        local targetChar = ValidateGiveTarget(client, ctx.target)
        if not targetChar then return false end

        -- Wallet inner inventory must resolve.
        local walletInvID = ctx.item:GetData("id")
        if not walletInvID then return false end
        local walletInv = ws.item.inventories[walletInvID]
        if not walletInv then return false end

        ctx.targetChar = targetChar
        ctx.walletInv = walletInv
        return true
    end,
    run = function(client, ctx)
        local target = ctx.target
        local targetChar = ctx.targetChar
        local walletInv = ctx.walletInv

        -- Calculate available money in wallet
        local available = ws.wallet and ws.wallet.GetWalletMoney and ws.wallet.GetWalletMoney(walletInv) or 0
        local cents = math.min(ctx.data, available)

        if cents <= 0 then
            client:NotifyLocalized("walletEmpty")
            return
        end

        -- Remove from wallet
        if not ws.currency.RemoveFromInventory(walletInv, cents) then
            client:NotifyLocalized("walletEmpty")
            return
        end

        -- Give to target (using wallet routing if available)
        local success
        if ws.currency.AddToInventoryWithWallet then
            success = ws.currency.AddToInventoryWithWallet(target, cents)
        else
            local targetInv = targetChar:GetInventory()
            success = targetInv and ws.currency.AddToInventory(targetInv, cents)
        end

        if not success then
            -- Refund if target can't receive
            ws.currency.AddToInventory(walletInv, cents)
            client:NotifyLocalized("targetInventoryFull")
            return
        end

        -- Notify both parties
        local dollars = math.floor(cents / 100)
        local remainingCents = cents % 100
        local moneyStr = string.format("$%d.%02d", dollars, remainingCents)

        client:NotifyLocalized("gaveMoneyTo", moneyStr, target:Nick())
        target:NotifyLocalized("receivedMoneyFrom", moneyStr, client:Nick())
    end
})

-- Disable faction whitelist requirements
-- All factions are open for transfer without needing /PlyWhitelist first
-- Players start factionless (no faction) and admins use /PlyTransfer to assign factions
local playerMeta = FindMetaTable("Player")

function playerMeta:HasWhitelist(faction)
    -- Always return true - no whitelist restrictions
    return true
end

-- (The Personal ID card was removed; new characters no longer receive one. Their physical
-- descriptors live on the character itself via GetData("physical"), set during creation.)
