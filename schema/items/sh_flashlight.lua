--[[
    Flashlight

    A portable flashlight with a single battery slot.
    Accepts batteries of any charge level (0-100up).
    Drains ~0.167up per second when on (~10 minutes per full battery).

    Batteries not included when purchased.
]]--

ITEM.name = "Flashlight"
ITEM.description = "A portable flashlight. Can be used as a makeshift weapon."
ITEM.model = "models/shaky/weapons/flashlight/w_flashlight.mdl"
ITEM.width = 1
ITEM.height = 2
ITEM.category = "Equipment"
ITEM.noBusiness = true

-- Battery slot configuration
ITEM.maxBatteries = 1

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetBatteries()
    return self:GetData("batteries", {})
end

function ITEM:SetBatteries(batteries)
    self:SetData("batteries", batteries)
end

function ITEM:GetBatteryCount()
    return #self:GetBatteries()
end

function ITEM:HasBattery()
    return self:GetBatteryCount() > 0
end

function ITEM:HasUsableCharge()
    local batteries = self:GetBatteries()
    for _, charge in ipairs(batteries) do
        if charge > 0 then
            return true
        end
    end
    return false
end

function ITEM:GetFirstBatteryCharge()
    local batteries = self:GetBatteries()
    return batteries[1] or 0
end

-- Find the highest charged battery in inventory (any charge level for flashlight)
function ITEM:FindBestBatteryInInventory(inventory)
    local bestBattery = nil
    local bestCharge = -1

    for _, invItem in pairs(inventory:GetItems()) do
        if invItem.uniqueID == "battery" then
            local charge = invItem:GetData("charge", 100)
            if charge > bestCharge then
                bestCharge = charge
                bestBattery = invItem
            end
        end
    end

    return bestBattery, bestCharge
end

-- Auto-eject depleted batteries if enabled
function ITEM:AutoEjectDepleted(client)
    if not ix.option.Get(client, "batteryAutoEject", true) then
        return false
    end

    local batteries = self:GetBatteries()
    local character = client:GetCharacter()
    if not character then return false end

    local inventory = character:GetInventory()
    if not inventory then return false end

    local ejected = false

    -- Check for 0up batteries and eject them
    for i = #batteries, 1, -1 do
        if batteries[i] <= 0 then
            -- Check if inventory has room
            if inventory:FindEmptySlot(1, 1) then
                inventory:Add("battery", 1, {charge = 0})
                table.remove(batteries, i)
                ejected = true
            end
        end
    end

    if ejected then
        self:SetBatteries(batteries)
        client:NotifyLocalized("flashlightBatteryEjected")
    end

    return ejected
end

-- Auto-load battery from inventory if enabled
function ITEM:AutoLoadFromInventory(client)
    if not ix.option.Get(client, "batteryAutoLoad", true) then
        return false
    end

    local batteries = self:GetBatteries()
    if #batteries >= self.maxBatteries then
        return false
    end

    local character = client:GetCharacter()
    if not character then return false end

    local inventory = character:GetInventory()
    if not inventory then return false end

    local bestBattery, bestCharge = self:FindBestBatteryInInventory(inventory)
    if not bestBattery or bestCharge <= 0 then
        return false
    end

    -- Load the battery
    table.insert(batteries, bestCharge)
    self:SetBatteries(batteries)
    bestBattery:Remove()

    client:NotifyLocalized("flashlightAutoLoaded", bestCharge)
    return true
end


-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local batteries = item:GetData("batteries", {})
        local isEquipped = item:GetData("equipped")

        -- Draw equipped indicator (green dot)
        if isEquipped then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end

        -- Draw battery bar if battery present
        if #batteries > 0 then
            local charge = batteries[1]

            -- Background bar
            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(4, h - 12, w - 8, 8)

            -- Charge fill with granular colors
            local chargeWidth = ((w - 8) / 100) * charge
            local color

            if charge >= 50 then
                color = Color(50, 200, 50)      -- GREEN
            elseif charge >= 25 then
                color = Color(200, 200, 50)     -- YELLOW
            elseif charge >= 10 then
                color = Color(255, 150, 50)     -- ORANGE
            elseif charge >= 1 then
                color = Color(200, 50, 50)      -- RED
            else
                color = Color(30, 30, 30)       -- BLACK (0up - depleted)
            end

            surface.SetDrawColor(color)
            surface.DrawRect(4, h - 12, chargeWidth, 8)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local batteries = self:GetData("batteries", {})

        local batteryRow = tooltip:AddRow("battery")

        if #batteries == 0 then
            batteryRow:SetText("No battery inserted.")
            batteryRow:SetBackgroundColor(Color(100, 100, 100))
        else
            local charge = batteries[1]
            batteryRow:SetText(string.format("Battery: %dup / 100up", charge))

            if charge >= 50 then
                batteryRow:SetBackgroundColor(Color(50, 100, 50))      -- Good
            elseif charge >= 25 then
                batteryRow:SetBackgroundColor(Color(100, 100, 50))     -- Moderate
            elseif charge >= 10 then
                batteryRow:SetBackgroundColor(Color(150, 100, 50))     -- Low
            elseif charge >= 1 then
                batteryRow:SetBackgroundColor(Color(150, 50, 50))      -- Critical
            else
                batteryRow:SetBackgroundColor(Color(60, 60, 60))       -- Depleted
            end
        end

        batteryRow:SizeToContents()
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Load Battery: Dropdown of batteries in inventory
ITEM.functions.LoadBattery = {
    name = "Load Battery",
    tip = "Insert a battery into the flashlight.",
    icon = "icon16/lightning_add.png",
    isMulti = true,
    multiOptions = function(item, client)
        local options = {}
        local character = client:GetCharacter()
        if not character then return options end

        local inventory = character:GetInventory()
        if not inventory then return options end

        local filterEmpty = ix.option.Get(client, "batteryFilterEmpty", true)

        for _, invItem in pairs(inventory:GetItems()) do
            if invItem.uniqueID == "battery" then
                local charge = invItem:GetData("charge", 100)

                -- Filter out 0up batteries if setting enabled
                if not filterEmpty or charge > 0 then
                    table.insert(options, {
                        name = string.format("Battery (%dup)", charge),
                        data = {batteryID = invItem:GetID()}
                    })
                end
            end
        end

        -- Sort by charge (highest first)
        table.sort(options, function(a, b)
            return tonumber(string.match(a.name, "%((%d+)up%)")) > tonumber(string.match(b.name, "%((%d+)up%)"))
        end)

        return options
    end,
    OnRun = function(item, data)
        local client = item.player
        local batteryID = data and data.batteryID

        if not batteryID then return false end

        local batteryItem = ix.item.instances[batteryID]
        if not batteryItem or batteryItem.uniqueID ~= "battery" then
            return false
        end

        local batteries = item:GetBatteries()
        if #batteries >= item.maxBatteries then
            client:NotifyLocalized("flashlightSlotFull")
            return false
        end

        -- Load the battery
        local charge = batteryItem:GetData("charge", 100)
        table.insert(batteries, charge)
        item:SetBatteries(batteries)

        -- Remove the battery item
        batteryItem:Remove()

        client:NotifyLocalized("flashlightBatteryLoaded", charge)
        client:EmitSound("items/battery_pickup.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        -- Can't load if already at max
        if item:GetBatteryCount() >= item.maxBatteries then return false end
        -- Can't load if on ground
        if IsValid(item.entity) then return false end

        -- Check if player has any batteries
        local client = item.player
        if not IsValid(client) then return false end

        local character = client:GetCharacter()
        if not character then return false end

        local inventory = character:GetInventory()
        if not inventory then return false end

        for _, invItem in pairs(inventory:GetItems()) do
            if invItem.uniqueID == "battery" then
                return true
            end
        end

        return false
    end
}

-- Eject Battery
ITEM.functions.EjectBattery = {
    name = "Eject Battery",
    tip = "Remove the battery from the flashlight.",
    icon = "icon16/lightning_delete.png",
    OnRun = function(item)
        local client = item.player
        local batteries = item:GetBatteries()

        if #batteries == 0 then
            return false
        end

        -- If equipped and light is on, turn it off first
        if item:GetData("equipped") then
            local weapon = client:GetWeapon("ix_flashlight")
            if IsValid(weapon) and weapon.GetFlashlightOn and weapon:GetFlashlightOn() then
                weapon:SetLight(false)
            end
        end

        -- Eject the first battery
        local charge = table.remove(batteries, 1)
        item:SetBatteries(batteries)

        -- Create battery item with current charge
        local character = client:GetCharacter()
        local inventory = character:GetInventory()
        inventory:Add("battery", 1, {charge = charge})

        client:NotifyLocalized("flashlightBatteryEjected")
        client:EmitSound("items/battery_pickup.wav", 50, 90)

        return false
    end,
    OnCanRun = function(item)
        -- Can't eject if no battery
        if not item:HasBattery() then return false end
        -- Can't eject if on ground
        if IsValid(item.entity) then return false end

        return true
    end
}

-- Equip: Give SWEP
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the flashlight in your hands.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing flashlight from this player
        if client.ixFlashlightItem and client.ixFlashlightItem ~= item then
            local oldItem = client.ixFlashlightItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing flashlight SWEP if any
        if client:HasWeapon("ix_flashlight") then
            client:StripWeapon("ix_flashlight")
        end

        -- Give the SWEP
        local weapon = client:Give("ix_flashlight")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_flashlight")
        end

        client.ixFlashlightItem = item
        item:SetData("equipped", true)

        client:EmitSound("items/flashlight1.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        -- Can't equip if on ground
        if IsValid(item.entity) then return false end
        -- Can't equip if already equipped
        if item:GetData("equipped") then return false end

        return true
    end
}

-- Unequip: Remove SWEP
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the flashlight away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        -- Remove SWEP
        local weapon = client:GetWeapon("ix_flashlight")
        if IsValid(weapon) then
            -- Turn off light first
            if weapon.SetLight then
                weapon:SetLight(false)
            end
            client:StripWeapon("ix_flashlight")
        end

        client.ixFlashlightItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("items/flashlight1.wav", 50, 90)

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equipped") == true
    end
}

-- ============================================================================
-- HOOKS
-- ============================================================================

-- Turn off and unequip when dropped
function ITEM.postHooks.drop(item, result)
    if item:GetData("equipped") then
        local client = item:GetOwner()
        if IsValid(client) then
            local weapon = client:GetWeapon("ix_flashlight")
            if IsValid(weapon) then
                if weapon.SetLight then
                    weapon:SetLight(false)
                end
                client:StripWeapon("ix_flashlight")
            end
            client.ixFlashlightItem = nil
        end
        item:SetData("equipped", nil)
    end
end

-- Handle transfer (same as drop)
function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            local weapon = oldOwner:GetWeapon("ix_flashlight")
            if IsValid(weapon) then
                if weapon.SetLight then
                    weapon:SetLight(false)
                end
                oldOwner:StripWeapon("ix_flashlight")
            end
            oldOwner.ixFlashlightItem = nil
        end
        self:SetData("equipped", nil)
    end
end

-- Can't transfer while equipped
function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("flashlightEquipped")
        end
        return false
    end
    return true
end

-- Restore equipped state on character load
function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_flashlight", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixFlashlightItem = self

            -- Ensure light is off on loadout (prevents battery drain from previous session)
            if weapon.SetLight then
                weapon:SetLight(false)
            end
        end
    end
end
