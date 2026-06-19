--[[
    Base Door Item

    A door that can be installed in empty door frames.
    - health: Current HP, persists
    - lockData: Installed lock data (if any)

    Controls when equipped:
    - RMB on empty frame: Install door (requires toolkit in inventory)

    Door types derive from this base:
    - Wood Door: 100 HP, low ram resistance
    - Metal Door: 250 HP, high ram resistance
    - Metal Gate: 175 HP, medium ram resistance
]]--

ITEM.name = "Door"
ITEM.description = "A door."
ITEM.model = "models/props_c17/door01_left.mdl"
ITEM.width = 4
ITEM.height = 4
ITEM.category = "Doors"
ITEM.noBusiness = true
ITEM.class = "ix_door"
ITEM.weaponCategory = "door"

-- Door type stats (override in derived items)
ITEM.doorType = "wood"
ITEM.maxHealth = 100
ITEM.ramResistance = 1  -- Multiplier for battering ram damage (lower = more resistant)

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetHealth()
    return self:GetData("health", self.maxHealth)
end

function ITEM:SetHealth(health)
    self:SetData("health", math.Clamp(health, 0, self.maxHealth))
end

function ITEM:GetLockData()
    return self:GetData("lockData", nil)
end

function ITEM:SetLockData(lockData)
    self:SetData("lockData", lockData)
end

function ITEM:HasLock()
    return self:GetLockData() ~= nil
end

function ITEM:GetHealthPercent()
    return (self:GetHealth() / self.maxHealth) * 100
end

function ITEM:GetConditionText()
    local percent = self:GetHealthPercent()
    local text
    if percent >= 76 then text = "Intact"
    elseif percent >= 51 then text = "Minor Damage"
    elseif percent >= 26 then text = "Moderate Damage"
    else text = "Severe Damage" end

    return text, ws.constants.GetChargeColor(percent, 76, 51, 26)
end

-- Override description to show health
function ITEM:GetDescription()
    local health = self:GetHealth()
    local condition, _ = self:GetConditionText()

    local desc = self.description
    desc = desc .. "\n\nHealth: " .. health .. "/" .. self.maxHealth .. " (" .. condition .. ")"

    if self:HasLock() then
        local lockData = self:GetLockData()
        desc = desc .. "\nLock installed: " .. (lockData.name ~= "" and lockData.name or "Unnamed")
    end

    return desc
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local isEquipped = item:GetData("equipped")
        local health = item:GetData("health", item.maxHealth)
        local healthPercent = (health / item.maxHealth) * 100

        -- Draw equipped indicator (green dot)
        if isEquipped then
            ws.constants.DrawEquippedIndicator(w, h)
        end

        -- Draw health bar at bottom
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(4, h - 12, w - 8, 8)

        local healthWidth = ((w - 8) / 100) * healthPercent
        surface.SetDrawColor(ws.constants.GetChargeColor(healthPercent, 76, 51, 26))
        surface.DrawRect(4, h - 12, healthWidth, 8)

        -- Draw lock indicator if has lock
        if item:GetData("lockData") then
            surface.SetDrawColor(100, 100, 200, 200)
            surface.DrawRect(4, 4, 12, 12)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local health = self:GetHealth()
        local condition, condColor = self:GetConditionText()

        -- Health row
        ws.constants.AddTooltipRow(tooltip, "health", "Health: " .. health .. "/" .. self.maxHealth, condColor)

        -- Condition row
        ws.constants.AddTooltipRow(tooltip, "condition", "Condition: " .. condition, Color(60, 60, 60))

        -- Lock info
        if self:HasLock() then
            local lockData = self:GetLockData()
            local lockName = lockData.name ~= "" and lockData.name or "Unnamed Lock"
            ws.constants.AddTooltipRow(tooltip, "lock", "Lock: " .. lockName .. " (" .. math.floor(lockData.durability or 100) .. "% dur.)", Color(80, 80, 120))
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Equip door (to install in frames)
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the door to install it in a frame.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing door from this player
        if client.wsDoorItem and client.wsDoorItem ~= item then
            local oldItem = client.wsDoorItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing door SWEP if any
        if client:HasWeapon("ix_door") then
            client:StripWeapon("ix_door")
        end

        -- Set these BEFORE Give() so hooks see them
        client.wsDoorItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("ix_door")
        if IsValid(weapon) then
            weapon.wsItem = item
            client:SelectWeapon("ix_door")
        end

        client:EmitSound("physics/wood/wood_plank_impact_hard3.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        return true
    end
}

-- Unequip door
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the door away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_door") then
            client:StripWeapon("ix_door")
        end

        client.wsDoorItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/wood/wood_plank_impact_soft2.wav", 50)

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
            if client:HasWeapon("ix_door") then
                client:StripWeapon("ix_door")
            end
            client.wsDoorItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_door") then
                oldOwner:StripWeapon("ix_door")
            end
            oldOwner.wsDoorItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("doorEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_door", true)
        if IsValid(weapon) then
            weapon.wsItem = self
            client.wsDoorItem = self
        end
    end
end
