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
ITEM.model = "models/props_c17/tools_pliers01a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Tools"
ITEM.noBusiness = true
ITEM.class = "ix_lockpick"
ITEM.weaponCategory = "lockpick"
ITEM.base = "base_equippable"

-- Equippable configuration
ITEM.equipWeaponClass = "ix_lockpick"
ITEM.equipPlayerKey = "wsLockpickItem"
ITEM.equipNotifyKey = "lockpickEquipped"
ITEM.equipSound = "physics/metal/metal_solid_impact_soft1.wav"
ITEM.equipTip = "Hold the lockpick to pick locks."
ITEM.unequipTip = "Put the lockpick away."

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
        -- Draw equipped indicator (green dot)
        if item:GetData("equipped") then
            ws.constants.DrawEquippedIndicator(w, h)
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

        local quality = self:GetQuality()
        local qualityColors = {
            crude = Color(150, 80, 60),
            regular = Color(100, 100, 100),
            quality = Color(60, 100, 150),
            master = Color(150, 130, 60)
        }
        ws.constants.AddTooltipRow(tooltip, "quality", "Quality: " .. config.name, qualityColors[quality] or qualityColors.regular)
        ws.constants.AddTooltipRow(tooltip, "attempts", "Attempts: " .. config.maxAttempts, Color(60, 60, 80))
    end
end
