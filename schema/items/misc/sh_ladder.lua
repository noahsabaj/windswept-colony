--[[
    Portable Ladder

    A collapsible aluminum ladder. Deploy it to climb surfaces,
    pick it back up when done.

    Controls (when equipped):
    - LMB: Deploy full ladder
    - RMB: Deploy short ladder
    - Hold E on deployed ladder: Pick it back up
]]--

ITEM.name = "Portable Ladder"
ITEM.model = Model("models/weapons/w_ladder.mdl")
ITEM.description = "A collapsible aluminum ladder. Deploy with LMB (full) or RMB (short). Hold E on a deployed ladder to pick it up."
ITEM.width = 4
ITEM.height = 4
ITEM.category = "Equipment"

-- Ladder SWEP: https://steamcommunity.com/sharedfiles/filedetails/?id=3411066267
if SERVER then
    resource.AddWorkshop("3411066267")
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local isEquipped = item:GetData("equipped")

        if isEquipped then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS - EQUIP/UNEQUIP
-- ============================================================================

ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the ladder in your hands.",
    icon = "icon16/arrow_up.png",
    OnRun = function(item)
        local client = item.player

        -- Strip existing ladder SWEP if any
        if client:HasWeapon("weapon_ladder_yl") then
            client:StripWeapon("weapon_ladder_yl")
        end

        -- Set these BEFORE Give() so WeaponEquip hook knows this is from inventory
        client.ixLadderItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("weapon_ladder_yl")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("weapon_ladder_yl")
        end

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        return true
    end
}

ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the ladder away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("weapon_ladder_yl") then
            client:StripWeapon("weapon_ladder_yl")
        end

        client.ixLadderItem = nil
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

function ITEM.postHooks.drop(item, result)
    if item:GetData("equipped") then
        local client = item:GetOwner()
        if IsValid(client) then
            if client:HasWeapon("weapon_ladder_yl") then
                client:StripWeapon("weapon_ladder_yl")
            end
            client.ixLadderItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("weapon_ladder_yl") then
                oldOwner:StripWeapon("weapon_ladder_yl")
            end
            oldOwner.ixLadderItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("ladderEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("weapon_ladder_yl", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixLadderItem = self
        end
    end
end
