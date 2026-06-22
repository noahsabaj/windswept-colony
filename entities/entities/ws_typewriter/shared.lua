--[[
    Typewriter Entity - Shared

    A placeable typewriter for creating typed documents.
]]--

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Typewriter"
ENT.Author = "Windswept"
ENT.Category = "Windswept"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "ItemID")
    self:NetworkVar("Entity", 0, "User")
end
