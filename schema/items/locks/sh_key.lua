--[[
    Key (Programmed)

    A programmed key that can lock/unlock doors with matching keyings.
    - keying: Single keying ID (e.g., "A5199D")
    - color: Visual tint for identification
    - name: One-time engravable name (cosmetic)

    Controls when equipped:
    - LMB: Lock door (if keying matches)
    - RMB: Unlock door (if keying matches)

    Non-stackable once programmed.
    Drops on knockout when held.
]]--

ITEM.name = "Key"
ITEM.description = "A programmed key."
ITEM.model = "models/props_c17/tools_wrench01a.mdl"  -- Placeholder model
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Keys & Locks"
ITEM.noBusiness = true
ITEM.class = "ix_key"
ITEM.weaponCategory = "key"

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetKeying()
    return self:GetData("keying", "")
end

function ITEM:GetKeyColor()
    return self:GetData("color", Color(200, 200, 200))
end

function ITEM:GetKeyName()
    return self:GetData("keyName", "")
end

function ITEM:HasName()
    local name = self:GetKeyName()
    return name and name ~= ""
end

function ITEM:IsProgrammed()
    local keying = self:GetKeying()
    return keying and keying ~= ""
end

-- Override GetName to show custom name or keying
function ITEM:GetName()
    if self:HasName() then
        return self:GetKeyName()
    end
    local keying = self:GetKeying()
    if keying and keying ~= "" then
        return "Key [" .. keying .. "]"
    end
    return self.name
end

-- Override description to show keying
function ITEM:GetDescription()
    local keying = self:GetKeying()
    if keying and keying ~= "" then
        return "A programmed key with keying: " .. keying
    end
    return self.description
end

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

        -- Draw color indicator strip at bottom
        local keyColor = item:GetData("color")
        if keyColor then
            surface.SetDrawColor(keyColor.r or 200, keyColor.g or 200, keyColor.b or 200, 200)
            surface.DrawRect(4, h - 8, w - 8, 4)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local keying = self:GetKeying()
        if keying and keying ~= "" then
            local keyingRow = tooltip:AddRow("keying")
            keyingRow:SetText("Keying: " .. keying)
            keyingRow:SetBackgroundColor(Color(80, 80, 120))
            keyingRow:SizeToContents()
        end

        local keyName = self:GetKeyName()
        if keyName and keyName ~= "" then
            local nameRow = tooltip:AddRow("keyName")
            nameRow:SetText("Label: " .. keyName)
            nameRow:SetBackgroundColor(Color(60, 100, 60))
            nameRow:SizeToContents()
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Equip key
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the key in your hand.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing key from this player
        if client.ixKeyItem and client.ixKeyItem ~= item then
            local oldItem = client.ixKeyItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing key SWEP if any
        if client:HasWeapon("ix_key") then
            client:StripWeapon("ix_key")
        end

        -- Set these BEFORE Give() so hooks see them
        client.ixKeyItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("ix_key")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_key")
        end

        client:EmitSound("physics/metal/metal_solid_impact_soft2.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        if not item:IsProgrammed() then return false end
        return true
    end
}

-- Unequip key
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the key away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_key") then
            client:StripWeapon("ix_key")
        end

        client.ixKeyItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/metal/metal_solid_impact_soft2.wav", 50, 90)

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
            if client:HasWeapon("ix_key") then
                client:StripWeapon("ix_key")
            end
            client.ixKeyItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_key") then
                oldOwner:StripWeapon("ix_key")
            end
            oldOwner.ixKeyItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("keyEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_key", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixKeyItem = self
        end
    end
end
