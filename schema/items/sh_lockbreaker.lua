--[[
    Lockbreaker

    A large saw-like tool that destroys locks through brute force.
    - RMB on lock: 20-second loud destruction
    - Creaking metal sound during operation
    - Loud SNAP when complete
    - Destroys lock completely (removed from door)
    - Door becomes lockless

    This is a loud, obvious method - not stealthy like lockpicking.
]]--

ITEM.name = "Lockbreaker"
ITEM.description = "A heavy-duty tool for destroying locks. Very loud."
ITEM.model = "models/weapons/w_crowbar.mdl"  -- Placeholder
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Tools"
ITEM.noBusiness = true
ITEM.class = "ix_lockbreaker"
ITEM.weaponCategory = "lockbreaker"

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local isEquipped = item:GetData("equipped")

        -- Draw equipped indicator (green dot)
        if isEquipped then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Equip lockbreaker
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the lockbreaker to destroy locks.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing lockbreaker from this player
        if client.ixLockbreakerItem and client.ixLockbreakerItem ~= item then
            local oldItem = client.ixLockbreakerItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing lockbreaker SWEP if any
        if client:HasWeapon("ix_lockbreaker") then
            client:StripWeapon("ix_lockbreaker")
        end

        -- Set these BEFORE Give() so hooks see them
        client.ixLockbreakerItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("ix_lockbreaker")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_lockbreaker")
        end

        client:EmitSound("physics/metal/metal_box_impact_hard1.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        return true
    end
}

-- Unequip lockbreaker
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the lockbreaker away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_lockbreaker") then
            client:StripWeapon("ix_lockbreaker")
        end

        client.ixLockbreakerItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/metal/metal_box_impact_soft1.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equipped") == true
    end
}

-- ============================================================================
-- HOOKS
-- ============================================================================

function ITEM.postHooks.drop(item, result)
    if item:GetData("equipped") then
        local client = item:GetOwner()
        if IsValid(client) then
            if client:HasWeapon("ix_lockbreaker") then
                client:StripWeapon("ix_lockbreaker")
            end
            client.ixLockbreakerItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_lockbreaker") then
                oldOwner:StripWeapon("ix_lockbreaker")
            end
            oldOwner.ixLockbreakerItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("lockbreakerEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_lockbreaker", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixLockbreakerItem = self
        end
    end
end
