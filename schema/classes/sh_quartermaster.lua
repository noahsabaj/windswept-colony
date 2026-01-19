--[[
    Quartermaster - Appointed by Governor
    Manages colonial supplies and resource distribution.
]]--

CLASS.name = "Quartermaster"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "Manager of colonial supplies and logistics."

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Governor."
end

CLASS_QUARTERMASTER = CLASS.index
