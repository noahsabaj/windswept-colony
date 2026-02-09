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

-- Find best toolkit in a player's inventory (returns hasToolkit, toolkitItem)
function C.FindBestToolkit(client)
    if not IsValid(client) then return false, nil end

    local character, inventory = C.GetCharacterInventory(client)
    if not character or not inventory then return false, nil end

    local bestToolkit = nil
    local bestSpeed = 0

    for _, item in pairs(inventory:GetItems()) do
        if item.uniqueID and string.find(item.uniqueID, "toolkit") then
            local speed = item.installSpeed or 1
            if speed > bestSpeed then
                bestSpeed = speed
                bestToolkit = item
            end
        end
    end

    return bestToolkit ~= nil, bestToolkit
end

-- Draw green equipped indicator dot on inventory icon (CLIENT only)
if CLIENT then
    function C.DrawEquippedIndicator(w, h)
        surface.SetDrawColor(110, 255, 110, 200)
        surface.DrawRect(w - 14, h - 14, 8, 8)
    end

    -- Draw a durability/resource bar on an inventory icon
    -- style: "thick" (8px, lock/toolkit) or "thin" (3px, eraser/writer)
    function C.DrawDurabilityBar(w, h, percent, color, style)
        local barW, barH, barX, barY, bgColor
        if style == "thin" then
            barW, barH, barX, barY = w - 4, 3, 2, h - 5
            bgColor = Color(50, 50, 50, 200)
        else
            barW, barH, barX, barY = w - 8, 8, 4, h - 12
            bgColor = Color(30, 30, 30, 200)
        end

        surface.SetDrawColor(bgColor)
        surface.DrawRect(barX, barY, barW, barH)

        if percent > 0 then
            surface.SetDrawColor(color)
            surface.DrawRect(barX, barY, barW * math.min(percent, 1), barH)
        end
    end

    -- Get bright status color for PaintOver bars (charge, durability, health)
    -- Thresholds default to battery levels (50/25/10); pass custom for durability (75/50/25)
    function C.GetChargeColor(percent, t1, t2, t3)
        if percent >= (t1 or 50) then return Color(50, 200, 50)
        elseif percent >= (t2 or 25) then return Color(200, 200, 50)
        elseif percent >= (t3 or 10) then return Color(255, 150, 50)
        elseif percent >= 1 then return Color(200, 50, 50)
        else return Color(30, 30, 30) end
    end

    -- Add a tooltip row with text and background color (reduces 4-line boilerplate to 1)
    function C.AddTooltipRow(tooltip, key, text, bgColor)
        local row = tooltip:AddRow(key)
        row:SetText(text)
        row:SetBackgroundColor(bgColor)
        row:SizeToContents()
        return row
    end

    -- Draw a world model attached to the owner's right hand bone
    -- offsets: {forward, right, up}, rotations: {{"Axis", degrees}, ...}
    function C.DrawWorldModelBone(weapon, offsets, rotations, modelScale)
        local owner = weapon:GetOwner()
        if not IsValid(owner) then
            weapon:DrawModel()
            return
        end

        local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        if not bone then
            weapon:DrawModel()
            return
        end

        local matrix = owner:GetBoneMatrix(bone)
        if not matrix then
            weapon:DrawModel()
            return
        end

        local pos = matrix:GetTranslation()
        local ang = matrix:GetAngles()

        pos = pos + ang:Forward() * offsets[1] + ang:Right() * offsets[2] + ang:Up() * offsets[3]

        for _, rot in ipairs(rotations) do
            ang:RotateAroundAxis(ang[rot[1]](ang), rot[2])
        end

        weapon:SetRenderOrigin(pos)
        weapon:SetRenderAngles(ang)
        if modelScale then
            weapon:SetModelScale(1, 0)
        end
        weapon:DrawModel()
    end

    -- Get dark status color for PopulateTooltip backgrounds
    function C.GetChargeColorDark(percent, t1, t2, t3)
        if percent >= (t1 or 50) then return Color(50, 100, 50)
        elseif percent >= (t2 or 25) then return Color(100, 100, 50)
        elseif percent >= (t3 or 10) then return Color(150, 100, 50)
        elseif percent >= 1 then return Color(150, 50, 50)
        else return Color(60, 60, 60) end
    end
end

if CLIENT then
    -- Draw a centered HUD progress bar (for SWEP action progress)
    -- label: text above bar, progress: 0-1, fillColor: Color
    -- cancelText: optional hint below bar, labelColor: optional (default white)
    function C.DrawProgressBar(label, progress, fillColor, cancelText, labelColor)
        local w, h = ScrW(), ScrH()
        local barW, barH = 200, 20
        local x, y = (w - barW) / 2, h * 0.6

        -- Background
        surface.SetDrawColor(30, 30, 30, 200)
        surface.DrawRect(x, y, barW, barH)

        -- Progress fill
        surface.SetDrawColor(fillColor)
        surface.DrawRect(x + 2, y + 2, (barW - 4) * progress, barH - 4)

        -- Border
        surface.SetDrawColor(200, 200, 200, 255)
        surface.DrawOutlinedRect(x, y, barW, barH, 2)

        -- Label
        draw.SimpleText(label, "ixSmallFont", w / 2, y - 20, labelColor or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

        -- Cancel hint (optional)
        if cancelText then
            draw.SimpleText(cancelText, "ixSmallFont", w / 2, y + barH + 10, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end

    -- Open a container bag's inventory panel (shared by all bag items' View function)
    function C.OpenContainerPanel(item)
        local index = item:GetData("id", "")
        if not index then return false end

        local panel = ix.gui["inv"..index]
        local inventory = ix.item.inventories[index]
        local parent = IsValid(ix.gui.menuInventoryContainer) and ix.gui.menuInventoryContainer or ix.gui.openedStorage

        if IsValid(panel) then panel:Remove() end

        if inventory and inventory.slots then
            panel = vgui.Create("ixInventory", IsValid(parent) and parent or nil)
            panel:SetInventory(inventory)
            panel:ShowCloseButton(true)

            local title = item:GetName()
            if item.viewSuffix then title = title .. item.viewSuffix end
            panel:SetTitle(title)

            if parent ~= ix.gui.menuInventoryContainer then
                panel:Center()
                if parent == ix.gui.openedStorage then panel:MakePopup() end
            else
                panel:MoveToFront()
            end

            ix.gui["inv"..index] = panel
        end

        return false
    end

    function C.CanOpenContainerPanel(item)
        return not IsValid(item.entity) and item:GetData("id") and not IsValid(ix.gui["inv" .. item:GetData("id", "")])
    end

    -- =========================================================================
    -- DERMA HELPERS
    -- =========================================================================

    -- Header bar colors (shared by Personal ID, Radio Frequency, and future panels)
    local COLOR_HEADER_BG = Color(30, 58, 95)

    -- Create a dark header bar with rounded top corners, title text, and close button.
    -- parent: parent panel
    -- title: header title string
    -- height: header height in pixels (default 36)
    -- onClose: function to call when close button is clicked (default: parent:Remove())
    -- Returns: header panel, close button
    function C.CreateHeaderBar(parent, title, height, onClose)
        height = height or 36

        local header = vgui.Create("DPanel", parent)
        header:SetTall(height)
        header:Dock(TOP)
        header.text = title
        header.Paint = function(pnl, w, h)
            draw.RoundedBoxEx(4, 0, 0, w, h, COLOR_HEADER_BG, true, true, false, false)

            surface.SetFont("ixMediumFont")
            local tw, th = surface.GetTextSize(pnl.text)
            surface.SetTextColor(255, 255, 255, 255)
            surface.SetTextPos(12, (h - th) / 2)
            surface.DrawText(pnl.text)
        end

        local closeBtn = vgui.Create("DButton", header)
        closeBtn:SetSize(height - 12, height - 12)
        closeBtn:Dock(RIGHT)
        closeBtn:DockMargin(0, 6, 6, 6)
        closeBtn:SetText("\xC3\x97")  -- multiplication sign (x)
        closeBtn:SetFont("ixMediumFont")
        closeBtn:SetTextColor(C.COLOR_UI_NEUTRAL)
        closeBtn.Paint = function(btn, w, h)
            if btn:IsHovered() then
                surface.SetDrawColor(255, 255, 255, 30)
                surface.DrawRect(0, 0, w, h)
            end
        end
        closeBtn.DoClick = onClose or function()
            parent:Remove()
        end

        return header, closeBtn
    end

    -- Create a bottom button bar: a transparent DPanel (height 40) docked BOTTOM
    -- with buttons created from a spec list.
    -- parent: parent panel for the bar
    -- buttons: sequential table of button specs, each a table:
    --   {text, width, dock, onClick}
    --   - text: button label string
    --   - width: button width in pixels
    --   - dock: LEFT or RIGHT
    --   - onClick: DoClick handler function
    --   Buttons are created in list order. Margins: 10px on the outside edge
    --   (first LEFT button gets 10 left, last RIGHT button gets 10 right),
    --   5px between adjacent buttons, 5px top/bottom.
    -- Returns: btnPanel, {button1, button2, ...} (buttons in spec order)
    function C.CreateButtonBar(parent, buttons)
        local btnPanel = vgui.Create("DPanel", parent)
        btnPanel:Dock(BOTTOM)
        btnPanel:SetTall(40)
        btnPanel.Paint = function() end

        local created = {}
        local leftCount = 0
        local rightCount = 0

        -- Count totals for margin calculation
        local totalLeft = 0
        local totalRight = 0
        for _, spec in ipairs(buttons) do
            if spec[3] == LEFT then
                totalLeft = totalLeft + 1
            else
                totalRight = totalRight + 1
            end
        end

        for _, spec in ipairs(buttons) do
            local text, width, dock, onClick = spec[1], spec[2], spec[3], spec[4]

            local btn = vgui.Create("DButton", btnPanel)
            btn:Dock(dock)
            btn:SetWide(width)
            btn:SetText(text)

            -- Calculate margins: outside edges get 10, inner gaps get 5
            local marginL, marginR = 5, 5
            if dock == LEFT then
                leftCount = leftCount + 1
                if leftCount == 1 then marginL = 10 end
            else
                rightCount = rightCount + 1
                if rightCount == 1 then marginR = 10 end
            end
            btn:DockMargin(marginL, 5, marginR, 5)

            if onClick then
                btn.DoClick = onClick
            end

            table.insert(created, btn)
        end

        return btnPanel, created
    end

    -- Process SWEP input: cursor check, LMB/RMB polling, edge detection
    -- Returns lmbPressed, rmbPressed (true only on the frame the button was first pressed)
    function C.ProcessSWEPInput(weapon)
        if vgui.CursorVisible() then
            weapon.wasLMBDown = false
            weapon.wasRMBDown = false
            return false, false
        end

        local lmbDown = input.IsMouseDown(MOUSE_LEFT)
        local rmbDown = input.IsMouseDown(MOUSE_RIGHT)

        local lmbPressed = lmbDown and weapon.wasLMBDown == false
        local rmbPressed = rmbDown and weapon.wasRMBDown == false

        weapon.wasLMBDown = lmbDown
        weapon.wasRMBDown = rmbDown

        return lmbPressed, rmbPressed
    end
end

-- Get character and inventory from a player, returning nil if either is missing
function C.GetCharacterInventory(client)
    local character = client:GetCharacter()
    if not character then return nil, nil end
    return character, character:GetInventory()
end

-- Verify that a client owns an item in their inventory (SERVER only)
-- Returns the item if found and valid, nil otherwise
if SERVER then
    function C.VerifyItemOwnership(client, itemID, expectedUniqueID)
        local item = ix.item.instances[itemID]
        if not item then return nil end

        if expectedUniqueID and item.uniqueID ~= expectedUniqueID then
            return nil
        end

        local character, inventory = C.GetCharacterInventory(client)
        if not character or not inventory then return nil end

        for _, invItem in pairs(inventory:GetItems()) do
            if invItem:GetID() == itemID then
                return item
            end
        end

        return nil
    end
end

-- Shared SWEP cancel action: check state, run cleanup, play cancel sound (SERVER only)
function C.CancelSWEPAction(weapon, checkFn, cleanupFn, soundVolume)
    if not checkFn() then return end
    cleanupFn()
    local owner = weapon:GetOwner()
    if IsValid(owner) and SERVER then
        owner:EmitSound("buttons/button10.wav", soundVolume or 50)
    end
end

