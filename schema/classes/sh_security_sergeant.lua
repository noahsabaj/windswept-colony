--[[
    SECURITY CLASS: Security Sergeant
    APPOINTED by the Security Chief.
    
    Mid-level security leadership.
]]--

CLASS.name = "Security Sergeant"
CLASS.faction = FACTION_SECURITY
CLASS.isDefault = false
CLASS.description = "A Security Sergeant. You lead squads of officers under the Chief's command."

function CLASS:OnCanBe(client)
    return client:IsAdmin()
end

function CLASS:OnSet(client)
    client:ChatPrint("You have been promoted to Security Sergeant.")
end

CLASS_SECURITY_SERGEANT = CLASS.index
