--[[
    Windswept Doors (Colony bridge) - Client

    Colony door SWEP UI: the install prompt and per-weapon keybind hints. The in-world
    empty-frame pulse is drawn by the framework door plugin (gated on the install tool
    this bridge registers via ws.doors.installToolClass).
]]--

-- ============================================================================
-- INSTALL PROMPT
-- ============================================================================

local framePulseAlpha = 0
local framePulseDir = 1

hook.Add("HUDPaint", "wsWindsweptDoorInstallPrompt", function()
    local client = LocalPlayer()
    local weapon = client:GetActiveWeapon()

    -- Only while holding the door install SWEP
    if not IsValid(weapon) or weapon:GetClass() ~= "ws_door" then return end

    -- Animate the prompt's alpha
    framePulseAlpha = framePulseAlpha + framePulseDir * FrameTime() * 200
    if framePulseAlpha > 150 then
        framePulseAlpha = 150
        framePulseDir = -1
    elseif framePulseAlpha < 50 then
        framePulseAlpha = 50
        framePulseDir = 1
    end

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

    if weaponClass == "ws_key" then
        hints = {"LMB: Lock door", "RMB: Unlock door"}
    elseif weaponClass == "ws_keyring" then
        hints = {"R: Cycle keys", "LMB: Lock", "RMB: Unlock"}
    elseif weaponClass == "ws_lock" then
        hints = {"RMB on door: Install lock"}
    elseif weaponClass == "ws_door" then
        hints = {"RMB on frame: Install door"}
    elseif weaponClass == "ws_toolkit" then
        hints = {"RMB on door/lock: Remove", "LMB: Repair"}
    elseif weaponClass == "ws_lockpick" then
        hints = {"RMB on locked door: Pick lock"}
    elseif weaponClass == "ws_lockbreaker" then
        hints = {"RMB on lock: Destroy lock"}
    end

    if #hints == 0 then return end

    -- Draw hints in bottom right
    local scrW, scrH = ScrW(), ScrH()
    local y = scrH - 100

    for _, hint in ipairs(hints) do
        draw.SimpleText(hint, "wsSmallFont", scrW - 20, y, Color(200, 200, 200, 200), TEXT_ALIGN_RIGHT)
        y = y + 30
    end
end)
