--[[
    Chief Medical Officer - Appointed by Mayor

    Leader of the Medical Department. The CMO oversees all medical operations
    at Redrock City General Hospital and coordinates medical affairs across
    the colony. They report directly to the Mayor and can be recalled at any time.

    The CMO is responsible for:
    - Managing hospital staff and operations
    - Setting medical protocols and procedures
    - Coordinating emergency medical response
    - Advising the Mayor on public health matters
]]--

CLASS.name = "Chief Medical Officer"
CLASS.faction = FACTION_MEDICAL
CLASS.isDefault = false
CLASS.description = "Head of Redrock City Medical Department. Appointed by the Mayor."
CLASS.rank = 255
CLASS.pay = 140

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Mayor."
end

CLASS_CMO = CLASS.index
