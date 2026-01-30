--[[
    Lockpick

    A tool for picking locks on doors.

    Quality Tiers:
    | Quality | Sweet Spot | Attempts | Break Chance |
    |---------|------------|----------|--------------|
    | Crude   | Tiny       | 1        | High         |
    | Regular | Small      | 2-3      | Medium       |
    | Quality | Medium     | 4-5      | Low          |
    | Master  | Large      | 7-8      | Very Low     |

    Each attempt (hit or miss) damages lock 1-5% durability.
    Failed attempt may break lockpick (loud SNAP sound).
    Lock at 0% durability = broken, door permanently unlocked.
]]--

ITEM.name = "Lockpick"
ITEM.description = "A tool for picking locks."
ITEM.model = "models/props_c17/tools_pliers01a.mdl"  -- Placeholder
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Tools"
ITEM.noBusiness = true
ITEM.class = "ix_lockpick"
ITEM.weaponCategory = "lockpick"

-- Quality configurations
ITEM.qualities = {
    crude = {
        name = "Crude",
        sweetSpotSize = 0.08,   -- 8% of bar width
        maxAttempts = 1,
        breakChance = 0.6,      -- 60% chance to break on miss
        requiredHits = 5,       -- Hits needed to unlock
    },
    regular = {
        name = "Regular",
        sweetSpotSize = 0.12,   -- 12% of bar width
        maxAttempts = 3,
        breakChance = 0.35,
        requiredHits = 4,
    },
    quality = {
        name = "Quality",
        sweetSpotSize = 0.18,   -- 18% of bar width
        maxAttempts = 5,
        breakChance = 0.15,
        requiredHits = 3,
    },
    master = {
        name = "Master",
        sweetSpotSize = 0.25,   -- 25% of bar width
        maxAttempts = 8,
        breakChance = 0.05,
        requiredHits = 3,
    }
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetQuality()
    return self:GetData("quality", "regular")
end

function ITEM:GetQualityConfig()
    local quality = self:GetQuality()
    return self.qualities[quality] or self.qualities.regular
end

function ITEM:GetSweetSpotSize()
    return self:GetQualityConfig().sweetSpotSize
end

function ITEM:GetMaxAttempts()
    return self:GetQualityConfig().maxAttempts
end

function ITEM:GetBreakChance()
    return self:GetQualityConfig().breakChance
end

function ITEM:GetRequiredHits()
    return self:GetQualityConfig().requiredHits
end

-- Override GetName to show quality
function ITEM:GetName()
    local config = self:GetQualityConfig()
    return config.name .. " Lockpick"
end

-- Override description
function ITEM:GetDescription()
    local config = self:GetQualityConfig()

    local desc = "A lockpick for bypassing locks."
    desc = desc .. "\n\nQuality: " .. config.name
    desc = desc .. "\nAttempts: " .. config.maxAttempts

    return desc
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

        -- Draw quality indicator color
        local quality = item:GetData("quality", "regular")
        local colors = {
            crude = Color(150, 100, 80),
            regular = Color(150, 150, 150),
            quality = Color(100, 150, 200),
            master = Color(200, 180, 100)
        }

        local color = colors[quality] or colors.regular
        surface.SetDrawColor(color.r, color.g, color.b, 200)
        surface.DrawRect(4, h - 8, w - 8, 4)
    end

    function ITEM:PopulateTooltip(tooltip)
        local config = self:GetQualityConfig()

        local qualityRow = tooltip:AddRow("quality")
        qualityRow:SetText("Quality: " .. config.name)

        local quality = self:GetQuality()
        local colors = {
            crude = Color(150, 80, 60),
            regular = Color(100, 100, 100),
            quality = Color(60, 100, 150),
            master = Color(150, 130, 60)
        }
        qualityRow:SetBackgroundColor(colors[quality] or colors.regular)
        qualityRow:SizeToContents()

        local attemptsRow = tooltip:AddRow("attempts")
        attemptsRow:SetText("Attempts: " .. config.maxAttempts)
        attemptsRow:SetBackgroundColor(Color(60, 60, 80))
        attemptsRow:SizeToContents()
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Equip lockpick
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the lockpick to pick locks.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing lockpick from this player
        if client.ixLockpickItem and client.ixLockpickItem ~= item then
            local oldItem = client.ixLockpickItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing lockpick SWEP if any
        if client:HasWeapon("ix_lockpick") then
            client:StripWeapon("ix_lockpick")
        end

        -- Set these BEFORE Give() so hooks see them
        client.ixLockpickItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("ix_lockpick")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_lockpick")
        end

        client:EmitSound("physics/metal/metal_solid_impact_soft1.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        return true
    end
}

-- Unequip lockpick
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the lockpick away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_lockpick") then
            client:StripWeapon("ix_lockpick")
        end

        client.ixLockpickItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/metal/metal_solid_impact_soft1.wav", 50, 90)

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
            if client:HasWeapon("ix_lockpick") then
                client:StripWeapon("ix_lockpick")
            end
            client.ixLockpickItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_lockpick") then
                oldOwner:StripWeapon("ix_lockpick")
            end
            oldOwner.ixLockpickItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("lockpickEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_lockpick", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixLockpickItem = self
        end
    end
end
