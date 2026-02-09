--[[
    Windswept Colony RP - Centralized Constants

    All magic numbers and repeated values in one place.
    Import with: local C = ix.constants (after this file loads)

    NOTE: Helix already defines ix.currency.MAX_STACK (100), ix.currency.CENTS_PER_DOLLAR (100),
    ix.currency.CASH_ITEM ("cash"), ix.currency.COINS_ITEM ("coins")
]]--

ix.constants = ix.constants or {}
local C = ix.constants

-- =============================================================================
-- UI COLORS
-- =============================================================================
-- Anti-metagaming: All UI uses neutral gray regardless of faction
-- See CLAUDE.md "UI is colorblind" design principle

C.COLOR_UI_NEUTRAL = Color(200, 200, 200)       -- Standard text/UI color
C.COLOR_UI_NEUTRAL_ALPHA = Color(200, 200, 200, 200)  -- With transparency
C.COLOR_OUTLINE = Color(0, 0, 0)                -- Text outline color
C.COLOR_PROGRESS_BG = Color(50, 50, 50, 200)    -- Progress bar background
C.COLOR_PROGRESS_FG = Color(200, 200, 200, 255) -- Progress bar foreground

-- =============================================================================
-- INTERACTION RANGES (squared, for use with DistToSqr)
-- =============================================================================
-- DistToSqr is faster than Distance because it skips the sqrt calculation
-- To check if within 100 units: pos1:DistToSqr(pos2) <= RANGE_INTERACTION

C.RANGE_INTERACTION = 100 * 100      -- 10000 - Standard player-to-player (giving items, money)
C.RANGE_INTERACTION_CLOSE = 96 * 96  -- 9216 - Close range (prisoner drag, ziptie)
C.RANGE_DOCUMENT_VIEW = 256 * 256    -- 65536 - Viewing documents (prison card)
C.RANGE_SOUND_FAR = 1000 * 1000      -- 1000000 - Far sound audibility
C.RANGE_EAVESDROP_BASE = 400         -- Base eavesdrop range (scaled by volume * amplitude)

-- Linear distances (for reference/documentation)
C.DISTANCE_INTERACTION = 100         -- units
C.DISTANCE_INTERACTION_CLOSE = 96    -- units
C.DISTANCE_DOCUMENT_VIEW = 256       -- units

-- =============================================================================
-- BATTERY SYSTEM
-- =============================================================================
-- "up" = units of power. A full battery has 100up.
-- Drain rates are up/second when device is active.

C.BATTERY_FULL_CHARGE = 100          -- Full battery in up

-- Drain rates (up per second)
-- Flashlight: 100up / 1200sec = 20 minutes per battery
-- Lantern: 100up / 600sec = 10 minutes per battery
C.DRAIN_FLASHLIGHT = 100 / 1200      -- ~0.083 up/sec
C.DRAIN_LANTERN = 100 / 600          -- ~0.167 up/sec

-- =============================================================================
-- ITEM STACK LIMITS
-- =============================================================================
-- Currency uses ix.currency.MAX_STACK (100) from Helix

C.STACK_KEY_BLANKS = 10
C.STACK_LOCK_BLANKS = 5
C.STACK_MATERIALS = 20               -- Wood planks, metal sheets

-- =============================================================================
-- TIMING (seconds)
-- =============================================================================

C.ITEM_PICKUP_HOLD_TIME = 0.5        -- Helix default for holding E to pickup
C.DOOR_BREACH_COOLDOWN = 2           -- Cooldown between ram hits

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Check if two entities are within interaction range
function C.WithinRange(ent1, ent2, rangeSquared)
    rangeSquared = rangeSquared or C.RANGE_INTERACTION
    return ent1:GetPos():DistToSqr(ent2:GetPos()) <= rangeSquared
end

-- Check if player is within standard interaction range of target
function C.CanInteract(player, target)
    return C.WithinRange(player, target, C.RANGE_INTERACTION)
end

-- Check if player is within close interaction range (prisoner ops)
function C.CanInteractClose(player, target)
    return C.WithinRange(player, target, C.RANGE_INTERACTION_CLOSE)
end
