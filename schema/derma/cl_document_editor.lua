--[[
    Document Editor

    Panel for writing on paper documents.
    Supports append-only writing, signatures (pen only), and ink/lead tracking.
]]--

local PANEL = {}

function PANEL:Init()
    self:SetSize(550, 600)
    self:Center()
    self:MakePopup()
    self:SetTitle("Write Document")
    self:SetDraggable(true)
    self:ShowCloseButton(true)

    self.paperItem = nil
    self.toolType = "pen"  -- "pen" or "pencil"
    self.resourceRemaining = 1000
    self.maxResource = 1000
    self.signatureData = nil
    self.existingContent = ""
    self.hasExistingContent = false

    -- Existing content section (read-only)
    self.existingLabel = vgui.Create("DLabel", self)
    self.existingLabel:Dock(TOP)
    self.existingLabel:DockMargin(10, 5, 10, 0)
    self.existingLabel:SetText("Existing content:")
    self.existingLabel:SetTextColor(Color(150, 150, 150))
    self.existingLabel:SetVisible(false)

    self.existingScroll = vgui.Create("DScrollPanel", self)
    self.existingScroll:Dock(TOP)
    self.existingScroll:DockMargin(10, 5, 10, 10)
    self.existingScroll:SetTall(120)
    self.existingScroll:SetVisible(false)

    self.existingText = vgui.Create("DLabel", self.existingScroll)
    self.existingText:Dock(TOP)
    self.existingText:SetWrap(true)
    self.existingText:SetAutoStretchVertical(true)
    self.existingText:SetTextColor(Color(180, 180, 180))

    -- New content label
    self.newLabel = vgui.Create("DLabel", self)
    self.newLabel:Dock(TOP)
    self.newLabel:DockMargin(10, 5, 10, 0)
    self.newLabel:SetText("Write new content:")
    self.newLabel:SetTextColor(Color(200, 200, 200))

    -- New content text entry
    self.content = vgui.Create("DTextEntry", self)
    self.content:Dock(FILL)
    self.content:DockMargin(10, 5, 10, 10)
    self.content:SetMultiline(true)
    self.content:SetPlaceholderText("Begin writing...")
    self.content.OnChange = function()
        self:UpdateResourceCounter()
    end

    -- Bottom panel
    local bottomPanel = vgui.Create("DPanel", self)
    bottomPanel:Dock(BOTTOM)
    bottomPanel:SetTall(90)
    bottomPanel.Paint = function() end

    -- Resource counter
    self.resourceCounter = vgui.Create("DLabel", bottomPanel)
    self.resourceCounter:Dock(TOP)
    self.resourceCounter:DockMargin(10, 5, 10, 0)
    self.resourceCounter:SetText("Ink: 1000 remaining")
    self.resourceCounter:SetTextColor(Color(200, 200, 200))

    -- Signature status
    self.sigStatus = vgui.Create("DLabel", bottomPanel)
    self.sigStatus:Dock(TOP)
    self.sigStatus:DockMargin(10, 2, 10, 5)
    self.sigStatus:SetText("")
    self.sigStatus:SetTextColor(Color(150, 200, 150))

    -- Button panel
    local btnPanel = vgui.Create("DPanel", bottomPanel)
    btnPanel:Dock(BOTTOM)
    btnPanel:SetTall(40)
    btnPanel.Paint = function() end

    -- Sign button (pen only)
    self.signBtn = vgui.Create("DButton", btnPanel)
    self.signBtn:Dock(LEFT)
    self.signBtn:SetWide(120)
    self.signBtn:DockMargin(10, 5, 5, 5)
    self.signBtn:SetText("Add Signature")
    self.signBtn.DoClick = function()
        self:OpenSignaturePad()
    end

    -- Cancel button
    local cancelBtn = vgui.Create("DButton", btnPanel)
    cancelBtn:Dock(RIGHT)
    cancelBtn:SetWide(80)
    cancelBtn:DockMargin(5, 5, 10, 5)
    cancelBtn:SetText("Cancel")
    cancelBtn.DoClick = function()
        self:Remove()
    end

    -- Save button
    local saveBtn = vgui.Create("DButton", btnPanel)
    saveBtn:Dock(RIGHT)
    saveBtn:SetWide(80)
    saveBtn:DockMargin(5, 5, 5, 5)
    saveBtn:SetText("Save")
    saveBtn.DoClick = function()
        self:SaveDocument()
    end
end

function PANEL:SetPaper(paperItem)
    self.paperItem = paperItem

    -- Check for existing content
    if paperItem:HasContent() then
        self.hasExistingContent = true
        self.existingLabel:SetVisible(true)
        self.existingScroll:SetVisible(true)
        self.existingText:SetText("Loading...")

        -- Request existing content from server
        -- Store reference for callback
        ix.gui.documentEditor = self

        net.Start("ixDocumentRead")
            net.WriteUInt(paperItem:GetID(), 32)
            net.WriteBool(true)  -- For editor
        net.SendToServer()
    end
end

function PANEL:SetExistingContent(content)
    self.existingContent = content or ""
    self.existingText:SetText(content or "(empty)")
    self.existingText:SizeToContentsY()
end

function PANEL:SetWritingTool(toolType)
    self.toolType = toolType

    -- Get resource amount from equipped item
    local client = LocalPlayer()

    if toolType == "pen" then
        local item = client.ixPenItem
        if item then
            self.resourceRemaining = item:GetInk()
            self.maxResource = item.maxInk
        end
        self.signBtn:SetEnabled(true)
        self.signBtn:SetText("Add Signature")
    else
        local item = client.ixPencilItem
        if item then
            self.resourceRemaining = item:GetData("lead", 500)
            self.maxResource = item.maxLead or 500
        end
        -- Pencils cannot sign
        self.signBtn:SetEnabled(false)
        self.signBtn:SetText("Pen Required")
    end

    self:UpdateResourceCounter()
end

function PANEL:UpdateResourceCounter()
    local contentLength = #self.content:GetValue()
    local signatureCost = self.signatureData and 50 or 0
    local totalCost = contentLength + signatureCost
    local remaining = self.resourceRemaining - totalCost

    local resourceName = self.toolType == "pen" and "Ink" or "Lead"

    self.resourceCounter:SetText(string.format("%s: %d remaining (using %d)",
        resourceName, remaining, totalCost))

    if remaining < 0 then
        self.resourceCounter:SetTextColor(Color(255, 100, 100))
    elseif remaining < self.maxResource * 0.1 then
        self.resourceCounter:SetTextColor(Color(255, 200, 100))
    else
        self.resourceCounter:SetTextColor(Color(200, 200, 200))
    end
end

function PANEL:OpenSignaturePad()
    if IsValid(self.sigPad) then
        self.sigPad:Remove()
    end

    self.sigPad = vgui.Create("ixSignaturePad")
    self.sigPad.OnConfirm = function(strokes)
        self.signatureData = strokes
        self.sigStatus:SetText("Signature added")
        self.signBtn:SetText("Signed")
        self.signBtn:SetEnabled(false)
        self:UpdateResourceCounter()
    end
end

function PANEL:SaveDocument()
    local content = self.content:GetValue()

    -- Check if there's anything to save
    if content == "" and not self.signatureData then
        LocalPlayer():NotifyLocalized("documentEmpty")
        return
    end

    -- Check resource availability
    local contentLength = #content
    local signatureCost = self.signatureData and 50 or 0
    local totalCost = contentLength + signatureCost

    if totalCost > self.resourceRemaining then
        local resourceName = self.toolType == "pen" and "ink" or "lead"
        LocalPlayer():NotifyLocalized("notEnough" .. (self.toolType == "pen" and "Ink" or "Lead"))
        return
    end

    -- Send to server
    net.Start("ixDocumentWrite")
        net.WriteUInt(self.paperItem:GetID(), 32)
        net.WriteString(content)
        net.WriteBool(self.signatureData ~= nil)
        if self.signatureData then
            net.WriteString(util.TableToJSON(self.signatureData))
        end
        net.WriteBool(false)  -- Not a rename operation
        net.WriteString("")   -- No title
    net.SendToServer()

    self:Remove()
end

function PANEL:OnRemove()
    if IsValid(self.sigPad) then
        self.sigPad:Remove()
    end

    if ix.gui.documentEditor == self then
        ix.gui.documentEditor = nil
    end
end

vgui.Register("ixDocumentEditor", PANEL, "DFrame")

-- ============================================================================
-- NETWORK RECEIVER FOR EDITOR CONTENT
-- ============================================================================

net.Receive("ixDocumentData", function()
    local forEditor = net.ReadBool()
    local jsonData = net.ReadString()
    local data = util.JSONToTable(jsonData)

    if not data then return end

    if forEditor then
        -- Update editor with existing content
        if IsValid(ix.gui.documentEditor) then
            ix.gui.documentEditor:SetExistingContent(data.content or "")
        end
    else
        -- Open viewer
        local viewer = vgui.Create("ixDocumentViewer")
        viewer:SetDocument(data)
    end
end)
