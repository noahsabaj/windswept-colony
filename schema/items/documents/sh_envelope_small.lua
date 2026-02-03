--[[
    Small Envelope

    A small envelope for storing a few papers.
    Capacity: 5 papers (5x1 grid)
    Only paper items can be stored inside.
]]--

ITEM.name = "Small Envelope"
ITEM.description = "A small paper envelope for documents."
ITEM.model = "models/props_c17/paper01.mdl"  -- Placeholder
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Containers"

ITEM.isBag = true
ITEM.invWidth = 5
ITEM.invHeight = 1

-- ============================================================================
-- BAG SYSTEM (required for inventory to work)
-- ============================================================================

-- Called when a new instance of this item has been made
function ITEM:OnInstanced(invID, x, y)
    local inventory = ix.item.inventories[invID]

    ix.inventory.New(inventory and inventory.owner or 0, self.uniqueID, function(inv)
        local client = inv:GetOwner()

        inv.vars.isBag = self.uniqueID
        inv.vars.isDocumentContainer = true
        self:SetData("id", inv:GetID())

        if IsValid(client) then
            inv:AddReceiver(client)
        end
    end)
end

function ITEM:GetInventory()
    local index = self:GetData("id")
    if index then
        return ix.item.inventories[index]
    end
end

ITEM.GetInv = ITEM.GetInventory

-- Called when the item first appears for a client
function ITEM:OnSendData()
    local index = self:GetData("id")

    if index then
        local inventory = ix.item.inventories[index]

        if inventory then
            inventory.vars.isBag = self.uniqueID
            inventory.vars.isDocumentContainer = true
            inventory:Sync(self.player)
            inventory:AddReceiver(self.player)
        else
            local owner = self.player:GetCharacter():GetID()

            ix.inventory.Restore(self:GetData("id"), self.invWidth, self.invHeight, function(inv)
                inv.vars.isBag = self.uniqueID
                inv.vars.isDocumentContainer = true
                inv:SetOwner(owner, true)

                if not inv.owner then
                    return
                end

                for client, character in ix.util.GetCharacters() do
                    if character:GetID() == inv.owner then
                        inv:AddReceiver(client)
                        break
                    end
                end
            end)
        end
    else
        ix.inventory.New(self.player:GetCharacter():GetID(), self.uniqueID, function(inv)
            inv.vars.isDocumentContainer = true
            self:SetData("id", inv:GetID())
        end)
    end
end

function ITEM.postHooks.drop(item, result)
    local index = item:GetData("id")

    local query = mysql:Update("ix_inventories")
        query:Update("character_id", 0)
        query:Where("inventory_id", index)
    query:Execute()

    if SERVER then
        net.Start("ixBagDrop")
            net.WriteUInt(index, 32)
        net.Send(item.player)
    end
end

function ITEM:OnRemoved()
    local index = self:GetData("id")

    if index then
        -- Delete contained papers' document files
        local inv = ix.item.inventories[index]
        if inv then
            for _, containedItem in pairs(inv:GetItems()) do
                if containedItem.uniqueID == "paper" then
                    local paperID = containedItem:GetPaperID()
                    if paperID then
                        ix.documents.Delete(paperID)
                    end
                end
            end
        end

        local query = mysql:Delete("ix_items")
            query:Where("inventory_id", index)
        query:Execute()

        query = mysql:Delete("ix_inventories")
            query:Where("inventory_id", index)
        query:Execute()
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    local index = self:GetData("id")

    if newInventory then
        -- Bags can't go into other bags
        if newInventory.vars and newInventory.vars.isBag then
            return false
        end

        local index2 = newInventory:GetID()

        if index == index2 then
            return false
        end

        -- Check for circular references
        local bagInv = self:GetInventory()
        if bagInv then
            for k, _ in bagInv:Iter() do
                if k:GetData("id") == index2 then
                    return false
                end
            end
        end
    end

    return not newInventory or newInventory:GetID() ~= oldInventory:GetID() or newInventory.vars.isBag
end

function ITEM:OnTransferred(curInv, inventory)
    local bagInventory = self:GetInventory()
    if not bagInventory then return end

    if isfunction(curInv.GetOwner) then
        local owner = curInv:GetOwner()
        if IsValid(owner) then
            bagInventory:RemoveReceiver(owner)
        end
    end

    if isfunction(inventory.GetOwner) then
        local owner = inventory:GetOwner()
        if IsValid(owner) then
            bagInventory:AddReceiver(owner)
            bagInventory:SetOwner(owner)
        end
    else
        bagInventory:SetOwner(nil)
    end
end

function ITEM:OnRegistered()
    ix.inventory.Register(self.uniqueID, self.invWidth, self.invHeight, true)
end

-- ============================================================================
-- NAME OVERRIDE
-- ============================================================================

function ITEM:GetName()
    local customName = self:GetData("customName")
    if customName and customName ~= "" then
        return customName
    end
    return self.name
end

-- ============================================================================
-- DESCRIPTION
-- ============================================================================

function ITEM:GetDescription()
    local desc = self.description
    local invID = self:GetData("id")

    if invID then
        local inv = ix.item.inventories[invID]
        if inv then
            local count = 0
            for _ in pairs(inv:GetItems()) do
                count = count + 1
            end
            desc = desc .. string.format("\n\nContains: %d paper(s)", count)
        end
    end

    return desc
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local panel = ix.gui["inv" .. item:GetData("id", "")]

        if IsValid(panel) and vgui.GetHoveredPanel() == self then
            panel:SetHighlighted(true)
        elseif IsValid(panel) then
            panel:SetHighlighted(false)
        end
    end

    net.Receive("ixBagDrop", function()
        local index = net.ReadUInt(32)
        local panel = ix.gui["inv"..index]

        if panel and panel:IsVisible() then
            panel:Close()
        end
    end)
end

-- ============================================================================
-- RENAME FUNCTION (requires pen/pencil in inventory)
-- ============================================================================

-- Helper to check for writing tool in inventory
local function hasWritingTool(client)
    local char = client:GetCharacter()
    if not char then return false end

    local inv = char:GetInventory()
    if not inv then return false end

    local penTypes = {pen = true, pen_black = true, pen_red = true, pen_green = true}

    for _, invItem in pairs(inv:GetItems()) do
        if penTypes[invItem.uniqueID] and invItem:GetInk() > 0 then
            return true
        elseif (invItem.uniqueID == "pencil" or invItem.uniqueID == "pencil_eraser") and invItem:GetLead() > 0 then
            return true
        end
    end

    return false
end

ITEM.functions.Rename = {
    name = "Name",
    tip = "Write a name on this envelope.",
    icon = "icon16/textfield_rename.png",
    OnRun = function(item)
        return false
    end,
    OnClick = function(item)
        local currentName = item:GetData("customName", "")

        Derma_StringRequest(
            "Name Envelope",
            "Write a name on this envelope (max 32 characters):",
            currentName,
            function(text)
                if text then
                    net.Start("ixContainerRename")
                        net.WriteUInt(item:GetID(), 32)
                        net.WriteString(string.sub(text, 1, 32))
                    net.SendToServer()
                end
            end,
            function() end,
            "Write",
            "Cancel"
        )
        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if not CLIENT then return true end

        return hasWritingTool(LocalPlayer())
    end
}

-- ============================================================================
-- VIEW FUNCTION (Helix auto-bag-open)
-- ============================================================================

ITEM.functions.View = {
    name = "Open",
    tip = "Open the envelope to view contents.",
    icon = "icon16/folder.png",
    OnClick = function(item)
        local index = item:GetData("id", "")

        if index then
            local panel = ix.gui["inv"..index]
            local inventory = ix.item.inventories[index]
            local parent = IsValid(ix.gui.menuInventoryContainer) and ix.gui.menuInventoryContainer or ix.gui.openedStorage

            if IsValid(panel) then
                panel:Remove()
            end

            if inventory and inventory.slots then
                panel = vgui.Create("ixInventory", IsValid(parent) and parent or nil)
                panel:SetInventory(inventory)
                panel:ShowCloseButton(true)
                panel:SetTitle(item:GetName())

                if parent ~= ix.gui.menuInventoryContainer then
                    panel:Center()
                    if parent == ix.gui.openedStorage then
                        panel:MakePopup()
                    end
                else
                    panel:MoveToFront()
                end

                ix.gui["inv"..index] = panel
            end
        end

        return false
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity) and item:GetData("id") and not IsValid(ix.gui["inv" .. item:GetData("id", "")])
    end
}

-- ============================================================================
-- TRANSFER RESTRICTION HOOK
-- ============================================================================

hook.Add("CanTransferItem", "ixEnvelopeSmallRestriction", function(transferItem, curInv, inventory)
    if inventory and inventory.vars and inventory.vars.isDocumentContainer then
        -- Only allow paper items
        if transferItem.uniqueID ~= "paper" then
            return false
        end
    end
end)
