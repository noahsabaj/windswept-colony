--[[
    ITEM: Handheld Radio
    Battery-powered communication device with frequency tuning and volume control.
    Supports both text (/r) and voice (Hold H) transmission.
]]--

ITEM.name = "Handheld Radio"
ITEM.model = Model("models/radio/w_radio.mdl")
ITEM.description = "A handheld radio with frequency tuner and volume control."
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Equipment"

-- Extend base_battery_device for battery management
ITEM.base = "base_battery_device"
ITEM.maxBatteries = 1
ITEM.weaponClass = nil  -- No SWEP, item-only (hides Equip/Unequip)
ITEM.playerItemKey = nil
ITEM.notifyPrefix = "radio"

-- Drain rates (up/sec)
ITEM.drainIdle = 0.033    -- ~50 min on full battery
ITEM.drainActive = 0.056  -- ~30 min on full battery

-- ============================================================================
-- DYNAMIC DESCRIPTION
-- ============================================================================

function ITEM:GetDescription()
    local enabled = self:GetData("enabled")
    local freq = self:GetData("frequency", "100.0")
    local volume = self:GetData("volume", 50)
    local batteries = self:GetBatteries()

    local status = "off"
    if enabled then
        if #batteries > 0 and batteries[1] > 0 then
            status = string.format("on - Freq: %s - Vol: %d%%", freq, volume)
        else
            status = "on (no battery)"
        end
    end

    return string.format("A handheld radio with frequency tuner and volume control.\nCurrently %s.", status)
end

-- ============================================================================
-- CLIENT VISUALS (Override base to use "enabled" instead of "equipped")
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local batteries = item:GetData("batteries", {})
        local isEnabled = item:GetData("enabled")

        -- Draw enabled indicator (green dot) instead of equipped
        if isEnabled then
            surface.SetDrawColor(110, 255, 110, 200)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end

        -- Draw battery bar (single battery)
        if #batteries > 0 then
            local charge = batteries[1]

            -- Background bar
            surface.SetDrawColor(30, 30, 30, 200)
            surface.DrawRect(4, h - 12, w - 8, 8)

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
            surface.DrawRect(4, h - 12, chargeWidth, 8)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local batteries = self:GetData("batteries", {})
        local volume = self:GetData("volume", 50)
        local freq = self:GetData("frequency", "100.0")
        local enabled = self:GetData("enabled")

        -- Status row
        local statusRow = tooltip:AddRow("status")
        if enabled then
            statusRow:SetText(string.format("ON - Frequency: %s", freq))
            statusRow:SetBackgroundColor(Color(50, 100, 50))
        else
            statusRow:SetText("OFF")
            statusRow:SetBackgroundColor(Color(100, 50, 50))
        end
        statusRow:SizeToContents()

        -- Volume row
        local volRow = tooltip:AddRow("volume")
        volRow:SetText(string.format("Volume: %d%%", volume))
        volRow:SetBackgroundColor(Color(75, 75, 100))
        volRow:SizeToContents()

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

        -- Usage hint
        local hintRow = tooltip:AddRow("hint")
        hintRow:SetText("Hold H to transmit voice")
        hintRow:SetBackgroundColor(Color(60, 60, 80))
        hintRow:SizeToContents()
    end
end

-- ============================================================================
-- BATTERY DRAIN FUNCTIONS
-- ============================================================================

-- Drain battery by amount, returns true if successful, false if depleted
function ITEM:DrainBattery(amount)
    local batteries = self:GetBatteries()
    if #batteries == 0 then return false end

    local charge = batteries[1]
    if charge <= 0 then return false end

    charge = math.max(0, charge - amount)
    batteries[1] = charge
    self:SetBatteries(batteries)

    -- Auto-disable if battery depleted
    if charge <= 0 then
        self:SetData("enabled", false)

        local owner = self:GetOwner()
        if IsValid(owner) then
            local character = owner:GetCharacter()
            if character then
                character:SetData("ixHasActiveRadio", false)
            end
            owner:NotifyLocalized("radioBatteryDepleted")
        end
        return false
    end

    return true
end

-- Called when radio transmits or receives (text or voice)
-- duration is in seconds
function ITEM:DrainActive(duration)
    return self:DrainBattery(self.drainActive * duration)
end

-- Called every tick while radio is on but idle
function ITEM:DrainIdleTick(deltaTime)
    return self:DrainBattery(self.drainIdle * deltaTime)
end

-- ============================================================================
-- RADIO FUNCTIONS
-- ============================================================================

-- Check if radio can operate (has battery with charge)
function ITEM:CanOperate()
    local batteries = self:GetBatteries()
    return #batteries > 0 and batteries[1] > 0
end

-- Check if radio is actively on and operational
function ITEM:IsOperational()
    return self:GetData("enabled") and self:CanOperate()
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

ITEM.functions.Toggle = {
    name = "Toggle",
    tip = "Turn radio on/off.",
    icon = "icon16/lightning.png",
    OnRun = function(item)
        local client = item.player
        local character = client:GetCharacter()

        local newState = not item:GetData("enabled", false)

        -- Check if turning on
        if newState then
            -- Need battery to turn on
            if not item:CanOperate() then
                client:NotifyLocalized("radioNoBattery")
                return false
            end

            -- Check if another radio is already on
            local radios = character:GetInventory():GetItemsByUniqueID("handheld_radio", true)
            for _, v in ipairs(radios) do
                if v ~= item and v:GetData("enabled", false) then
                    client:NotifyLocalized("radioAlreadyOn")
                    return false
                end
            end
        end

        item:SetData("enabled", newState)
        client:EmitSound("buttons/lever7.wav", 50, math.random(170, 180), 0.25)

        -- Update cache for radio CanHear optimization
        character:SetData("ixHasActiveRadio", newState)

        -- Sync frequency to character data when turning ON (prevents stale data)
        if newState then
            local itemFreq = item:GetData("frequency", "100.0")
            character:SetData("frequency", itemFreq)
        end

        -- Start/stop idle drain timer
        if SERVER then
            local timerName = "ixRadioIdleDrain_" .. item:GetID()
            if newState then
                timer.Create(timerName, 1, 0, function()
                    if not item or not item:GetData("enabled") then
                        timer.Remove(timerName)
                        return
                    end
                    item:DrainIdleTick(1)
                end)
            else
                timer.Remove(timerName)
            end
        end

        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return true
    end
}

ITEM.functions.Frequency = {
    name = "Set Frequency",
    tip = "Tune to a frequency.",
    icon = "icon16/transmit.png",
    OnRun = function(item)
        netstream.Start(item.player, "ixRadioFrequency", item:GetData("frequency", "100.0"))
        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return true
    end
}

ITEM.functions.Volume = {
    name = "Set Volume",
    tip = "Adjust receive volume.",
    icon = "icon16/sound.png",
    OnRun = function(item)
        net.Start("ixRadioVolume")
        net.WriteUInt(item:GetID(), 32)
        net.WriteUInt(item:GetData("volume", 50), 7)  -- 0-100 fits in 7 bits
        net.Send(item.player)
        return false
    end,
    OnCanRun = function(item)
        if IsValid(item.entity) then return false end
        return true
    end
}

-- ============================================================================
-- HOOKS
-- ============================================================================

-- Auto-off when dropped
function ITEM.postHooks.drop(item, status)
    if item:GetData("enabled") then
        item:SetData("enabled", false)

        -- Stop drain timer
        if SERVER then
            timer.Remove("ixRadioIdleDrain_" .. item:GetID())
        end

        -- Update cache
        local owner = item:GetOwner()
        if IsValid(owner) then
            local character = owner:GetCharacter()
            if character then
                character:SetData("ixHasActiveRadio", false)
            end
        end
    end
end

-- Clean up timer when item is removed
function ITEM:OnRemoved()
    if SERVER then
        timer.Remove("ixRadioIdleDrain_" .. self:GetID())
    end
end

-- Restore timer on loadout if radio was enabled
function ITEM:OnLoadout()
    if SERVER and self:GetData("enabled") then
        -- Verify battery still has charge
        if not self:CanOperate() then
            self:SetData("enabled", false)
            return
        end

        local timerName = "ixRadioIdleDrain_" .. self:GetID()
        timer.Create(timerName, 1, 0, function()
            if not self or not self:GetData("enabled") then
                timer.Remove(timerName)
                return
            end
            self:DrainIdleTick(1)
        end)
    end
end
