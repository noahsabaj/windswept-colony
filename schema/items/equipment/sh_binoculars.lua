--[[
    Binoculars Item

    Used to see far distances.
    Equip to use as a SWEP.
]]--

ITEM.name = "Binoculars"
ITEM.description = "A pair of binoculars for seeing far distances."
ITEM.model = Model("models/weapons/w_binocularsbp.mdl")
ITEM.width = 2
ITEM.height = 1
ITEM.price = 75
ITEM.category = "Equipment"

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        if item:GetData("equipped") then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the binoculars in your hands.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Check if already has binoculars equipped
        if client.ixBinocularsItem and client.ixBinocularsItem ~= item then
            local oldItem = client.ixBinocularsItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing binoculars SWEP if any
        if client:HasWeapon("ix_binoculars") then
            client:StripWeapon("ix_binoculars")
        end

        -- Give the SWEP
        local weapon = client:Give("ix_binoculars")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_binoculars")
        end

        client.ixBinocularsItem = item
        item:SetData("equipped", true)

        return false
    end,
    OnCanRun = function(item)
        -- Can't equip if on ground
        if IsValid(item.entity) then return false end
        -- Can't equip if already equipped
        if item:GetData("equipped") then return false end

        return true
    end
}

ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the binoculars away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        -- Remove SWEP
        if client:HasWeapon("ix_binoculars") then
            client:StripWeapon("ix_binoculars")
        end

        client.ixBinocularsItem = nil
        item:SetData("equipped", nil)

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equipped") == true
    end
}

-- ============================================================================
-- HOOKS
-- ============================================================================

-- Unequip when dropped
function ITEM.postHooks.drop(item, result)
    if item:GetData("equipped") then
        local client = item:GetOwner()
        if IsValid(client) then
            if client:HasWeapon("ix_binoculars") then
                client:StripWeapon("ix_binoculars")
            end
            client.ixBinocularsItem = nil
        end
        item:SetData("equipped", nil)
    end
end

-- Handle transfer
function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_binoculars") then
                oldOwner:StripWeapon("ix_binoculars")
            end
            oldOwner.ixBinocularsItem = nil
        end
        self:SetData("equipped", nil)
    end
end

-- Can't transfer while equipped
function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        return false
    end
    return true
end

-- Restore equipped state on character load
function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_binoculars", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixBinocularsItem = self
        end
    end
end
