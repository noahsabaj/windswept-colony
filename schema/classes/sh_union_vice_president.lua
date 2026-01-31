--[[
    Vice President - Appointed by Union President
    Second in command of the Union.
]]--

CLASS.name = "Vice President"
CLASS.faction = FACTION_UNION
CLASS.isDefault = false
CLASS.isAnchor = false  -- Not a leader class
CLASS.rank = 254        -- Directly below Union President (255)
CLASS.description = "Second in command of the Miners Union."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Union President."
end

CLASS_UNION_VICE_PRESIDENT = CLASS.index
