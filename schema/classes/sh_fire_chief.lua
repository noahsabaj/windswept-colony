--[[
    Fire Chief - Appointed by Mayor

    Leader of the Fire Brigade. The Fire Chief oversees all firefighting
    operations in Redrock City and coordinates emergency response for fires
    and other hazardous situations. They report directly to the Mayor and
    can be recalled at any time.

    The Fire Chief is responsible for:
    - Managing Fire Brigade personnel
    - Setting fire safety protocols
    - Coordinating fire emergency response
    - Advising the Mayor on fire safety regulations
    - Overseeing fire prevention inspections
]]--

CLASS.name = "Fire Chief"
CLASS.faction = FACTION_FIREBRIGADE
CLASS.isDefault = false
CLASS.description = "Head of Redrock City Fire Brigade. Appointed by the Mayor."
CLASS.rank = 255
CLASS.pay = 100

function CLASS:OnCanBe(client)
    return false, "This position must be appointed by the Mayor."
end

CLASS_FIRE_CHIEF = CLASS.index
