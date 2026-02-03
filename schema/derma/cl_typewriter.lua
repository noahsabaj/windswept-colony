--[[
    Typewriter UI

    Interface for typing on paper using a typewriter.
    Monospace font, no signatures, append-only.
]]--

local PANEL = {}

function PANEL:Init()
    self:SetSize(600, 550)
    self:Center()
    self:MakePopup()
    self:SetTitle("Typewriter")
    self:SetDraggable(true)
    self:ShowCloseButton(true)

    self.typewriter = nil
    self.papers = {}
    self.selectedPaper = nil

    -- Paper selection section
    self.paperLabel = vgui.Create("DLabel", self)
    self.paperLabel:Dock(TOP)
    self.paperLabel:DockMargin(10, 5, 10, 0)
    self.paperLabel:SetText("Select Paper:")
    self.paperLabel:SetTextColor(Color(200, 200, 200))

    self.paperSelect = vgui.Create("DComboBox", self)
    self.paperSelect:Dock(TOP)
    self.paperSelect:DockMargin(10, 5, 10, 10)
    self.paperSelect:SetTall(25)
    self.paperSelect:SetValue("-- Select Paper --")
    self.paperSelect.OnSelect = function(pnl, index, value, data)
        self:SelectPaper(data)
    end

    -- Typing area
    self.contentLabel = vgui.Create("DLabel", self)
    self.contentLabel:Dock(TOP)
    self.contentLabel:DockMargin(10, 5, 10, 0)
    self.contentLabel:SetText("Type your document:")
    self.contentLabel:SetTextColor(Color(200, 200, 200))

    self.content = vgui.Create("DTextEntry", self)
    self.content:Dock(FILL)
    self.content:DockMargin(10, 5, 10, 10)
    self.content:SetMultiline(true)
    self.content:SetPlaceholderText("Begin typing...")
    self.content:SetFont("ixTypewriterFont")
    self.content:SetEnabled(false)  -- Disabled until paper selected
    self.content.OnChange = function()
        self:UpdateCharCounter()
    end

    -- Create monospace font for typewriter effect
    surface.CreateFont("ixTypewriterFont", {
        font = "Courier New",
        size = 16,
        weight = 500
    })

    -- Bottom panel
    local bottomPanel = vgui.Create("DPanel", self)
    bottomPanel:Dock(BOTTOM)
    bottomPanel:SetTall(70)
    bottomPanel.Paint = function() end

    -- Character counter
    self.charCounter = vgui.Create("DLabel", bottomPanel)
    self.charCounter:Dock(TOP)
    self.charCounter:DockMargin(10, 5, 10, 5)
    self.charCounter:SetText("Characters: 0")
    self.charCounter:SetTextColor(Color(200, 200, 200))

    -- Button panel
    local btnPanel = vgui.Create("DPanel", bottomPanel)
    btnPanel:Dock(BOTTOM)
    btnPanel:SetTall(40)
    btnPanel.Paint = function() end

    -- Cancel button
    local cancelBtn = vgui.Create("DButton", btnPanel)
    cancelBtn:Dock(RIGHT)
    cancelBtn:SetWide(80)
    cancelBtn:DockMargin(5, 5, 10, 5)
    cancelBtn:SetText("Cancel")
    cancelBtn.DoClick = function()
        self:Close()
    end

    -- Type button
    self.typeBtn = vgui.Create("DButton", btnPanel)
    self.typeBtn:Dock(RIGHT)
    self.typeBtn:SetWide(80)
    self.typeBtn:DockMargin(5, 5, 5, 5)
    self.typeBtn:SetText("Type")
    self.typeBtn:SetEnabled(false)
    self.typeBtn.DoClick = function()
        self:TypeDocument()
    end
end

function PANEL:SetTypewriter(typewriter)
    self.typewriter = typewriter
end

function PANEL:SetPapers(papers)
    self.papers = papers

    self.paperSelect:Clear()
    self.paperSelect:SetValue("-- Select Paper --")

    for _, paper in ipairs(papers) do
        local label = paper.name
        if paper.hasContent then
            label = label .. " (has content)"
        end
        self.paperSelect:AddChoice(label, paper.id)
    end

    if #papers == 0 then
        self.paperSelect:SetValue("No paper available")
    end
end

function PANEL:SelectPaper(paperID)
    self.selectedPaper = paperID
    self.content:SetEnabled(true)
    self.typeBtn:SetEnabled(true)

    -- Clear content for fresh typing
    self.content:SetText("")
    self:UpdateCharCounter()
end

function PANEL:UpdateCharCounter()
    local charCount = #self.content:GetValue()
    self.charCounter:SetText(string.format("Characters: %d", charCount))

    if charCount > ix.documents.MAX_CONTENT_LENGTH then
        self.charCounter:SetTextColor(Color(255, 100, 100))
    else
        self.charCounter:SetTextColor(Color(200, 200, 200))
    end
end

function PANEL:TypeDocument()
    if not self.selectedPaper then
        LocalPlayer():NotifyLocalized("selectPaperFirst")
        return
    end

    local content = self.content:GetValue()
    if content == "" then
        LocalPlayer():NotifyLocalized("documentEmpty")
        return
    end

    -- Send to server
    net.Start("ixTypewriterWrite")
        net.WriteEntity(self.typewriter)
        net.WriteUInt(self.selectedPaper, 32)
        net.WriteString(content)
    net.SendToServer()

    self:Close()
end

function PANEL:Close()
    -- Notify server we're closing
    if IsValid(self.typewriter) then
        net.Start("ixTypewriterClose")
            net.WriteEntity(self.typewriter)
        net.SendToServer()
    end

    self:Remove()
end

function PANEL:OnRemove()
    -- Make sure we notify server
    if IsValid(self.typewriter) then
        net.Start("ixTypewriterClose")
            net.WriteEntity(self.typewriter)
        net.SendToServer()
    end
end

vgui.Register("ixTypewriterUI", PANEL, "DFrame")
