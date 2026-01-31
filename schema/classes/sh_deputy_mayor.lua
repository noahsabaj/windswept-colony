--[[
    ADMINISTRATION CLASS: Deputy Mayor
    APPOINTED by the Mayor.
]]--

CLASS.name = "Deputy Mayor"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.isAnchor = false  -- Not a leader class
CLASS.rank = 254        -- Directly below Mayor (255)
CLASS.description = "The Mayor's second in command. You act in their absence."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed Deputy Mayor.")
end

CLASS_DEPUTY_MAYOR = CLASS.index