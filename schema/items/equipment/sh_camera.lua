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
ITEM.base = "base_battery_device"
ITEM.width = 2
ITEM.height = 2
ITEM.category = "Equipment"
ITEM.noBusiness = true

-- Battery device configuration
ITEM.maxBatteries = 1
ITEM.weaponClass = "ix_camera"
ITEM.playerItemKey = "ixCameraItem"
ITEM.equipSound = "items/flashlight1.wav"
ITEM.notifyPrefix = "camera"
ITEM.hasLightToggle = false

-- Camera-specific configuration
ITEM.maxFilm = 1
ITEM.batteryDrainPerPhoto = 2

-- ============================================================================
-- FILM HELPER FUNCTIONS (camera-specific)
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
        self:SetFilm(nil)
        return true, true  -- success, film exhausted
    else
        self:SetFilm(film)
        return true, false  -- success, film not exhausted
    end
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

-- ============================================================================
-- CLIENT VISUALS (override to show both battery and film)
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

            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(4, barY - barHeight - 2, w - 8, barHeight)

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
            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(4, barY, w - 8, barHeight)

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
-- ITEM FUNCTIONS - FILM (camera-specific)
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
                        data = {filmID = invItem:GetID(), shots = shots}
                    })
                end
            end
        end

        table.sort(options, function(a, b)
            return (a.data.shots or 0) > (b.data.shots or 0)
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
