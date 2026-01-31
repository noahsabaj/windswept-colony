--[[
    Governor - APPOINTED by Admin

    The Governor is part of the Conglomerate faction and represents the
    Conglomerate's authority over the colony. They have subordinate authority
    over both Administration (Mayor) and Security (Commissioner), meaning they
    can hire/fire both leaders at will.

    The Governor is responsible for overseeing the administration of the colony and
    ensuring that the Conglomerate's interests are represented. They have the
    authority to make high-level decisions regarding the colony's governance,
    including economic policies, security measures, and diplomatic relations with
    other factions. The Governor works closely with the Mayor and other officials
    to ensure the smooth operation of the colony and the well-being of its citizens.

    The Governor will rarely be present in the colony, often delegating day-to-day
    operations to the Mayor and other local officials. However, they hold significant
    power and can intervene in local matters when necessary, especially in cases
    that impact the Conglomerate's broader interests.
]]--

CLASS.name = "Governor"
CLASS.faction = FACTION_CONGLOMERATE
CLASS.isDefault = false
CLASS.description = "Colonial Governor. Has authority over both Mayor and Commissioner. Appointed by Admin."
CLASS.rank = 255
CLASS.pay = 300

function CLASS:OnCanBe(client)
    return false, "This position must be assigned through appointment."
end

CLASS_GOVERNOR = CLASS.index
