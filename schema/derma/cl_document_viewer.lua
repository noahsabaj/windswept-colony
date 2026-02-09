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
    self:SetKeyboardInputEnabled(false)

    -- Header panel
    local headerPanel = vgui.Create("DPanel", self)
    headerPanel:Dock(TOP)
    headerPanel:SetTall(40)
    headerPanel.Paint = function(pnl, w, h)
        surface.SetDrawColor(35, 35, 35)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(60, 60, 60)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    -- Metadata (type, word count) - NO author shown (fog of war)
    self.metaLabel = vgui.Create("DLabel", headerPanel)
    self.metaLabel:Dock(TOP)
    self.metaLabel:DockMargin(15, 10, 15, 10)
    self.metaLabel:SetText("Handwritten | 0 words")
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
    self.contentLabel:SetTextColor(ix.constants.COLOR_UI_NEUTRAL)

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
    closeLabel:SetText("Click X to close")
    closeLabel:SetTextColor(Color(100, 100, 100))
    closeLabel:SetContentAlignment(5)
end

function PANEL:SetDocument(data)
    if not data then return end

    -- Metadata (NO author - fog of war)
    local docType = ix.documents and ix.documents.FormatType(data.documentType) or (data.documentType or "Unknown")
    local wordCount = data.wordCount or 0

    self.metaLabel:SetText(string.format("%s | %d words", docType, wordCount))

    -- Content
    local content = data.content or ""
    if content == "" then
        content = "(No content)"
    end
    self.contentLabel:SetText(content)
    self.contentLabel:SizeToContentsY()

    local signatures = data.signatures or {}

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

        -- Get stroke color (default gray if missing)
        local strokeColor = sigData.color or {200, 200, 200}

        sigPanel.Paint = function(pnl, w, h)
            -- Background
            surface.SetDrawColor(45, 45, 45)
            surface.DrawRect(0, 0, w, h)

            -- Signature area (full height now, no label below)
            local sigX = 15
            local sigY = 5
            local sigW = w - 30
            local sigH = h - 10

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

            -- NO author label - fog of war (signature speaks for itself)
        end

        totalHeight = totalHeight + sigHeight + (i > 1 and spacing or 0)
    end

    self.signaturesContainer:SetTall(totalHeight)
end

function PANEL:OnRemove()
    -- Cleanup
end

vgui.Register("ixDocumentViewer", PANEL, "DFrame")
