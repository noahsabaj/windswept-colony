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

local function getInventoryItems(cachedItems)
    if cachedItems then return cachedItems end
    local _, inventory = ws.constants.GetCharacterInventory(LocalPlayer())
    if not inventory then return nil end
    return inventory:GetItems()
end

-- Creates a DListView with standard styling, single column, and single-select.
local function CreateItemListView(parent, label, x, y, w, h)
    local listView = vgui.Create("DListView", parent)
    listView:SetPos(x, y)
    listView:SetSize(w, h)
    listView:AddColumn(label)
    listView:SetMultiSelect(false)
    return listView
end

-- Creates a DButton that sends a net message with station entity + item ID (UInt 32).
-- getItemIDFn() should return an item ID or nil to abort.
-- refreshFn is called after a 0.5s delay if provided.
local function CreateNetButton(parent, text, x, y, w, h, panelRef, netMsg, getItemIDFn, refreshFn)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText(text)
    btn.DoClick = function()
        local itemID = getItemIDFn()
        if not itemID then return end

        ws.action.Send(netMsg, nil, panelRef.station, function()
            net.WriteUInt(itemID, 32)
        end)

        if refreshFn then
            timer.Simple(0.5, function()
                if IsValid(panelRef) then
                    refreshFn()
                end
            end)
        end
    end
    return btn
end

-- Helper to get selected item ID from a DListView, or nil if nothing is selected.
local function GetSelectedItemID(listView)
    local selected = listView:GetSelectedLine()
    if not selected then return nil end

    local data = listView:GetLine(selected)
    if not data then return nil end

    return data.itemID
end

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
    local character, inventory = ws.constants.GetCharacterInventory(LocalPlayer())
    if not character or not inventory then return end

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

    self.blankLockList = CreateItemListView(panel, "Blank Locks", 10, 35, 400, 200)

    CreateNetButton(panel, "Program Lock", 10, 245, 400, 30, self,
        "wsLocksmithProgramLock",
        function() return GetSelectedItemID(self.blankLockList) end,
        function() self:RefreshInventory() end
    )

    self.tabs:AddSheet("Program Lock", panel, "icon16/lock_add.png")
end

function PANEL:PopulateBlankLocks(listView, cachedItems)
    listView:Clear()

    local items = getInventoryItems(cachedItems)
    if not items then return end

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

    self.blankKeyList = CreateItemListView(panel, "Blank Keys", 10, 35, 200, 150)

    local label2 = vgui.Create("DLabel", panel)
    label2:SetPos(220, 10)
    label2:SetSize(200, 20)
    label2:SetText("Select source (lock or key):")

    self.sourceList = CreateItemListView(panel, "Source", 220, 35, 200, 150)

    local btn = vgui.Create("DButton", panel)
    btn:SetPos(10, 195)
    btn:SetSize(410, 30)
    btn:SetText("Program Key")
    btn.DoClick = function()
        local blankItemID = GetSelectedItemID(self.blankKeyList)
        local sourceItemID = GetSelectedItemID(self.sourceList)

        if not blankItemID or not sourceItemID then return end

        ws.action.Send("wsLocksmithProgramKey", nil, self.station, function()
            net.WriteUInt(blankItemID, 32)
            net.WriteUInt(sourceItemID, 32)
        end)

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

    local items = getInventoryItems(cachedItems)
    if not items then return end

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

    local items = getInventoryItems(cachedItems)
    if not items then return end

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

    self.lockListForKeying = CreateItemListView(panel, "Lock", 10, 35, 200, 150)

    local label2 = vgui.Create("DLabel", panel)
    label2:SetPos(220, 10)
    label2:SetSize(200, 20)
    label2:SetText("Select key to add:")

    self.keyListForKeying = CreateItemListView(panel, "Key", 220, 35, 200, 150)

    local btn = vgui.Create("DButton", panel)
    btn:SetPos(10, 195)
    btn:SetSize(410, 30)
    btn:SetText("Add Keying to Lock")
    btn.DoClick = function()
        local lockItemID = GetSelectedItemID(self.lockListForKeying)
        local keyItemID = GetSelectedItemID(self.keyListForKeying)

        if not lockItemID or not keyItemID then return end

        ws.action.Send("wsLocksmithAddKeying", nil, self.station, function()
            net.WriteUInt(lockItemID, 32)
            net.WriteUInt(keyItemID, 32)
        end)

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

    local items = getInventoryItems(cachedItems)
    if not items then return end

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

    local items = getInventoryItems(cachedItems)
    if not items then return end

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

    self.renameList = CreateItemListView(panel, "Item", 10, 35, 400, 140)

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
        local itemID = GetSelectedItemID(self.renameList)
        if not itemID then return end

        local newName = self.renameEntry:GetValue()
        if newName == "" then return end

        ws.action.Send("wsLocksmithRename", nil, self.station, function()
            net.WriteUInt(itemID, 32)
            net.WriteString(newName)
        end)

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

    local items = getInventoryItems(cachedItems)
    if not items then return end

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

    self.viewLockList = CreateItemListView(panel, "Lock", 10, 35, 400, 180)

    CreateNetButton(panel, "View Keyings", 10, 225, 400, 30, self,
        "wsLocksmithViewKeyings",
        function() return GetSelectedItemID(self.viewLockList) end,
        nil
    )

    self.tabs:AddSheet("View Keyings", panel, "icon16/magnifier.png")
end

-- ============================================================================
-- CLOSE HANDLING
-- ============================================================================

function PANEL:OnRemove()
    if IsValid(self.station) then
        ws.action.Send("wsLocksmithClose", nil, self.station)
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

vgui.Register("wsLocksmithMenu", PANEL, "DFrame")
