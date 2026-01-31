--[[
    Ballot Station Entity - Shared
    Physical voting station for succession votes
]]--

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Ballot Station"
ENT.Author = "Windswept"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.Category = "Windswept"

ENT.PopulateEntityInfo = true

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "InUse")
    self:NetworkVar("Entity", 0, "User")
end
