--[[
    Lantern

    A portable lantern with ambient light.
    - Single battery slot, accepts any charge (0-100up)
    - Drains ~0.167up per second when on (~10 minutes per full battery)
    - Can be placed on the ground (RMB when equipped)
    - Placed lanterns continue to drain and emit light
    - Pick up placed lanterns by holding E

    Batteries not included.
]]--

ITEM.name = "Lantern"
ITEM.description = "A portable lantern providing ambient light. Can be placed on the ground."
ITEM.model = "models/weapons/cof/w_lantern.mdl"
ITEM.width = 1
ITEM.height = 2
ITEM.category = "Equipment"
ITEM.noBusiness = true

-- Lantern model: https://steamcommunity.com/sharedfiles/filedetails/?id=3354246770
if SERVER then
    resource.AddWorkshop("3354246770")
end

-- Battery slot configuration
ITEM.maxBatteries = 1

-- ============================================================================
-- HELPER FUNCTIONS (same as flashlight)
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

    for i = #batteries, 1, -1 do
        if batteries[i] <= 0 then
            if inventory:FindEmptySlot(1, 1) then
                inventory:Add("battery", 1, {charge = 0})
                table.remove(batteries, i)
                ejected = true
            end
        end
    end

    if ejected then
        self:SetBatteries(batteries)
        client:NotifyLocalized("lanternBatteryEjected")
    end

    return ejected
end

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

    table.insert(batteries, bestCharge)
    self:SetBatteries(batteries)
    bestBattery:Remove()

    client:NotifyLocalized("lanternAutoLoaded", bestCharge)
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
                color = Color(50, 200, 50)
            elseif charge >= 25 then
                color = Color(200, 200, 50)
            elseif charge >= 10 then
                color = Color(255, 150, 50)
            elseif charge >= 1 then
                color = Color(200, 50, 50)
            else
                color = Color(30, 30, 30)
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
                batteryRow:SetBackgroundColor(Color(50, 100, 50))
            elseif charge >= 25 then
                batteryRow:SetBackgroundColor(Color(100, 100, 50))
            elseif charge >= 10 then
                batteryRow:SetBackgroundColor(Color(150, 100, 50))
            elseif charge >= 1 then
                batteryRow:SetBackgroundColor(Color(150, 50, 50))
            else
                batteryRow:SetBackgroundColor(Color(60, 60, 60))
            end
        end

        batteryRow:SizeToContents()
    end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Load Battery
ITEM.functions.LoadBattery = {
    name = "Load Battery",
    tip = "Insert a battery into the lantern.",
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

                if not filterEmpty or charge > 0 then
                    table.insert(options, {
                        name = string.format("Battery (%dup)", charge),
                        data = {batteryID = invItem:GetID()}
                    })
                end
            end
        end

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
            client:NotifyLocalized("lanternSlotFull")
            return false
        end

        local charge = batteryItem:GetData("charge", 100)
        table.insert(batteries, charge)
        item:SetBatteries(batteries)

        batteryItem:Remove()

        client:NotifyLocalized("lanternBatteryLoaded", charge)
        client:EmitSound("items/battery_pickup.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if item:GetBatteryCount() >= item.maxBatteries then return false end
        if IsValid(item.entity) then return false end

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
    tip = "Remove the battery from the lantern.",
    icon = "icon16/lightning_delete.png",
    OnRun = function(item)
        local client = item.player
        local batteries = item:GetBatteries()

        if #batteries == 0 then
            return false
        end

        -- If equipped and light is on, turn it off first
        if item:GetData("equipped") then
            local weapon = client:GetWeapon("ix_lantern")
            if IsValid(weapon) and weapon.GetLanternOn and weapon:GetLanternOn() then
                weapon:SetLight(false)
            end
        end

        local charge = table.remove(batteries, 1)
        item:SetBatteries(batteries)

        local character = client:GetCharacter()
        local inventory = character:GetInventory()
        inventory:Add("battery", 1, {charge = charge})

        client:NotifyLocalized("lanternBatteryEjected")
        client:EmitSound("items/battery_pickup.wav", 50, 90)

        return false
    end,
    OnCanRun = function(item)
        if not item:HasBattery() then return false end
        if IsValid(item.entity) then return false end

        return true
    end
}

-- Equip
ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the lantern in your hands.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing lantern from this player
        if client.ixLanternItem and client.ixLanternItem ~= item then
            local oldItem = client.ixLanternItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing lantern SWEP if any
        if client:HasWeapon("ix_lantern") then
            client:StripWeapon("ix_lantern")
        end

        -- Set these BEFORE Give() so hooks see them
        client.ixLanternItem = item
        item:SetData("equipped", true)

        -- Give the SWEP
        local weapon = client:Give("ix_lantern")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_lantern")
        end

        client:EmitSound("physics/metal/metal_canister_impact_soft1.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end

        return true
    end
}

-- Unequip
ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the lantern away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        local weapon = client:GetWeapon("ix_lantern")
        if IsValid(weapon) then
            if weapon.SetLight then
                weapon:SetLight(false)
            end
            client:StripWeapon("ix_lantern")
        end

        client.ixLanternItem = nil
        item:SetData("equipped", nil)

        client:EmitSound("physics/metal/metal_canister_impact_soft1.wav", 50, 90)

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("equipped") == true
    end
}

-- ============================================================================
-- HOOKS
-- ============================================================================

function ITEM.postHooks.drop(item, result)
    if item:GetData("equipped") then
        local client = item:GetOwner()
        if IsValid(client) then
            local weapon = client:GetWeapon("ix_lantern")
            if IsValid(weapon) then
                if weapon.SetLight then
                    weapon:SetLight(false)
                end
                client:StripWeapon("ix_lantern")
            end
            client.ixLanternItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            local weapon = oldOwner:GetWeapon("ix_lantern")
            if IsValid(weapon) then
                if weapon.SetLight then
                    weapon:SetLight(false)
                end
                oldOwner:StripWeapon("ix_lantern")
            end
            oldOwner.ixLanternItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("lanternEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_lantern", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixLanternItem = self

            if weapon.SetLight then
                weapon:SetLight(false)
            end
        end
    end
end
