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

-- Disable faction whitelist requirements
-- All factions are open for transfer without needing /PlyWhitelist first
-- Players still start as Civilians (the only isDefault=true faction)
-- but admins can /PlyTransfer them to any faction directly
local playerMeta = FindMetaTable("Player")

function playerMeta:HasWhitelist(faction)
    -- Always return true - no whitelist restrictions
    return true
end
