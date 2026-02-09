--[[
    Signature Pad

    A drawing canvas for mouse-drawn signatures.
    Stores strokes as normalized coordinates (0-1 range).
]]--

local PANEL = {}

function PANEL:Init()
    self:SetSize(400, 280)
    self:Center()
    self:MakePopup()
    self:SetTitle("Sign Document")
    self:SetDraggable(true)
    self:ShowCloseButton(true)

    self.strokes = {}
    self.currentStroke = nil
    self.isDrawing = false
    self.strokeColor = {200, 200, 200}  -- Default gray, set by SetStrokeColor

    -- Instructions label
    local instructions = vgui.Create("DLabel", self)
    instructions:Dock(TOP)
    instructions:DockMargin(10, 5, 10, 5)
    instructions:SetText("Draw your signature below. Click and drag to draw.")
    instructions:SetTextColor(ix.constants.COLOR_UI_NEUTRAL)

    -- Canvas panel
    self.canvas = vgui.Create("DPanel", self)
    self.canvas:Dock(FILL)
    self.canvas:DockMargin(10, 5, 10, 10)

    self.canvas.Paint = function(pnl, w, h)
        -- Background
        surface.SetDrawColor(40, 40, 40)
        surface.DrawRect(0, 0, w, h)

        -- Draw existing strokes with color
        local color = self.strokeColor
        surface.SetDrawColor(color[1], color[2], color[3])
        for _, stroke in ipairs(self.strokes) do
            self:DrawStroke(stroke, w, h)
        end

        -- Draw current stroke
        if self.currentStroke then
            self:DrawStroke(self.currentStroke, w, h)
        end

        -- Border
        surface.SetDrawColor(100, 100, 100)
        surface.DrawOutlinedRect(0, 0, w, h)

        -- Signature line
        local lineY = h * 0.75
        surface.SetDrawColor(80, 80, 80)
        surface.DrawLine(20, lineY, w - 20, lineY)

        -- X mark
        draw.SimpleText("X", "ixSmallFont", 10, lineY - 10, Color(80, 80, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    end

    self.canvas.OnMousePressed = function(pnl, code)
        if code == MOUSE_LEFT then
            self.isDrawing = true
            self.currentStroke = {}
            local x, y = pnl:CursorPos()
            local w, h = pnl:GetSize()
            table.insert(self.currentStroke, {x = x / w, y = y / h})
        end
    end

    self.canvas.OnMouseReleased = function(pnl, code)
        if code == MOUSE_LEFT and self.isDrawing then
            self.isDrawing = false
            if self.currentStroke and #self.currentStroke > 1 then
                table.insert(self.strokes, self.currentStroke)
            end
            self.currentStroke = nil
        end
    end

    self.canvas.Think = function(pnl)
        if self.isDrawing and self.currentStroke then
            local x, y = pnl:CursorPos()
            local w, h = pnl:GetSize()

            -- Only add point if within canvas
            if x >= 0 and x <= w and y >= 0 and y <= h then
                local last = self.currentStroke[#self.currentStroke]
                -- Add point if moved enough (reduces data size)
                if not last or math.abs(x / w - last.x) > 0.005 or math.abs(y / h - last.y) > 0.005 then
                    table.insert(self.currentStroke, {x = x / w, y = y / h})
                end
            end
        end
    end

    -- Button panel
    local btnPanel = vgui.Create("DPanel", self)
    btnPanel:Dock(BOTTOM)
    btnPanel:SetTall(40)
    btnPanel.Paint = function() end

    -- Clear button
    local clearBtn = vgui.Create("DButton", btnPanel)
    clearBtn:Dock(LEFT)
    clearBtn:SetWide(70)
    clearBtn:DockMargin(10, 5, 5, 5)
    clearBtn:SetText("Clear")
    clearBtn.DoClick = function()
        self.strokes = {}
        self.currentStroke = nil
    end

    -- Cancel button
    local cancelBtn = vgui.Create("DButton", btnPanel)
    cancelBtn:Dock(RIGHT)
    cancelBtn:SetWide(70)
    cancelBtn:DockMargin(5, 5, 10, 5)
    cancelBtn:SetText("Cancel")
    cancelBtn.DoClick = function()
        self:Remove()
    end

    -- Save & Sign button
    local saveSignBtn = vgui.Create("DButton", btnPanel)
    saveSignBtn:Dock(RIGHT)
    saveSignBtn:SetWide(90)
    saveSignBtn:DockMargin(5, 5, 5, 5)
    saveSignBtn:SetText("Save & Sign")
    saveSignBtn.DoClick = function()
        if #self.strokes > 0 then
            -- Save signature to character
            net.Start("ixSignatureSave")
                net.WriteString(util.TableToJSON(self.strokes))
            net.SendToServer()

            -- Also apply to current document
            if self.OnConfirm then
                self.OnConfirm(self.strokes)
            end
        else
            LocalPlayer():NotifyLocalized("signatureEmpty")
        end
        self:Remove()
    end

    -- Sign button (one-time use)
    local confirmBtn = vgui.Create("DButton", btnPanel)
    confirmBtn:Dock(RIGHT)
    confirmBtn:SetWide(70)
    confirmBtn:DockMargin(5, 5, 5, 5)
    confirmBtn:SetText("Sign")
    confirmBtn.DoClick = function()
        if #self.strokes > 0 then
            if self.OnConfirm then
                self.OnConfirm(self.strokes)
            end
        else
            LocalPlayer():NotifyLocalized("signatureEmpty")
        end
        self:Remove()
    end
end

function PANEL:DrawStroke(stroke, w, h)
    if #stroke < 2 then return end

    for i = 2, #stroke do
        local x1 = stroke[i - 1].x * w
        local y1 = stroke[i - 1].y * h
        local x2 = stroke[i].x * w
        local y2 = stroke[i].y * h
        surface.DrawLine(x1, y1, x2, y2)
    end
end

function PANEL:GetStrokes()
    return self.strokes
end

function PANEL:SetStrokeColor(color)
    self.strokeColor = color or {200, 200, 200}
end

function PANEL:OnRemove()
    -- Cleanup
end

vgui.Register("ixSignaturePad", PANEL, "DFrame")
