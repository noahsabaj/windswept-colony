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

    -- Signature panel (hidden by default)
    self.signaturePanel = vgui.Create("DPanel", self.scroll)
    self.signaturePanel:Dock(TOP)
    self.signaturePanel:DockMargin(0, 15, 0, 0)
    self.signaturePanel:SetTall(120)
    self.signaturePanel:SetVisible(false)

    self.signatureData = nil

    self.signaturePanel.Paint = function(pnl, w, h)
        if not self.signatureData then return end

        -- Background
        surface.SetDrawColor(45, 45, 45)
        surface.DrawRect(0, 0, w, h)

        -- Label
        draw.SimpleText("Signature:", "ixSmallFont", 15, 10, Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Signature area
        local sigX = 15
        local sigY = 30
        local sigW = w - 30
        local sigH = h - 55

        -- Signature background
        surface.SetDrawColor(35, 35, 35)
        surface.DrawRect(sigX, sigY, sigW, sigH)

        -- Draw strokes
        surface.SetDrawColor(200, 200, 200)
        local strokes = self.signatureData.strokes or {}
        for _, stroke in ipairs(strokes) do
            if #stroke >= 2 then
                for i = 2, #stroke do
                    local x1 = sigX + stroke[i - 1].x * sigW
                    local y1 = sigY + stroke[i - 1].y * sigH
                    local x2 = sigX + stroke[i].x * sigW
                    local y2 = sigY + stroke[i].y * sigH
                    surface.DrawLine(x1, y1, x2, y2)
                end
            end
        end

        -- Border
        surface.SetDrawColor(80, 80, 80)
        surface.DrawOutlinedRect(sigX, sigY, sigW, sigH)
    end

    -- Signature author label
    self.sigAuthorLabel = vgui.Create("DLabel", self.signaturePanel)
    self.sigAuthorLabel:SetPos(15, 95)
    self.sigAuthorLabel:SetSize(300, 20)
    self.sigAuthorLabel:SetText("")
    self.sigAuthorLabel:SetTextColor(Color(150, 150, 150))

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

    -- Signature
    if data.signatureData then
        self.signatureData = data.signatureData
        self.signaturePanel:SetVisible(true)

        local sigAuthor = data.signatureData.authorName or "Unknown"
        self.sigAuthorLabel:SetText("Signed by: " .. sigAuthor)
    end
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
