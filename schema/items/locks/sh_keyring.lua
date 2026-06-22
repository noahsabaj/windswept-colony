--[[
    Key Ring

    A ring that holds up to 20 keys.
    - Only keys can be stored (using container restriction system)
    - When equipped, press R to cycle through keys
    - Displays current key's name/keying
]]--

ITEM.name = "Key Ring"
ITEM.description = "A ring for holding multiple keys."
ITEM.model = "models/props_c17/tools_wrench01a.mdl"
ITEM.category = "Keys & Locks"
ITEM.base = "base_container"
ITEM.width = 1
ITEM.height = 1
ITEM.invWidth = 5
ITEM.invHeight = 4

ITEM.inventoryFlag = "isKeyRing"
ITEM.allowedItemType = "key"
ITEM.allowedItemNotify = "keyringOnlyKeys"
ITEM.viewSuffix = " - Keys"

ITEM.class = "ws_keyring"
ITEM.weaponCategory = "keyring"

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetKeys()
    local inv = self:GetInventory()
    if not inv then return {} end

    local keys = inv:GetItemsByUniqueID("key", false)

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
    function ITEM:PaintOverExtra(w, h)
        local isEquipped = self:GetData("equipped")

        if isEquipped then
            ws.constants.DrawEquippedIndicator(w, h)
        end

        local keys = self:GetKeys()
        local count = #keys

        if count > 0 then
            local text = tostring(count)
            surface.SetFont("wsSmallFont")
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

        local bgColor = #keys >= 18 and Color(150, 100, 50) or (#keys > 0 and Color(50, 80, 100) or Color(100, 100, 100))
        ws.constants.AddTooltipRow(tooltip, "keys", string.format("Keys: %d / 20", #keys), bgColor)

        if self:GetData("equipped") then
            local currentKey = self:GetCurrentKey()
            if currentKey then
                local keyName = currentKey:GetData("keyName", "") ~= "" and currentKey:GetData("keyName") or currentKey:GetData("keying", "Unknown")
                ws.constants.AddTooltipRow(tooltip, "current", "Selected: " .. keyName, Color(60, 100, 60))
            end
        end
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Override View with custom name
ITEM.functions.View = {
    name = "Manage Keys",
    tip = "Add or remove keys from the ring.",
    icon = "icon16/folder.png",
    OnClick = ws.constants.OpenContainerPanel,
    OnCanRun = ws.constants.CanOpenContainerPanel
}

-- Equip keyring
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the keyring. Press R to cycle keys.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        if client.wsKeyringItem and client.wsKeyringItem ~= item then
            local oldItem = client.wsKeyringItem
            oldItem:SetData("equipped", nil)
        end

        if client:HasWeapon("ws_keyring") then
            client:StripWeapon("ws_keyring")
        end

        client.wsKeyringItem = item
        item:SetData("equipped", true)

        local weapon = client:Give("ws_keyring")
        if IsValid(weapon) then
            weapon.wsItem = item
            client:SelectWeapon("ws_keyring")
        end

        client:EmitSound("physics/metal/metal_solid_impact_soft2.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        if item:GetKeyCount() == 0 then return false end
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

        if client:HasWeapon("ws_keyring") then
            client:StripWeapon("ws_keyring")
        end

        client.wsKeyringItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/metal/metal_solid_impact_soft2.wav", 50, 90)

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equipped") == true
    end
}

-- ============================================================================
-- CONTAINER HOOKS (extra behavior for equipped state)
-- ============================================================================

function ITEM:OnDropExtra()
    if self:GetData("equipped") then
        local client = self:GetOwner()
        if IsValid(client) then
            if client:HasWeapon("ws_keyring") then
                client:StripWeapon("ws_keyring")
            end
            client.wsKeyringItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransferExtra(oldInventory, newInventory)
    if self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("keyringEquipped")
        end
        return false
    end
end

function ITEM:OnTransferExtra(curInv, inventory)
    if self:GetData("equipped") then
        local oldOwner = curInv and curInv.GetOwner and curInv:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ws_keyring") then
                oldOwner:StripWeapon("ws_keyring")
            end
            oldOwner.wsKeyringItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ws_keyring", true)
        if IsValid(weapon) then
            weapon.wsItem = self
            client.wsKeyringItem = self
        end
    end
end
