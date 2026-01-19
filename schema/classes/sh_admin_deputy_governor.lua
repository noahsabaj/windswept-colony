--[[
    ADMINISTRATION CLASS: Deputy Governor
    APPOINTED by the Governor.
]]--

CLASS.name = "Deputy Governor"
CLASS.faction = FACTION_ADMINISTRATION
CLASS.isDefault = false
CLASS.description = "The Governor's second in command. You act in their absence."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been appointed Deputy Governor.")
end

CLASS_DEPUTY_GOVERNOR = CLASS.index
