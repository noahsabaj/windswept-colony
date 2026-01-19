--[[
    CONGLOMERATE CLASS: Shift Supervisor
    APPOINTED by the Head Foreman.
    
    Manages mining shifts and worker productivity.
]]--

CLASS.name = "Shift Supervisor"
CLASS.faction = FACTION_CONGLOMERATE
CLASS.isDefault = true
CLASS.description = "A corporate supervisor. You manage shifts and ensure productivity quotas are met."

function CLASS:OnCanBe(client)
    return true
end

function CLASS:OnSet(client)
    client:ChatPrint("You are now a Shift Supervisor.")
end

CLASS_SHIFT_SUPERVISOR = CLASS.index
