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
    -- Enable mouse for the Give Up button, but don't use MakePopup() to allow ESC
    self:SetMouseInputEnabled(true)
    -- Show mouse cursor
    gui.EnableScreenClicker(true)

    self.startTime = RealTime()
    self.duration = 300
    self.knockoutNum = 1

    -- Create Give Up button (subtle, at bottom)
    self.giveUpButton = vgui.Create("DButton", self)
    self.giveUpButton:SetText(L("giveUp"))
    self.giveUpButton:SetFont("ixSmallFont")
    self.giveUpButton:SetSize(120, 30)
    self.giveUpButton:SetPos(ScrW() / 2 - 60, ScrH() - 160)
    self.giveUpButton:SetTextColor(Color(150, 150, 150))
    self.giveUpButton.Paint = function(btn, w, h)
        -- Subtle dark button
        surface.SetDrawColor(40, 40, 40, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(80, 80, 80, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    self.giveUpButton.DoClick = function()
        self:ShowGiveUpConfirmation()
    end
end

function PANEL:ShowGiveUpConfirmation()
    -- Don't show if already showing
    if IsValid(self.confirmDialog) then return end

    -- Get text for sizing
    local confirmText = L("giveUpConfirm")
    local yesText = L("giveUpYes")
    local noText = L("giveUpNo")

    -- Calculate button sizes based on text
    surface.SetFont("ixSmallFont")
    local yesW = surface.GetTextSize(yesText) + 20  -- padding
    local noW = surface.GetTextSize(noText) + 20

    -- Calculate dialog width based on buttons
    local buttonPadding = 20
    local dialogWidth = math.max(350, yesW + noW + buttonPadding * 3)

    -- Create confirmation dialog (positioned below center so timer is visible)
    self.confirmDialog = vgui.Create("DPanel", self)
    self.confirmDialog:SetSize(dialogWidth, 120)
    self.confirmDialog:SetPos(ScrW() / 2 - dialogWidth / 2, ScrH() / 2 + 80)
    self.confirmDialog.Paint = function(pnl, w, h)
        surface.SetDrawColor(20, 20, 20, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(100, 100, 100, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    -- Confirmation text
    local label = vgui.Create("DLabel", self.confirmDialog)
    label:SetText(confirmText)
    label:SetFont("ixMediumFont")
    label:SetTextColor(Color(200, 200, 200))
    label:SizeToContents()
    label:SetPos(dialogWidth / 2 - label:GetWide() / 2, 20)

    -- Yes button
    local yesBtn = vgui.Create("DButton", self.confirmDialog)
    yesBtn:SetText(yesText)
    yesBtn:SetFont("ixSmallFont")
    yesBtn:SetSize(yesW, 30)
    yesBtn:SetPos(buttonPadding, 70)
    yesBtn:SetTextColor(Color(200, 100, 100))
    yesBtn.Paint = function(btn, w, h)
        surface.SetDrawColor(60, 30, 30, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(120, 60, 60, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    yesBtn.DoClick = function()
        print("[Permadeath] Client sending ixKnockoutGiveUp")
        -- Send give up request to server
        net.Start("ixKnockoutGiveUp")
        net.SendToServer()

        -- Hide the Give Up button (can't give up twice)
        if IsValid(self.giveUpButton) then
            self.giveUpButton:Remove()
        end

        -- Close dialog
        if IsValid(self.confirmDialog) then
            self.confirmDialog:Remove()
            self.confirmDialog = nil
        end
    end

    -- No button
    local noBtn = vgui.Create("DButton", self.confirmDialog)
    noBtn:SetText(noText)
    noBtn:SetFont("ixSmallFont")
    noBtn:SetSize(noW, 30)
    noBtn:SetPos(dialogWidth - noW - buttonPadding, 70)
    noBtn:SetTextColor(Color(150, 150, 150))
    noBtn.Paint = function(btn, w, h)
        surface.SetDrawColor(40, 40, 40, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(80, 80, 80, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    noBtn.DoClick = function()
        -- Close dialog
        if IsValid(self.confirmDialog) then
            self.confirmDialog:Remove()
            self.confirmDialog = nil
        end
    end
end

function PANEL:OnRemove()
    -- Hide mouse cursor
    gui.EnableScreenClicker(false)
    -- Clean up confirmation dialog if open
    if IsValid(self.confirmDialog) then
        self.confirmDialog:Remove()
        self.confirmDialog = nil
    end
end

function PANEL:SetKnockoutData(duration, knockoutNum)
    self.duration = duration
    self.knockoutNum = knockoutNum
    self.startTime = RealTime()
end

function PANEL:SyncTimer(newDuration)
    -- Timer was halved from damage - sync it
    self.duration = newDuration
    self.startTime = RealTime()
end

function PANEL:GetRemainingTime()
    local elapsed = RealTime() - self.startTime
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
    knockoutStartTime = RealTime()
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
    knockoutStartTime = RealTime()

    -- Sync the panel if it exists
    if IsValid(knockoutPanel) then
        knockoutPanel:SyncTimer(newDuration)
    end
end)

-- Force cleanup of all knockout UI state
local function CleanupKnockoutUI()
    isKnockedOut = false
    knockoutStartTime = 0
    knockoutDuration = 0
    knockoutCount = 0

    if IsValid(knockoutPanel) then
        print("[Permadeath] Cleaning up knockout panel")
        knockoutPanel:Remove()
        knockoutPanel = nil
    end

    -- Re-enable screen clicker in case it was left on
    gui.EnableScreenClicker(false)
end

net.Receive("ixKnockoutEnd", function()
    print("[Permadeath] Client received ixKnockoutEnd")

    local revived = net.ReadBool()
    local health = net.ReadUInt(8)

    print("[Permadeath] Revived: " .. tostring(revived) .. ", Health: " .. health)

    -- Force cleanup all knockout state
    CleanupKnockoutUI()

    -- Show appropriate notification
    if revived then
        ix.util.Notify(L("revivalSuccess"))
        ix.util.Notify(string.format("You regained consciousness with %d HP.", health))
    else
        print("[Permadeath] Character permadead, showing notification")
        ix.util.Notify(L("characterPermadead"))
    end
end)

-- Clean up knockout UI when character is kicked/unloaded
function PLUGIN:CharacterLoaded(character)
    -- Clean up any leftover knockout UI from previous character
    CleanupKnockoutUI()
end

-- Also clean up when player spawns (covers edge cases)
function PLUGIN:PlayerSpawn(client)
    if client == LocalPlayer() then
        CleanupKnockoutUI()
    end
end

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
        local elapsed = RealTime() - knockoutStartTime
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
