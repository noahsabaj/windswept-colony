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
ITEM.model = "models/props_c17/tools_pliers01a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Keys & Locks"
ITEM.noBusiness = true
ITEM.class = "ix_lock"
ITEM.weaponCategory = "lock"
ITEM.base = "base_equippable"

-- Equippable configuration
ITEM.equipWeaponClass = "ix_lock"
ITEM.equipPlayerKey = "ixLockItem"
ITEM.equipNotifyKey = "lockEquipped"
ITEM.equipSound = "physics/metal/metal_solid_impact_soft3.wav"
ITEM.equipSoundVolume = 0.5
ITEM.unequipSoundVolume = 0.4
ITEM.equipTip = "Hold the lock to install it on a door."
ITEM.unequipTip = "Put the lock away."

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

-- Additional equip check: must be programmed
function ITEM:CanEquip()
    return self:IsProgrammed()
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
        local durability = item:GetData("durability", 100)

        -- Draw equipped indicator (green dot)
        if item:GetData("equipped") then
            ix.constants.DrawEquippedIndicator(w, h)
        end

        -- Draw durability bar
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(4, h - 12, w - 8, 8)

        local durWidth = ((w - 8) / 100) * durability
        surface.SetDrawColor(ix.constants.GetChargeColor(durability, 75, 50, 25))
        surface.DrawRect(4, h - 12, durWidth, 8)
    end

    function ITEM:PopulateTooltip(tooltip)
        local keyings = self:GetKeyings()
        local durability = self:GetDurability()

        -- Keying count
        ix.constants.AddTooltipRow(tooltip, "keyings", "Keyings: " .. #keyings .. "/" .. self.maxKeyings, Color(80, 80, 120))

        -- Durability
        ix.constants.AddTooltipRow(tooltip, "durability", "Durability: " .. math.floor(durability) .. "%", ix.constants.GetChargeColorDark(durability, 75, 50, 25))

        -- Lock name
        local lockName = self:GetLockName()
        if lockName and lockName ~= "" then
            ix.constants.AddTooltipRow(tooltip, "lockName", "Label: " .. lockName, Color(60, 100, 60))
        end
    end
end
