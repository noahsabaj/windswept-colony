--[[
    Permadeath Plugin - Client Logic

    Handles knockout UI (black screen with timer),
    communication blocking, and audio effects.
]]--

print("[Permadeath] cl_plugin.lua is loading...")

-- Knockout state
local isKnockedOut = false
local knockoutStartTime = 0
local knockoutDuration = 0
local knockoutCount = 0

-- ============================================================================
-- KNOCKOUT SCREEN PANEL
-- ============================================================================

local PANEL = {}

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)

    self.startTime = CurTime()
    self.duration = 300
    self.knockoutNum = 1
end

function PANEL:SetKnockoutData(duration, knockoutNum)
    self.duration = duration
    self.knockoutNum = knockoutNum
    self.startTime = CurTime()
end

function PANEL:SyncTimer(newDuration)
    -- Timer was halved from damage - sync it
    self.duration = newDuration
    self.startTime = CurTime()
end

function PANEL:GetRemainingTime()
    local elapsed = CurTime() - self.startTime
    return math.max(0, self.duration - elapsed)
end

function PANEL:Paint(w, h)
    -- Full black background
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(0, 0, w, h)

    -- Calculate remaining time
    local remaining = self:GetRemainingTime()
    local minutes = math.floor(remaining / 60)
    local seconds = math.floor(remaining % 60)
    local timeText = string.format("%02d:%02d", minutes, seconds)

    -- Draw centered timer
    surface.SetFont("ixMenuButtonHugeFont")
    local tw, th = surface.GetTextSize(timeText)
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
    surface.DrawText(timeText)

    -- Draw knockout count below timer
    local countText = string.format("KNOCKOUT #%d", self.knockoutNum)
    surface.SetFont("ixMediumFont")
    local cw, ch = surface.GetTextSize(countText)
    surface.SetTextColor(150, 150, 150, 255)
    surface.SetTextPos(w / 2 - cw / 2, h / 2 + th / 2 + 20)
    surface.DrawText(countText)

    -- Draw instruction at bottom
    local instructionText = "You are knocked out. Wait for rescue or death."
    surface.SetFont("ixSmallFont")
    local iw, ih = surface.GetTextSize(instructionText)
    surface.SetTextColor(100, 100, 100, 255)
    surface.SetTextPos(w / 2 - iw / 2, h - 100)
    surface.DrawText(instructionText)
end

function PANEL:Think()
    -- Keep panel on top
    self:MoveToFront()

    -- Check if timer expired (server will handle permadeath)
    if self:GetRemainingTime() <= 0 then
        -- Timer expired - wait for server to send ixKnockoutEnd
    end
end

function PANEL:OnKeyCodePressed(key)
    -- Block all key input
    return true
end

function PANEL:OnMousePressed(mouseCode)
    -- Block mouse input
    return true
end

vgui.Register("ixKnockoutScreen", PANEL, "DPanel")

-- ============================================================================
-- NETWORK RECEIVERS
-- ============================================================================

local knockoutPanel = nil

net.Receive("ixKnockoutStart", function()
    print("[Permadeath] Client received ixKnockoutStart!")

    local duration = net.ReadFloat()
    local count = net.ReadUInt(8)

    print("[Permadeath] Duration: " .. duration .. ", Count: " .. count)

    isKnockedOut = true
    knockoutStartTime = CurTime()
    knockoutDuration = duration
    knockoutCount = count

    -- Remove existing panel if any
    if IsValid(knockoutPanel) then
        knockoutPanel:Remove()
    end

    -- Create knockout screen
    knockoutPanel = vgui.Create("ixKnockoutScreen")
    if IsValid(knockoutPanel) then
        knockoutPanel:SetKnockoutData(duration, count)
        print("[Permadeath] Knockout panel created successfully")
    else
        print("[Permadeath] ERROR: Failed to create knockout panel!")
    end
end)

net.Receive("ixKnockoutTimerSync", function()
    local newDuration = net.ReadFloat()

    knockoutDuration = newDuration
    knockoutStartTime = CurTime()

    -- Sync the panel if it exists
    if IsValid(knockoutPanel) then
        knockoutPanel:SyncTimer(newDuration)
    end
end)

net.Receive("ixKnockoutEnd", function()
    local revived = net.ReadBool()
    local health = net.ReadUInt(8)

    isKnockedOut = false

    -- Remove the knockout screen
    if IsValid(knockoutPanel) then
        knockoutPanel:Remove()
        knockoutPanel = nil
    end

    -- Show appropriate notification
    if revived then
        ix.util.Notify(L("revivalSuccess"))
        ix.util.Notify(string.format("You regained consciousness with %d HP.", health))
    else
        ix.util.Notify(L("characterPermadead"))
    end
end)

-- ============================================================================
-- COMMUNICATION BLOCKING
-- ============================================================================

-- Block chat while knocked out
function PLUGIN:CanPlayerChat(client, text)
    if isKnockedOut then
        return false
    end
end

-- Block voice while knocked out
function PLUGIN:PlayerStartVoice(client)
    if client == LocalPlayer() and isKnockedOut then
        return false
    end
end

-- Hide chat messages while knocked out (optional - creates isolation)
function PLUGIN:ChatboxShouldShowMessage(data)
    if isKnockedOut then
        return false
    end
end

-- ============================================================================
-- VIEW / RENDERING OVERRIDES
-- ============================================================================

-- Override the view to prevent death camera from showing
function PLUGIN:CalcView(client, pos, angles, fov)
    if isKnockedOut then
        -- Return a view that shows nothing (underground)
        return {
            origin = Vector(0, 0, -10000),
            angles = Angle(0, 0, 0),
            fov = 1,  -- Minimal FOV
            drawviewer = false
        }
    end
end

-- Force black screen even if panel fails
function PLUGIN:HUDPaint()
    if isKnockedOut and not IsValid(knockoutPanel) then
        -- Fallback black screen
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, ScrW(), ScrH())

        -- Draw timer
        local elapsed = CurTime() - knockoutStartTime
        local remaining = math.max(0, knockoutDuration - elapsed)
        local minutes = math.floor(remaining / 60)
        local seconds = math.floor(remaining % 60)
        local timeText = string.format("%02d:%02d", minutes, seconds)

        surface.SetFont("ixMenuButtonHugeFont")
        local tw, th = surface.GetTextSize(timeText)
        surface.SetTextColor(255, 255, 255, 255)
        surface.SetTextPos(ScrW() / 2 - tw / 2, ScrH() / 2 - th / 2)
        surface.DrawText(timeText)
    end
end

-- Block HUD elements while knocked out
function PLUGIN:HUDShouldDraw(element)
    if isKnockedOut then
        return false
    end
end

-- Block scoreboard while knocked out
function PLUGIN:ScoreboardShow()
    if isKnockedOut then
        return false
    end
end

-- Block context menu while knocked out
function PLUGIN:ContextMenuOpen()
    if isKnockedOut then
        return false
    end
end

-- ============================================================================
-- INPUT BLOCKING
-- ============================================================================

-- Block movement commands
function PLUGIN:StartCommand(client, cmd)
    if client == LocalPlayer() and isKnockedOut then
        cmd:ClearButtons()
        cmd:ClearMovement()
    end
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Expose knockout state for other systems
function PLUGIN:IsLocalPlayerKnockedOut()
    return isKnockedOut
end

print("[Permadeath] cl_plugin.lua finished loading")
