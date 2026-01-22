--[[
    Prisoner - Default class for Prisoners faction

    Assigned automatically when sentenced by a judge.
    Cannot be selected manually.
]]--

CLASS.name = "Prisoner"
CLASS.faction = FACTION_PRISONERS
CLASS.isDefault = true
CLASS.description = "You are serving time at Skarn Prison. Follow the rules and serve your sentence."

function CLASS:OnCanBe(client)
    return false, "You cannot choose to be a prisoner."
end

CLASS_PRISONER = CLASS.index
