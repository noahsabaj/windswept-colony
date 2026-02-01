--[[
    Key Ring

    A ring that holds up to 20 keys.
    - Only keys can be stored (using CanTransferItem hook)
    - When equipped, press R to cycle through keys
    - Displays current key's name/keying
    - Uses bag pattern from photo_album

    Pattern reference: sh_photo_album.lua
]]--

ITEM.name = "Key Ring"
ITEM.description = "A ring for holding multiple keys."
ITEM.model = "models/props_c17/tools_wrench01a.mdl"  -- Placeholder
ITEM.category = "Keys & Locks"
ITEM.width = 1
ITEM.height = 1
ITEM.invWidth = 5
ITEM.invHeight = 4  -- 20 slots total
ITEM.isBag = true
ITEM.noBusiness = true
ITEM.class = "ix_keyring"
ITEM.weaponCategory = "keyring"

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetKeys()
    local inv = self:GetInventory()
    if not inv then return {} end

    local keys = {}
    for _, item in pairs(inv:GetItems()) do
        if item.uniqueID == "key" then
            table.insert(keys, item)
        end
    end

    -- Sort by name or keying
    table.sort(keys, function(a, b)
        local nameA = a:GetData("keyName", "") ~= "" and a:GetData("keyName") or a:GetData("keying", "")
        local nameB = b:GetData("keyName", "") ~= "" and b:GetData("keyName") or b:GetData("keying", "")
        return nameA < nameB
    end)

    return keys
end

function ITEM:GetKeyCount()
    return #self:GetKeys()
end

function ITEM:GetCurrentKeyIndex()
    return self:GetData("currentKey", 1)
end

function ITEM:SetCurrentKeyIndex(index)
    local keys = self:GetKeys()
    if #keys == 0 then
        self:SetData("currentKey", 1)
        return
    end

    index = ((index - 1) % #keys) + 1
    self:SetData("currentKey", index)
end

function ITEM:GetCurrentKey()
    local keys = self:GetKeys()
    local index = self:GetCurrentKeyIndex()
    return keys[index]
end

function ITEM:CycleKey(direction)
    local index = self:GetCurrentKeyIndex()
    self:SetCurrentKeyIndex(index + (direction or 1))
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local panel = ix.gui["inv" .. item:GetData("id", "")]
        local isEquipped = item:GetData("equipped")

        if IsValid(panel) and vgui.GetHoveredPanel() == self then
            panel:SetHighlighted(true)
        elseif IsValid(panel) then
            panel:SetHighlighted(false)
        end

        -- Draw equipped indicator (green dot)
        if isEquipped then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end

        -- Show key count
        local keys = item:GetKeys()
        local count = #keys

        if count > 0 then
            local text = tostring(count)
            surface.SetFont("ixSmallFont")
            local textW, textH = surface.GetTextSize(text)

            surface.SetDrawColor(80, 80, 120, 200)
            surface.DrawRect(w - textW - 8, 2, textW + 6, textH + 2)

            surface.SetTextColor(255, 255, 255)
            surface.SetTextPos(w - textW - 5, 3)
            surface.DrawText(text)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local keys = self:GetKeys()

        local keyRow = tooltip:AddRow("keys")
        keyRow:SetText(string.format("Keys: %d / 20", #keys))

        if #keys >= 18 then
            keyRow:SetBackgroundColor(Color(150, 100, 50))
        elseif #keys > 0 then
            keyRow:SetBackgroundColor(Color(50, 80, 100))
        else
            keyRow:SetBackgroundColor(Color(100, 100, 100))
        end

        keyRow:SizeToContents()

        -- Show current key if equipped
        if self:GetData("equipped") then
            local currentKey = self:GetCurrentKey()
            if currentKey then
                local keyName = currentKey:GetData("keyName", "") ~= "" and currentKey:GetData("keyName") or currentKey:GetData("keying", "Unknown")
                local currentRow = tooltip:AddRow("current")
                currentRow:SetText("Selected: " .. keyName)
                currentRow:SetBackgroundColor(Color(60, 100, 60))
                currentRow:SizeToContents()
            end
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- View function for Helix auto-bag-open (opens standard inventory panel)
ITEM.functions.View = {
    name = "Manage Keys",
    tip = "Add or remove keys from the ring.",
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
                panel:SetTitle(item:GetName() .. " - Keys")

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

-- Equip keyring
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the keyring. Press R to cycle keys.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing keyring from this player
        if client.ixKeyringItem and client.ixKeyringItem ~= item then
            local oldItem = client.ixKeyringItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing keyring SWEP if any
        if client:HasWeapon("ix_keyring") then
            client:StripWeapon("ix_keyring")
        end

        -- Set these BEFORE Give() so hooks see them
        client.ixKeyringItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("ix_keyring")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_keyring")
        end

        client:EmitSound("physics/metal/metal_solid_impact_soft2.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        if item:GetKeyCount() == 0 then return false end  -- Need at least one key
        return true
    end
}

-- Unequip keyring
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the keyring away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_keyring") then
            client:StripWeapon("ix_keyring")
        end

        client.ixKeyringItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/metal/metal_solid_impact_soft2.wav", 50, 90)

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equipped") == true
    end
}

-- Combine (drag items into bag)
ITEM.functions.combine = {
    OnRun = function(item, data)
        local targetItem = ix.item.instances[data[1]]
        if not targetItem then return false end

        -- Only allow keys
        if targetItem.uniqueID ~= "key" then
            if item.player then
                item.player:NotifyLocalized("keyringOnlyKeys")
            end
            return false
        end

        targetItem:Transfer(item:GetData("id"), nil, nil, item.player)
        return false
    end,
    OnCanRun = function(item, data)
        local index = item:GetData("id", "")
        if index then
            local inventory = ix.item.inventories[index]
            if inventory then
                return true
            end
        end
        return false
    end
}

-- ============================================================================
-- BAG SYSTEM
-- ============================================================================

function ITEM:OnInstanced(invID, x, y)
    local inventory = ix.item.inventories[invID]

    ix.inventory.New(inventory and inventory.owner or 0, self.uniqueID, function(inv)
        local client = inv:GetOwner()

        inv.vars.isBag = self.uniqueID
        inv.vars.isKeyRing = true
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

function ITEM:OnSendData()
    local index = self:GetData("id")

    if index then
        local inventory = ix.item.inventories[index]

        if inventory then
            inventory.vars.isBag = self.uniqueID
            inventory.vars.isKeyRing = true
            inventory:Sync(self.player)
            inventory:AddReceiver(self.player)
        else
            local owner = self.player:GetCharacter():GetID()

            ix.inventory.Restore(self:GetData("id"), self.invWidth, self.invHeight, function(inv)
                inv.vars.isBag = self.uniqueID
                inv.vars.isKeyRing = true
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
            inv.vars.isKeyRing = true
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

    -- Also handle equipped state
    if item:GetData("equipped") then
        local client = item:GetOwner()
        if IsValid(client) then
            if client:HasWeapon("ix_keyring") then
                client:StripWeapon("ix_keyring")
            end
            client.ixKeyringItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnRemoved()
    local index = self:GetData("id")

    if index then
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

    -- Block if equipped
    if self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("keyringEquipped")
        end
        return false
    end

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

    -- Handle equipped state on transfer
    if self:GetData("equipped") then
        local oldOwner = curInv and curInv.GetOwner and curInv:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_keyring") then
                oldOwner:StripWeapon("ix_keyring")
            end
            oldOwner.ixKeyringItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:OnRegistered()
    ix.inventory.Register(self.uniqueID, self.invWidth, self.invHeight, true)
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_keyring", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixKeyringItem = self
        end
    end
end

-- ============================================================================
-- KEY RING RESTRICTION HOOK
-- ============================================================================

hook.Add("CanTransferItem", "ixKeyRingRestriction", function(item, curInv, inventory)
    -- Check if target inventory is a key ring
    if inventory and inventory.vars and inventory.vars.isKeyRing then
        -- Only allow key items
        if item.uniqueID ~= "key" then
            return false
        end
    end
end)
