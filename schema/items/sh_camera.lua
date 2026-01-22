--[[
    Camera

    A camera with battery and film slots.
    - Battery: Powers the camera (2up per photo)
    - Film: Captures photos (1 shot per photo, 10 shots per pack)

    Film cannot be ejected once loaded - must use all 10 shots.
    When film is empty, it is automatically removed.
]]--

ITEM.name = "Camera"
ITEM.description = "A camera for taking photographs. Requires battery and film."
ITEM.model = "models/weapons/infra/w_camera.mdl"
ITEM.width = 1
ITEM.height = 2
ITEM.category = "Equipment"
ITEM.noBusiness = true

-- Slot configuration
ITEM.maxBatteries = 1
ITEM.maxFilm = 1

-- Battery drain per photo
ITEM.batteryDrainPerPhoto = 2

-- ============================================================================
-- BATTERY HELPER FUNCTIONS (same as flashlight)
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

function ITEM:GetFirstBatteryCharge()
    local batteries = self:GetBatteries()
    return batteries[1] or 0
end

function ITEM:HasSufficientCharge()
    return self:GetFirstBatteryCharge() >= self.batteryDrainPerPhoto
end

function ITEM:DrainBattery(amount)
    local batteries = self:GetBatteries()
    if #batteries == 0 then return false end

    batteries[1] = math.max(0, batteries[1] - amount)
    self:SetBatteries(batteries)

    return true
end

-- Find the highest charged battery in inventory
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
        client:NotifyLocalized("cameraBatteryEjected")
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

    table.insert(batteries, bestCharge)
    self:SetBatteries(batteries)
    bestBattery:Remove()

    client:NotifyLocalized("cameraAutoLoaded", bestCharge)
    return true
end

-- ============================================================================
-- FILM HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetFilm()
    return self:GetData("film", nil)
end

function ITEM:SetFilm(film)
    self:SetData("film", film)
end

function ITEM:HasFilm()
    local film = self:GetFilm()
    return film ~= nil and film.shots > 0
end

function ITEM:GetFilmShots()
    local film = self:GetFilm()
    return film and film.shots or 0
end

function ITEM:ConsumeFilmShot()
    local film = self:GetFilm()
    if not film then return false end

    film.shots = film.shots - 1

    if film.shots <= 0 then
        -- Film exhausted - remove it
        self:SetFilm(nil)
        return true, true  -- success, film exhausted
    else
        self:SetFilm(film)
        return true, false  -- success, film not exhausted
    end
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local batteries = item:GetData("batteries", {})
        local film = item:GetData("film", nil)
        local isEquipped = item:GetData("equipped")

        -- Draw equipped indicator (green dot)
        if isEquipped then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end

        local barY = h - 12
        local barHeight = 6

        -- Draw battery bar (top)
        if #batteries > 0 then
            local charge = batteries[1]

            -- Background bar
            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(4, barY - barHeight - 2, w - 8, barHeight)

            -- Charge fill
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
            surface.DrawRect(4, barY - barHeight - 2, chargeWidth, barHeight)
        end

        -- Draw film indicator (bottom)
        if film then
            -- Background bar
            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(4, barY, w - 8, barHeight)

            -- Film shots fill (cyan/blue color)
            local shotWidth = ((w - 8) / 10) * film.shots
            surface.SetDrawColor(50, 150, 200)
            surface.DrawRect(4, barY, shotWidth, barHeight)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local batteries = self:GetData("batteries", {})
        local film = self:GetData("film", nil)

        -- Battery row
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

        -- Film row
        local filmRow = tooltip:AddRow("film")
        if not film then
            filmRow:SetText("No film loaded.")
            filmRow:SetBackgroundColor(Color(100, 100, 100))
        else
            filmRow:SetText(string.format("Film: %d / 10 shots", film.shots))
            if film.shots >= 5 then
                filmRow:SetBackgroundColor(Color(50, 100, 100))
            elseif film.shots >= 2 then
                filmRow:SetBackgroundColor(Color(100, 100, 50))
            else
                filmRow:SetBackgroundColor(Color(150, 100, 50))
            end
        end
        filmRow:SizeToContents()
    end
end

-- ============================================================================
-- ITEM FUNCTIONS - BATTERY
-- ============================================================================

ITEM.functions.LoadBattery = {
    name = "Load Battery",
    tip = "Insert a battery into the camera.",
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
            client:NotifyLocalized("cameraSlotFull")
            return false
        end

        local charge = batteryItem:GetData("charge", 100)
        table.insert(batteries, charge)
        item:SetBatteries(batteries)
        batteryItem:Remove()

        client:NotifyLocalized("cameraBatteryLoaded", charge)
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

ITEM.functions.EjectBattery = {
    name = "Eject Battery",
    tip = "Remove the battery from the camera.",
    icon = "icon16/lightning_delete.png",
    OnRun = function(item)
        local client = item.player
        local batteries = item:GetBatteries()

        if #batteries == 0 then
            return false
        end

        local charge = table.remove(batteries, 1)
        item:SetBatteries(batteries)

        local character = client:GetCharacter()
        local inventory = character:GetInventory()
        inventory:Add("battery", 1, {charge = charge})

        client:NotifyLocalized("cameraBatteryEjected")
        client:EmitSound("items/battery_pickup.wav", 50, 90)

        return false
    end,
    OnCanRun = function(item)
        if not item:HasBattery() then return false end
        if IsValid(item.entity) then return false end
        return true
    end
}

-- ============================================================================
-- ITEM FUNCTIONS - FILM
-- ============================================================================

ITEM.functions.LoadFilm = {
    name = "Load Film",
    tip = "Insert a film pack into the camera.",
    icon = "icon16/picture_add.png",
    isMulti = true,
    multiOptions = function(item, client)
        local options = {}
        local character = client:GetCharacter()
        if not character then return options end

        local inventory = character:GetInventory()
        if not inventory then return options end

        for _, invItem in pairs(inventory:GetItems()) do
            if invItem.uniqueID == "film" then
                local shots = invItem:GetData("shots", 10)
                if shots > 0 then
                    table.insert(options, {
                        name = string.format("Film Pack (%d shots)", shots),
                        data = {filmID = invItem:GetID()}
                    })
                end
            end
        end

        -- Sort by shots (highest first)
        table.sort(options, function(a, b)
            return tonumber(string.match(a.name, "%((%d+) shots%)")) > tonumber(string.match(b.name, "%((%d+) shots%)"))
        end)

        return options
    end,
    OnRun = function(item, data)
        local client = item.player
        local filmID = data and data.filmID

        if not filmID then return false end

        local filmItem = ix.item.instances[filmID]
        if not filmItem or filmItem.uniqueID ~= "film" then
            return false
        end

        if item:HasFilm() then
            client:NotifyLocalized("cameraFilmSlotFull")
            return false
        end

        local shots = filmItem:GetData("shots", 10)
        item:SetFilm({shots = shots})
        filmItem:Remove()

        client:NotifyLocalized("cameraFilmLoaded", shots)
        client:EmitSound("items/ammocrate_open.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        -- Can't load if already has film
        if item:HasFilm() then return false end
        if IsValid(item.entity) then return false end

        local client = item.player
        if not IsValid(client) then return false end

        local character = client:GetCharacter()
        if not character then return false end

        local inventory = character:GetInventory()
        if not inventory then return false end

        for _, invItem in pairs(inventory:GetItems()) do
            if invItem.uniqueID == "film" then
                local shots = invItem:GetData("shots", 10)
                if shots > 0 then
                    return true
                end
            end
        end

        return false
    end
}

-- NOTE: No EjectFilm function - film must be used up

-- ============================================================================
-- ITEM FUNCTIONS - EQUIP/UNEQUIP
-- ============================================================================

ITEM.functions.Equip = {
    name = "Equip",
    tip = "Hold the camera in your hands.",
    icon = "icon16/tick.png",
    OnRun = function(item)
        local client = item.player

        -- Unequip any existing camera from this player
        if client.ixCameraItem and client.ixCameraItem ~= item then
            local oldItem = client.ixCameraItem
            oldItem:SetData("equipped", nil)
        end

        -- Strip existing camera SWEP if any
        if client:HasWeapon("ix_camera") then
            client:StripWeapon("ix_camera")
        end

        -- Give the SWEP
        local weapon = client:Give("ix_camera")
        if IsValid(weapon) then
            weapon.ixItem = item
            client:SelectWeapon("ix_camera")
        end

        client.ixCameraItem = item
        item:SetData("equipped", true)

        client:EmitSound("items/flashlight1.wav", 50)

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        if item:GetData("equipped") then return false end
        return true
    end
}

ITEM.functions.Unequip = {
    name = "Unequip",
    tip = "Put the camera away.",
    icon = "icon16/cross.png",
    OnRun = function(item)
        local client = item.player

        if client:HasWeapon("ix_camera") then
            client:StripWeapon("ix_camera")
        end

        client.ixCameraItem = nil
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

function ITEM.postHooks.drop(item, result)
    if item:GetData("equipped") then
        local client = item:GetOwner()
        if IsValid(client) then
            if client:HasWeapon("ix_camera") then
                client:StripWeapon("ix_camera")
            end
            client.ixCameraItem = nil
        end
        item:SetData("equipped", nil)
    end
end

function ITEM:OnTransferred(oldInventory, newInventory)
    if self:GetData("equipped") then
        local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
        if IsValid(oldOwner) then
            if oldOwner:HasWeapon("ix_camera") then
                oldOwner:StripWeapon("ix_camera")
            end
            oldOwner.ixCameraItem = nil
        end
        self:SetData("equipped", nil)
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    if newInventory and self:GetData("equipped") then
        local owner = self:GetOwner()
        if IsValid(owner) then
            owner:NotifyLocalized("cameraEquipped")
        end
        return false
    end
    return true
end

function ITEM:OnLoadout()
    if self:GetData("equipped") then
        local client = self.player
        if not IsValid(client) then return end

        local weapon = client:Give("ix_camera", true)
        if IsValid(weapon) then
            weapon.ixItem = self
            client.ixCameraItem = self
        end
    end
end
