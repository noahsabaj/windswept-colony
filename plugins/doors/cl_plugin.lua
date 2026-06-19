--[[
    Windswept Doors Plugin - Client

    Client-side door rendering and UI.
]]--

local PLUGIN = PLUGIN

-- ============================================================================
-- 3D2D DOOR INFO (Override Helix default)
-- ============================================================================

-- Disable Helix's default door info rendering
hook.Add("PostDrawTranslucentRenderables", "wsWindsweptDoorInfo", function(_, bSkybox)
    if bSkybox then return end

    local client = LocalPlayer()
    local data = {}
        data.start = client:GetShootPos()
        data.endpos = data.start + client:GetAimVector() * 128
        data.filter = client
    local entity = util.TraceLine(data).Entity

    if not IsValid(entity) then return end

    -- Only draw for our managed doors (prop_door_rotating with wsIsWindsweptDoor marker)
    if not entity.wsIsWindsweptDoor then return end

    -- Managed doors use native prop_door_rotating rendering
end)

-- ============================================================================
-- EMPTY FRAME VISUALIZATION
-- ============================================================================

-- Pulsating effect for empty frames when holding door item
local framePulseAlpha = 0
local framePulseDir = 1

hook.Add("PostDrawTranslucentRenderables", "wsWindsweptFramePulse", function(_, bSkybox)
    if bSkybox then return end

    local client = LocalPlayer()
    local weapon = client:GetActiveWeapon()

    -- Only show when holding door SWEP
    if not IsValid(weapon) or weapon:GetClass() ~= "ix_door" then return end

    -- Animate pulse
    framePulseAlpha = framePulseAlpha + framePulseDir * FrameTime() * 200
    if framePulseAlpha > 150 then
        framePulseAlpha = 150
        framePulseDir = -1
    elseif framePulseAlpha < 50 then
        framePulseAlpha = 50
        framePulseDir = 1
    end

    -- We'd need frame positions synced from server
    -- For now, just highlight nearby entities that look like door frames
    -- Real implementation would use networked frame data

    -- Draw instruction text on screen
    local scrW, scrH = ScrW(), ScrH()
    draw.SimpleText("Point at an empty door frame and press RMB to install", "wsSmallFont",
        scrW / 2, scrH * 0.8, Color(200, 200, 200, framePulseAlpha), TEXT_ALIGN_CENTER)
end)

-- ============================================================================
-- KEYBIND HINTS
-- ============================================================================

hook.Add("HUDPaint", "wsWindsweptDoorHints", function()
    local client = LocalPlayer()
    local weapon = client:GetActiveWeapon()

    if not IsValid(weapon) then return end

    local weaponClass = weapon:GetClass()
    local hints = {}

    if weaponClass == "ix_key" then
        hints = {"LMB: Lock door", "RMB: Unlock door"}
    elseif weaponClass == "ix_keyring" then
        hints = {"R: Cycle keys", "LMB: Lock", "RMB: Unlock"}
    elseif weaponClass == "ix_lock" then
        hints = {"RMB on door: Install lock"}
    elseif weaponClass == "ix_door" then
        hints = {"RMB on frame: Install door"}
    elseif weaponClass == "ix_toolkit" then
        hints = {"RMB on door/lock: Remove", "LMB: Repair"}
    elseif weaponClass == "ix_lockpick" then
        hints = {"RMB on locked door: Pick lock"}
    elseif weaponClass == "ix_lockbreaker" then
        hints = {"RMB on lock: Destroy lock"}
    end

    if #hints == 0 then return end

    -- Draw hints in bottom right
    local scrW, scrH = ScrW(), ScrH()
    local y = scrH - 100

    for i, hint in ipairs(hints) do
        draw.SimpleText(hint, "wsSmallFont", scrW - 20, y, Color(200, 200, 200, 200), TEXT_ALIGN_RIGHT)
        y = y + 30
    end
end)

-- ============================================================================
-- DOOR MENU OVERRIDE
-- ============================================================================

-- Prevent Helix's door menu from opening
hook.Add("ShowHelp", "wsWindsweptDoorMenu", function()
    local client = LocalPlayer()
    local data = {}
        data.start = client:GetShootPos()
        data.endpos = data.start + client:GetAimVector() * 128
        data.filter = client
    local entity = util.TraceLine(data).Entity

    -- If looking at a managed door or hidden map door, don't show Helix menu
    if IsValid(entity) then
        if entity.wsIsWindsweptDoor then
            return true  -- Block Helix menu for our managed doors
        end

        if entity:IsDoor() and entity:GetNoDraw() then
            return true  -- Block Helix menu for hidden doors
        end
    end
end)
