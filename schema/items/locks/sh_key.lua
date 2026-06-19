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
ITEM.model = "models/props_c17/tools_wrench01a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Keys & Locks"
ITEM.noBusiness = true
ITEM.class = "ix_key"
ITEM.weaponCategory = "key"
ITEM.base = "base_equippable"

-- Equippable configuration
ITEM.equipWeaponClass = "ix_key"
ITEM.equipPlayerKey = "wsKeyItem"
ITEM.equipNotifyKey = "keyEquipped"
ITEM.equipSound = "physics/metal/metal_solid_impact_soft2.wav"
ITEM.equipSoundVolume = 0.5
ITEM.unequipSoundVolume = 0.4
ITEM.equipTip = "Hold the key in your hand."
ITEM.unequipTip = "Put the key away."

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

-- Additional equip check: must be programmed
function ITEM:CanEquip()
    return self:IsProgrammed()
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
        -- Draw equipped indicator (green dot)
        if item:GetData("equipped") then
            ws.constants.DrawEquippedIndicator(w, h)
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
            ws.constants.AddTooltipRow(tooltip, "keying", "Keying: " .. keying, Color(80, 80, 120))
        end

        local keyName = self:GetKeyName()
        if keyName and keyName ~= "" then
            ws.constants.AddTooltipRow(tooltip, "keyName", "Label: " .. keyName, Color(60, 100, 60))
        end
    end
end
