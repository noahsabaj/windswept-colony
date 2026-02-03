--[[
    Document Viewer

    Panel for reading document contents with signature display.
]]--

local PANEL = {}

function PANEL:Init()
    self:SetSize(550, 650)
    self:Center()
    self:MakePopup()
    self:SetTitle("Document")
    self:SetDraggable(true)
    self:ShowCloseButton(true)
    self:SetKeyboardInputEnabled(true)

    self.closeKeys = {KEY_ESCAPE}

    -- Header panel
    local headerPanel = vgui.Create("DPanel", self)
    headerPanel:Dock(TOP)
    headerPanel:SetTall(70)
    headerPanel.Paint = function(pnl, w, h)
        surface.SetDrawColor(35, 35, 35)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(60, 60, 60)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    -- Title
    self.titleLabel = vgui.Create("DLabel", headerPanel)
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(15, 10, 15, 0)
    self.titleLabel:SetFont("ixMediumFont")
    self.titleLabel:SetText("Untitled Document")
    self.titleLabel:SetTextColor(Color(220, 220, 220))

    -- Metadata (author, type, word count)
    self.metaLabel = vgui.Create("DLabel", headerPanel)
    self.metaLabel:Dock(TOP)
    self.metaLabel:DockMargin(15, 5, 15, 10)
    self.metaLabel:SetText("Author: Unknown | Type: Handwritten | Words: 0")
    self.metaLabel:SetTextColor(Color(150, 150, 150))

    -- Content scroll panel
    self.scroll = vgui.Create("DScrollPanel", self)
    self.scroll:Dock(FILL)
    self.scroll:DockMargin(10, 10, 10, 10)

    -- Content background
    local contentBg = vgui.Create("DPanel", self.scroll)
    contentBg:Dock(TOP)
    contentBg:DockMargin(0, 0, 0, 0)
    contentBg.Paint = function(pnl, w, h)
        surface.SetDrawColor(45, 45, 45)
        surface.DrawRect(0, 0, w, h)
    end

    -- Content label
    self.contentLabel = vgui.Create("DLabel", contentBg)
    self.contentLabel:Dock(FILL)
    self.contentLabel:DockMargin(15, 15, 15, 15)
    self.contentLabel:SetWrap(true)
    self.contentLabel:SetAutoStretchVertical(true)
    self.contentLabel:SetText("Loading...")
    self.contentLabel:SetTextColor(Color(200, 200, 200))

    -- Update content background height when content changes
    self.contentLabel.PerformLayout = function(lbl)
        lbl:SizeToContentsY()
        contentBg:SetTall(lbl:GetTall() + 30)
    end

    -- Signatures container (hidden by default)
    self.signaturesContainer = vgui.Create("DPanel", self.scroll)
    self.signaturesContainer:Dock(TOP)
    self.signaturesContainer:DockMargin(0, 15, 0, 0)
    self.signaturesContainer:SetVisible(false)
    self.signaturesContainer.Paint = function() end

    self.signatures = {}

    -- Close instructions
    local closeLabel = vgui.Create("DLabel", self)
    closeLabel:Dock(BOTTOM)
    closeLabel:DockMargin(10, 5, 10, 5)
    closeLabel:SetText("Press ESC or click X to close")
    closeLabel:SetTextColor(Color(100, 100, 100))
    closeLabel:SetContentAlignment(5)
end

function PANEL:SetDocument(data)
    if not data then return end

    -- Title
    local title = data.title
    if not title or title == "" then
        title = "Untitled Document"
    end
    self.titleLabel:SetText(title)
    self:SetTitle(title)

    -- Metadata
    local author = data.author or "Unknown"
    local docType = ix.documents and ix.documents.FormatType(data.documentType) or (data.documentType or "Unknown")
    local wordCount = data.wordCount or 0

    self.metaLabel:SetText(string.format("By %s | %s | %d words", author, docType, wordCount))

    -- Content
    local content = data.content or ""
    if content == "" then
        content = "(No content)"
    end
    self.contentLabel:SetText(content)
    self.contentLabel:SizeToContentsY()

    -- Signatures (supports multiple)
    local signatures = data.signatures or {}

    -- Backwards compatibility: convert old single signature to array
    if data.signatureData and #signatures == 0 then
        table.insert(signatures, data.signatureData)
    end

    if #signatures > 0 then
        self.signaturesContainer:SetVisible(true)
        self:CreateSignaturePanels(signatures)
    end
end

function PANEL:CreateSignaturePanels(signatures)
    local totalHeight = 0
    local sigHeight = 100
    local spacing = 10

    for i, sigData in ipairs(signatures) do
        local sigPanel = vgui.Create("DPanel", self.signaturesContainer)
        sigPanel:Dock(TOP)
        sigPanel:DockMargin(0, i > 1 and spacing or 0, 0, 0)
        sigPanel:SetTall(sigHeight)

        -- Get stroke color (default to gray for backwards compatibility)
        local strokeColor = sigData.color or {200, 200, 200}
        local isPencil = sigData.type == "pencil"

        sigPanel.Paint = function(pnl, w, h)
            -- Background
            surface.SetDrawColor(45, 45, 45)
            surface.DrawRect(0, 0, w, h)

            -- Signature area
            local sigX = 15
            local sigY = 5
            local sigW = w - 30
            local sigH = h - 30

            -- Signature background
            surface.SetDrawColor(35, 35, 35)
            surface.DrawRect(sigX, sigY, sigW, sigH)

            -- Draw strokes with color
            surface.SetDrawColor(strokeColor[1], strokeColor[2], strokeColor[3])
            local strokes = sigData.strokes or {}
            for _, stroke in ipairs(strokes) do
                if #stroke >= 2 then
                    for j = 2, #stroke do
                        local x1 = sigX + stroke[j - 1].x * sigW
                        local y1 = sigY + stroke[j - 1].y * sigH
                        local x2 = sigX + stroke[j].x * sigW
                        local y2 = sigY + stroke[j].y * sigH
                        surface.DrawLine(x1, y1, x2, y2)
                    end
                end
            end

            -- Border
            surface.SetDrawColor(80, 80, 80)
            surface.DrawOutlinedRect(sigX, sigY, sigW, sigH)

            -- Author label
            local authorText = sigData.authorName or "Unknown"
            if isPencil then
                authorText = authorText .. " (pencil)"
            end
            draw.SimpleText(authorText, "ixSmallFont", 15, h - 18, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        totalHeight = totalHeight + sigHeight + (i > 1 and spacing or 0)
    end

    self.signaturesContainer:SetTall(totalHeight)
end

function PANEL:OnKeyCodePressed(key)
    for _, closeKey in ipairs(self.closeKeys) do
        if key == closeKey then
            self:Remove()
            return
        end
    end
end

function PANEL:OnRemove()
    -- Cleanup
end

vgui.Register("ixDocumentViewer", PANEL, "DFrame")
