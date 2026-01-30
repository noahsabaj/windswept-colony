--[[
    Lock (Programmed)

    A programmed lock that can be installed on doors.
    - keyings: List of accepted keying IDs (max 3)
    - durability: 0-100%, damaged by lockpicking
    - name: One-time engravable name (cosmetic)

    Controls when equipped:
    - RMB while looking at door: Install lock (requires toolkit in inventory)

    Non-stackable once programmed.
    Destroyed if door is destroyed.
]]--

ITEM.name = "Lock"
ITEM.description = "A programmed lock."
ITEM.model = "models/props_c17/tools_pliers01a.mdl"  -- Placeholder model
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Keys & Locks"
ITEM.noBusiness = true
ITEM.class = "ix_lock"
ITEM.weaponCategory = "lock"

-- Maximum keyings a lock can accept
ITEM.maxKeyings = 3

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetKeyings()
    return self:GetData("keyings", {})
end

function ITEM:GetDurability()
    return self:GetData("durability", 100)
end

function ITEM:GetLockName()
    return self:GetData("lockName", "")
end

function ITEM:HasName()
    local name = self:GetLockName()
    return name and name ~= ""
end

function ITEM:IsProgrammed()
    local keyings = self:GetKeyings()
    return keyings and #keyings > 0
end

function ITEM:CanAddKeying()
    local keyings = self:GetKeyings()
    return #keyings < self.maxKeyings
end

-- Override GetName to show custom name or keying info
function ITEM:GetName()
    if self:HasName() then
        return self:GetLockName()
    end
    local keyings = self:GetKeyings()
    if keyings and #keyings > 0 then
        return "Lock [" .. #keyings .. " keying" .. (#keyings > 1 and "s" or "") .. "]"
    end
    return self.name
end

-- Override description to show durability
function ITEM:GetDescription()
    local durability = self:GetDurability()
    local keyings = self:GetKeyings()

    local desc = "A programmed lock."
    if keyings and #keyings > 0 then
        desc = desc .. "\nKeyings: " .. #keyings .. "/" .. self.maxKeyings
    end
    desc = desc .. "\nDurability: " .. math.floor(durability) .. "%"

    return desc
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local isEquipped = item:GetData("equipped")
        local durability = item:GetData("durability", 100)

        -- Draw equipped indicator (green dot)
        if isEquipped then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end

        -- Draw durability bar
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(4, h - 12, w - 8, 8)

        local durWidth = ((w - 8) / 100) * durability
        local color
        if durability >= 75 then
            color = Color(50, 200, 50)
        elseif durability >= 50 then
            color = Color(200, 200, 50)
        elseif durability >= 25 then
            color = Color(255, 150, 50)
        else
            color = Color(200, 50, 50)
        end

        surface.SetDrawColor(color)
        surface.DrawRect(4, h - 12, durWidth, 8)
    end

    function ITEM:PopulateTooltip(tooltip)
        local keyings = self:GetKeyings()
        local durability = self:GetDurability()

        -- Keying count
        local keyingRow = tooltip:AddRow("keyings")
        keyingRow:SetText("Keyings: " .. #keyings .. "/" .. self.maxKeyings)
        keyingRow:SetBackgroundColor(Color(80, 80, 120))
        keyingRow:SizeToContents()

        -- Durability
        local durRow = tooltip:AddRow("durability")
        durRow:SetText("Durability: " .. math.floor(durability) .. "%")

        if durability >= 75 then
            durRow:SetBackgroundColor(Color(50, 100, 50))
        elseif durability >= 50 then
            durRow:SetBackgroundColor(Color(100, 100, 50))
        elseif durability >= 25 then
            durRow:SetBackgroundColor(Color(150, 100, 50))
        else
            durRow:SetBackgroundColor(Color(150, 50, 50))
        end

        durRow:SizeToContents()

        -- Lock name
        local lockName = self:GetLockName()
        if lockName and lockName ~= "" then
            local nameRow = tooltip:AddRow("lockName")
            nameRow:SetText("Label: " .. lockName)
            nameRow:SetBackgroundColor(Color(60, 100, 60))
            nameRow:SizeToContents()
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Equip lock (to install on doors)
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the lock to install it on a door.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing lock from this player
        if client.ixLockItem and client.ixLockItem ~= item then
            local oldItem = client.ixLockItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing lock SWEP if any
        if client:HasWeapon("ix_lock") then
            client:StripWeapon("ix_lock")
        end

        -- Set these BEFORE Give() so hooks see them
        client.ixLockItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("ix_lock")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_lock")
        end

        client:EmitSound("physics/metal/metal_solid_impact_soft3.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        if not item:IsProgrammed() then return false end
        return true
    end
}

-- Unequip lock
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the lock away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_lock") then
            client:StripWeapon("ix_lock")
        end

        client.ixLockItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/metal/metal_solid_impact_soft3.wav", 50, 90)

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
            if client:HasWeapon("ix_lock") then
                client:StripWeapon("ix_lock")
            end
            client.ixLockItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_lock") then
                oldOwner:StripWeapon("ix_lock")
            end
            oldOwner.ixLockItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("lockEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_lock", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixLockItem = self
        end
    end
end
