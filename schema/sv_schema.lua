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
