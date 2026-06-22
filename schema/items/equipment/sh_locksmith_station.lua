--[[
    Locksmith Station Item

    A portable automated locksmith machine for programming locks and keys.
    Drop to place in the world, Hold E to pick back up.
]]--

ITEM.name = "Locksmith Station"
ITEM.description = "An automated machine for programming locks and keys. Place it down to use."
ITEM.model = Model("models/props_lab/reciever01b.mdl")
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Equipment"

-- Don't inherit base_equipment, we're a simple droppable item
ITEM.base = "base_misc"

if SERVER then
    -- Override drop behavior to spawn our custom entity
    function ITEM:OnDrop()
        local client = self:GetOwner()
        if not IsValid(client) then return end

        -- Get drop position
        local trace = client:GetEyeTrace()
        local pos = trace.HitPos + trace.HitNormal * 5

        -- Create the locksmith entity
        local ent = ents.Create("ws_auto_locksmith")

        if not IsValid(ent) then
            return -- Allow default behavior as fallback
        end

        ent:SetPos(pos)
        ent:SetAngles(Angle(0, client:EyeAngles().y, 0))
        ent:Spawn()
        ent:Activate()

        -- Enable physics so it can be moved
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end

        -- Remove item from inventory
        local inventory = self:GetInventory()
        if inventory then
            inventory:Remove(self:GetID())
        end

        return false -- Prevent default ws_item spawn
    end
end
