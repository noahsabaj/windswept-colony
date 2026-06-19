--[[
    Base Equippable Item

    Base class for items that can be equipped as SWEPs.
    Provides standard Equip/Unequip functionality, transfer blocking, and persistence.

    Configuration (child items must set these):
        ITEM.equipWeaponClass   - The SWEP class to give (e.g., "ix_binoculars")
        ITEM.equipPlayerKey     - Key to store item reference on player (e.g., "wsBinocularsItem")
        ITEM.equipNotifyKey     - Localization key for "unequip first" message (e.g., "binocularsEquipped")

    Optional configuration:
        ITEM.equipSound         - Sound to play on equip (default: "items/ammo_pickup.wav")
        ITEM.equipSoundVolume   - Equip sound volume (default: 0.5)
        ITEM.unequipSoundVolume - Unequip sound volume (default: 0.3)
        ITEM.equipTip           - Tooltip for equip button (default: "Equip this item.")
        ITEM.unequipTip         - Tooltip for unequip button (default: "Put this item away.")

    Optional override methods:
        ITEM:CanEquip()         - Return false to prevent equipping (e.g., item not programmed)

    Example child item:
        ITEM.name = "Binoculars"
        ITEM.model = "models/weapons/w_binocularsbp.mdl"
        ITEM.base = "base_equippable"

        ITEM.equipWeaponClass = "ix_binoculars"
        ITEM.equipPlayerKey = "wsBinocularsItem"
        ITEM.equipNotifyKey = "binocularsEquipped"
]]--

ITEM.name = "Equippable Item"
ITEM.description = "An item that can be equipped."
ITEM.category = "Equipment"
ITEM.model = "models/props_junk/cardboard_box004a.mdl"
ITEM.width = 1
ITEM.height = 1

-- Configuration defaults
ITEM.equipWeaponClass = nil     -- MUST be set by child
ITEM.equipPlayerKey = nil       -- MUST be set by child
ITEM.equipNotifyKey = nil       -- MUST be set by child
ITEM.equipSound = "items/ammo_pickup.wav"
ITEM.equipSoundVolume = 0.5
ITEM.unequipSoundVolume = 0.3
ITEM.equipTip = "Equip this item."
ITEM.unequipTip = "Put this item away."

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        if item:GetData("equipped") then
            ws.constants.DrawEquippedIndicator(w, h)
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

ITEM.functions.Equip = {
    name = "Equip",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end

        local weaponClass = item.equipWeaponClass
        local playerKey = item.equipPlayerKey

        if not weaponClass or not playerKey then
            ErrorNoHalt("[base_equippable] Missing equipWeaponClass or equipPlayerKey for " .. item.uniqueID .. "\n")
            return false
        end

        -- Unequip any existing item of this type
        local existingItem = client[playerKey]
        if existingItem and existingItem ~= item then
            existingItem:SetData("equipped", nil)
        end

        -- Strip existing weapon if any
        if client:HasWeapon(weaponClass) then
            client:StripWeapon(weaponClass)
        end

        -- Give the SWEP
        local weapon = client:Give(weaponClass)
        if IsValid(weapon) then
            weapon.wsItem = item
            client:SelectWeapon(weaponClass)
        end

        client[playerKey] = item
        item:SetData("equipped", true)

        -- Play equip sound
        if item.equipSound then
            client:EmitSound(item.equipSound, 75, 100, item.equipSoundVolume or 0.5)
        end

        return false
    end,
    OnCanRun = function(item)
        -- Can't equip if on ground
        if IsValid(item.entity) then return false end
        -- Can't equip if already equipped
        if item:GetData("equipped") then return false end
        -- Allow child items to add additional checks (e.g., IsProgrammed)
        if item.CanEquip and not item:CanEquip() then return false end

        return true
    end
}

ITEM.functions.Unequip = {
    name = "Unequip",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end

        local weaponClass = item.equipWeaponClass
        local playerKey = item.equipPlayerKey

        if not weaponClass or not playerKey then return false end

        -- Remove SWEP
        if client:HasWeapon(weaponClass) then
            client:StripWeapon(weaponClass)
        end

        client[playerKey] = nil
        item:SetData("equipped", nil)

        -- Play unequip sound
        if item.equipSound then
            client:EmitSound(item.equipSound, 75, 100, item.unequipSoundVolume or 0.3)
        end

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
        local weaponClass = item.equipWeaponClass
        local playerKey = item.equipPlayerKey

        if IsValid(client) and weaponClass then
            if client:HasWeapon(weaponClass) then
                client:StripWeapon(weaponClass)
            end
            if playerKey then
                client[playerKey] = nil
            end
        end
        item:SetData("equipped", nil)
    end
end

-- Handle transfer to different inventory
function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        local weaponClass = self.equipWeaponClass
        local playerKey = self.equipPlayerKey

        if IsValid(oldOwner) and weaponClass then
            if oldOwner:HasWeapon(weaponClass) then
                oldOwner:StripWeapon(weaponClass)
            end
            if playerKey then
                oldOwner[playerKey] = nil
            end
        end
        self:SetData("equipped", nil)
    end
end

-- Block transfer while equipped
function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) and self.equipNotifyKey then
            owner:NotifyLocalized(self.equipNotifyKey)
        end
        return false
    end
    return true
end

-- Restore equipped state on character load
function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weaponClass = self.equipWeaponClass
        local playerKey = self.equipPlayerKey

        if not weaponClass or not playerKey then return end

        local weapon = client:Give(weaponClass, true)
        if IsValid(weapon) then
            weapon.wsItem = self
            client[playerKey] = self
        end
    end
end
