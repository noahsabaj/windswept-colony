--[[
    Union Secretary - Appointed by Union President
    Handles union records, communications, and organization.
]]--

CLASS.name = "Union Secretary"
CLASS.faction = FACTION_UNION
CLASS.isDefault = false
CLASS.description = "Handles union administration and communications."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Union President."
end

CLASS_UNION_SECRETARY = CLASS.index
