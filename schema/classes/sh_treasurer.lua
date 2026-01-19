--[[
    Treasurer - Appointed by Union President
    Manages union dues and funds.
]]--

CLASS.name = "Treasurer"
CLASS.faction = FACTION_UNION
CLASS.isDefault = false
CLASS.description = "Manages the union's finances and dues."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Union President."
end

CLASS_TREASURER = CLASS.index
