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

-- Disable faction whitelist requirements
-- All factions are open for transfer without needing /PlyWhitelist first
-- Players still start as Civilians (the only isDefault=true faction)
-- but admins can /PlyTransfer them to any faction directly
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
