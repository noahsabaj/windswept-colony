--[[
    Model 10 Revolver Item
    .38 caliber revolver - 6 round cylinder
    Uses tfa_ins2_wpn_38revolver from TFA INS2 Weapons pack
]]--

ITEM.base = "base_weapons"
ITEM.name = "Model 10"
ITEM.description = "A Smith & Wesson .38 caliber revolver."
ITEM.model = Model("models/tfa_ins2_wpns/38revolver/w_38rev.mdl")
ITEM.class = "tfa_ins2_wpn_38revolver"
ITEM.weaponCategory = "sidearm"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Firearms"

ITEM.iconCam = {
    ang = Angle(-3, 270, 0),
    fov = 8,
    pos = Vector(0, 200, -1)
}

-- Load Ammo function - requires weapon to be equipped
ITEM.functions.LoadAmmo = {
    name = "Load Ammo",
    tip = "Load .357 ammunition into the revolver",
    icon = "icon16/bullet_add.png",
    OnRun = function(item)
        local client = item.player
        local character, inventory = ix.constants.GetCharacterInventory(client)
        if not character or not inventory then return false end

        -- Find a .357 ammo item in the player's inventory
        local ammoItem = inventory:HasItem("357ammo")

        if not ammoItem then
            client:NotifyLocalized("noAmmoToLoad")
            return false
        end

        -- Get the equipped weapon
        local weapon = client:GetActiveWeapon()

        if not IsValid(weapon) or weapon:GetClass() ~= item.class then
            client:NotifyLocalized("mustHoldWeapon")
            return false
        end

        -- Remove the ammo item from inventory
        ammoItem:Remove()

        -- Give 12 rounds to player's reserve ammo
        client:GiveAmmo(12, "357")
        client:EmitSound("items/ammo_pickup.wav", 80)

        return false
    end,
    OnCanRun = function(item)
        local client = item.player

        -- Must be in inventory (not dropped), must be equipped
        if IsValid(item.entity) then
            return false
        end

        if not item:GetData("equipped") then
            return false
        end

        -- Must be holding this weapon
        local weapon = client:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= item.class then
            return false
        end

        -- Must have ammo in inventory
        local _, inventory = ix.constants.GetCharacterInventory(client)
        if not inventory or not inventory:HasItem("357ammo") then
            return false
        end

        return true
    end
}
