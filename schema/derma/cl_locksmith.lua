--[[
    Locksmith UI

    Interface for programming locks and keys at a locksmith machine.

    Operations:
    - Program Lock: Blank Lock -> Lock with auto-generated keying
    - Program Key: Blank Key + Lock/Key -> Key with copied keying
    - Add Keying: Lock + Key -> Lock accepts that key's keying
    - Rename Lock/Key: One-time cosmetic rename
    - View Lock Keyings: Shows all accepted keyings
]]--

local PANEL = {}

function PANEL:Init()
    self:SetSize(450, 400)
    self:SetTitle("Locksmith")
    self:Center()
    self:MakePopup()
    self:SetDraggable(true)

    self.station = nil

    -- Tab system
    self.tabs = vgui.Create("DPropertySheet", self)
    self.tabs:Dock(FILL)
    self.tabs:DockMargin(5, 5, 5, 5)

    -- Create tabs
    self:CreateProgramLockTab()
    self:CreateProgramKeyTab()
    self:CreateAddKeyingTab()
    self:CreateRenameTab()
    self:CreateViewKeyingsTab()
end

function PANEL:SetStation(station)
    self.station = station
    self:RefreshInventory()
end

function PANEL:RefreshInventory()
    -- Cache inventory items ONCE instead of 6+ GetItems() calls
    local character = LocalPlayer():GetCharacter()
    if not character then return end

    local inventory = character:GetInventory()
    if not inventory then return end

    local cachedItems = inventory:GetItems()

    -- Refresh item lists in all tabs using cached items
    if self.blankLockList then self:PopulateBlankLocks(self.blankLockList, cachedItems) end
    if self.blankKeyList then self:PopulateBlankKeys(self.blankKeyList, cachedItems) end
    if self.sourceList then self:PopulateSources(self.sourceList, cachedItems) end
    if self.lockListForKeying then self:PopulateLocks(self.lockListForKeying, cachedItems) end
    if self.keyListForKeying then self:PopulateKeys(self.keyListForKeying, cachedItems) end
    if self.renameList then self:PopulateRenamable(self.renameList, cachedItems) end
    if self.viewLockList then self:PopulateLocks(self.viewLockList, cachedItems) end
end

-- ============================================================================
-- PROGRAM LOCK TAB
-- ============================================================================

function PANEL:CreateProgramLockTab()
    local panel = vgui.Create("DPanel")
    panel:SetBackgroundColor(Color(40, 40, 40))

    local label = vgui.Create("DLabel", panel)
    label:SetPos(10, 10)
    label:SetSize(400, 20)
    label:SetText("Select a blank lock to program:")

    self.blankLockList = vgui.Create("DListView", panel)
    self.blankLockList:SetPos(10, 35)
    self.blankLockList:SetSize(400, 200)
    self.blankLockList:AddColumn("Blank Locks")
    self.blankLockList:SetMultiSelect(false)

    local btn = vgui.Create("DButton", panel)
    btn:SetPos(10, 245)
    btn:SetSize(400, 30)
    btn:SetText("Program Lock")
    btn.DoClick = function()
        local selected = self.blankLockList:GetSelectedLine()
        if not selected then return end

        local data = self.blankLockList:GetLine(selected)
        if not data then return end

        local itemID = data.itemID
        if not itemID then return end

        net.Start("ixLocksmithProgramLock")
            net.WriteEntity(self.station)
            net.WriteUInt(itemID, 32)
        net.SendToServer()

        timer.Simple(0.5, function()
            if IsValid(self) then
                self:RefreshInventory()
            end
        end)
    end

    self.tabs:AddSheet("Program Lock", panel, "icon16/lock_add.png")
end

function PANEL:PopulateBlankLocks(listView, cachedItems)
    listView:Clear()

    -- Use cached items if provided, otherwise fetch (fallback for direct calls)
    local items = cachedItems
    if not items then
        local character = LocalPlayer():GetCharacter()
        if not character then return end
        local inventory = character:GetInventory()
        if not inventory then return end
        items = inventory:GetItems()
    end

    for _, item in pairs(items) do
        if item.uniqueID == "lock_blank" then
            local quantity = item:GetData("quantity", 1)
            local line = listView:AddLine("Blank Lock (x" .. quantity .. ")")
            line.itemID = item:GetID()
        end
    end
end

-- ============================================================================
-- PROGRAM KEY TAB
-- ============================================================================

function PANEL:CreateProgramKeyTab()
    local panel = vgui.Create("DPanel")
    panel:SetBackgroundColor(Color(40, 40, 40))

    local label1 = vgui.Create("DLabel", panel)
    label1:SetPos(10, 10)
    label1:SetSize(200, 20)
    label1:SetText("Select a blank key:")

    self.blankKeyList = vgui.Create("DListView", panel)
    self.blankKeyList:SetPos(10, 35)
    self.blankKeyList:SetSize(200, 150)
    self.blankKeyList:AddColumn("Blank Keys")
    self.blankKeyList:SetMultiSelect(false)

    local label2 = vgui.Create("DLabel", panel)
    label2:SetPos(220, 10)
    label2:SetSize(200, 20)
    label2:SetText("Select source (lock or key):")

    self.sourceList = vgui.Create("DListView", panel)
    self.sourceList:SetPos(220, 35)
    self.sourceList:SetSize(200, 150)
    self.sourceList:AddColumn("Source")
    self.sourceList:SetMultiSelect(false)

    local btn = vgui.Create("DButton", panel)
    btn:SetPos(10, 195)
    btn:SetSize(410, 30)
    btn:SetText("Program Key")
    btn.DoClick = function()
        local blankLine = self.blankKeyList:GetSelectedLine()
        local sourceLine = self.sourceList:GetSelectedLine()

        if not blankLine or not sourceLine then return end

        local blankData = self.blankKeyList:GetLine(blankLine)
        local sourceData = self.sourceList:GetLine(sourceLine)

        if not blankData or not sourceData then return end

        net.Start("ixLocksmithProgramKey")
            net.WriteEntity(self.station)
            net.WriteUInt(blankData.itemID, 32)
            net.WriteUInt(sourceData.itemID, 32)
        net.SendToServer()

        timer.Simple(0.5, function()
            if IsValid(self) then
                self:RefreshInventory()
            end
        end)
    end

    self.tabs:AddSheet("Program Key", panel, "icon16/key_add.png")
end

function PANEL:PopulateBlankKeys(listView, cachedItems)
    listView:Clear()

    local items = cachedItems
    if not items then
        local character = LocalPlayer():GetCharacter()
        if not character then return end
        local inventory = character:GetInventory()
        if not inventory then return end
        items = inventory:GetItems()
    end

    for _, item in pairs(items) do
        if item.uniqueID == "key_blank" then
            local quantity = item:GetData("quantity", 1)
            local line = listView:AddLine("Blank Key (x" .. quantity .. ")")
            line.itemID = item:GetID()
        end
    end
end

function PANEL:PopulateSources(listView, cachedItems)
    listView:Clear()

    local items = cachedItems
    if not items then
        local character = LocalPlayer():GetCharacter()
        if not character then return end
        local inventory = character:GetInventory()
        if not inventory then return end
        items = inventory:GetItems()
    end

    for _, item in pairs(items) do
        if item.uniqueID == "lock" then
            local keyings = item:GetData("keyings", {})
            if #keyings > 0 then
                local name = item:GetData("lockName", "")
                if name == "" then name = "Lock [" .. #keyings .. " keyings]" end
                local line = listView:AddLine(name)
                line.itemID = item:GetID()
            end
        elseif item.uniqueID == "key" then
            local keying = item:GetData("keying", "")
            if keying ~= "" then
                local name = item:GetData("keyName", "")
                if name == "" then name = "Key [" .. keying .. "]" end
                local line = listView:AddLine(name)
                line.itemID = item:GetID()
            end
        end
    end
end

-- ============================================================================
-- ADD KEYING TAB
-- ============================================================================

function PANEL:CreateAddKeyingTab()
    local panel = vgui.Create("DPanel")
    panel:SetBackgroundColor(Color(40, 40, 40))

    local label1 = vgui.Create("DLabel", panel)
    label1:SetPos(10, 10)
    label1:SetSize(200, 20)
    label1:SetText("Select lock:")

    self.lockListForKeying = vgui.Create("DListView", panel)
    self.lockListForKeying:SetPos(10, 35)
    self.lockListForKeying:SetSize(200, 150)
    self.lockListForKeying:AddColumn("Lock")
    self.lockListForKeying:SetMultiSelect(false)

    local label2 = vgui.Create("DLabel", panel)
    label2:SetPos(220, 10)
    label2:SetSize(200, 20)
    label2:SetText("Select key to add:")

    self.keyListForKeying = vgui.Create("DListView", panel)
    self.keyListForKeying:SetPos(220, 35)
    self.keyListForKeying:SetSize(200, 150)
    self.keyListForKeying:AddColumn("Key")
    self.keyListForKeying:SetMultiSelect(false)

    local btn = vgui.Create("DButton", panel)
    btn:SetPos(10, 195)
    btn:SetSize(410, 30)
    btn:SetText("Add Keying to Lock")
    btn.DoClick = function()
        local lockLine = self.lockListForKeying:GetSelectedLine()
        local keyLine = self.keyListForKeying:GetSelectedLine()

        if not lockLine or not keyLine then return end

        local lockData = self.lockListForKeying:GetLine(lockLine)
        local keyData = self.keyListForKeying:GetLine(keyLine)

        if not lockData or not keyData then return end

        net.Start("ixLocksmithAddKeying")
            net.WriteEntity(self.station)
            net.WriteUInt(lockData.itemID, 32)
            net.WriteUInt(keyData.itemID, 32)
        net.SendToServer()

        timer.Simple(0.5, function()
            if IsValid(self) then
                self:RefreshInventory()
            end
        end)
    end

    self.tabs:AddSheet("Add Keying", panel, "icon16/link_add.png")
end

function PANEL:PopulateLocks(listView, cachedItems)
    listView:Clear()

    local items = cachedItems
    if not items then
        local character = LocalPlayer():GetCharacter()
        if not character then return end
        local inventory = character:GetInventory()
        if not inventory then return end
        items = inventory:GetItems()
    end

    for _, item in pairs(items) do
        if item.uniqueID == "lock" then
            local keyings = item:GetData("keyings", {})
            local name = item:GetData("lockName", "")
            if name == "" then name = "Lock [" .. #keyings .. "/3 keyings]" end
            local line = listView:AddLine(name)
            line.itemID = item:GetID()
        end
    end
end

function PANEL:PopulateKeys(listView, cachedItems)
    listView:Clear()

    local items = cachedItems
    if not items then
        local character = LocalPlayer():GetCharacter()
        if not character then return end
        local inventory = character:GetInventory()
        if not inventory then return end
        items = inventory:GetItems()
    end

    for _, item in pairs(items) do
        if item.uniqueID == "key" then
            local keying = item:GetData("keying", "")
            if keying ~= "" then
                local name = item:GetData("keyName", "")
                if name == "" then name = "Key [" .. keying .. "]" end
                local line = listView:AddLine(name)
                line.itemID = item:GetID()
            end
        end
    end
end

-- ============================================================================
-- RENAME TAB
-- ============================================================================

function PANEL:CreateRenameTab()
    local panel = vgui.Create("DPanel")
    panel:SetBackgroundColor(Color(40, 40, 40))

    local label = vgui.Create("DLabel", panel)
    label:SetPos(10, 10)
    label:SetSize(400, 20)
    label:SetText("Select lock or key to rename (one-time only):")

    self.renameList = vgui.Create("DListView", panel)
    self.renameList:SetPos(10, 35)
    self.renameList:SetSize(400, 140)
    self.renameList:AddColumn("Item")
    self.renameList:SetMultiSelect(false)

    local labelName = vgui.Create("DLabel", panel)
    labelName:SetPos(10, 185)
    labelName:SetSize(100, 20)
    labelName:SetText("New Name:")

    self.renameEntry = vgui.Create("DTextEntry", panel)
    self.renameEntry:SetPos(80, 185)
    self.renameEntry:SetSize(330, 25)
    self.renameEntry:SetPlaceholderText("Enter name (max 32 chars)")

    local btn = vgui.Create("DButton", panel)
    btn:SetPos(10, 220)
    btn:SetSize(400, 30)
    btn:SetText("Rename")
    btn.DoClick = function()
        local selected = self.renameList:GetSelectedLine()
        if not selected then return end

        local data = self.renameList:GetLine(selected)
        if not data then return end

        local newName = self.renameEntry:GetValue()
        if newName == "" then return end

        net.Start("ixLocksmithRename")
            net.WriteEntity(self.station)
            net.WriteUInt(data.itemID, 32)
            net.WriteString(newName)
        net.SendToServer()

        self.renameEntry:SetValue("")

        timer.Simple(0.5, function()
            if IsValid(self) then
                self:RefreshInventory()
            end
        end)
    end

    self.tabs:AddSheet("Rename", panel, "icon16/pencil.png")
end

function PANEL:PopulateRenamable(listView, cachedItems)
    listView:Clear()

    local items = cachedItems
    if not items then
        local character = LocalPlayer():GetCharacter()
        if not character then return end
        local inventory = character:GetInventory()
        if not inventory then return end
        items = inventory:GetItems()
    end

    for _, item in pairs(items) do
        if item.uniqueID == "lock" then
            local name = item:GetData("lockName", "")
            if name == "" then
                local keyings = item:GetData("keyings", {})
                local displayName = "Lock [" .. #keyings .. " keyings] - (unnamed)"
                local line = listView:AddLine(displayName)
                line.itemID = item:GetID()
            end
        elseif item.uniqueID == "key" then
            local name = item:GetData("keyName", "")
            if name == "" then
                local keying = item:GetData("keying", "")
                if keying ~= "" then
                    local displayName = "Key [" .. keying .. "] - (unnamed)"
                    local line = listView:AddLine(displayName)
                    line.itemID = item:GetID()
                end
            end
        end
    end
end

-- ============================================================================
-- VIEW KEYINGS TAB
-- ============================================================================

function PANEL:CreateViewKeyingsTab()
    local panel = vgui.Create("DPanel")
    panel:SetBackgroundColor(Color(40, 40, 40))

    local label = vgui.Create("DLabel", panel)
    label:SetPos(10, 10)
    label:SetSize(400, 20)
    label:SetText("Select lock to view its keyings:")

    self.viewLockList = vgui.Create("DListView", panel)
    self.viewLockList:SetPos(10, 35)
    self.viewLockList:SetSize(400, 180)
    self.viewLockList:AddColumn("Lock")
    self.viewLockList:SetMultiSelect(false)

    local btn = vgui.Create("DButton", panel)
    btn:SetPos(10, 225)
    btn:SetSize(400, 30)
    btn:SetText("View Keyings")
    btn.DoClick = function()
        local selected = self.viewLockList:GetSelectedLine()
        if not selected then return end

        local data = self.viewLockList:GetLine(selected)
        if not data then return end

        net.Start("ixLocksmithViewKeyings")
            net.WriteEntity(self.station)
            net.WriteUInt(data.itemID, 32)
        net.SendToServer()
    end

    self.tabs:AddSheet("View Keyings", panel, "icon16/magnifier.png")
end

-- ============================================================================
-- CLOSE HANDLING
-- ============================================================================

function PANEL:OnRemove()
    if IsValid(self.station) then
        net.Start("ixLocksmithClose")
            net.WriteEntity(self.station)
        net.SendToServer()
    end
end

function PANEL:Think()
    -- Close if too far from station
    if IsValid(self.station) then
        local dist = LocalPlayer():GetPos():Distance(self.station:GetPos())
        if dist > 200 then
            self:Remove()
        end
    end
end

vgui.Register("ixLocksmithMenu", PANEL, "DFrame")
