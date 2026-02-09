--[[
    Stationary Radio Entity - Server
]]--

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_lab/citizenradio.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(CONTINUOUS_USE) -- For hold E detection

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    -- Apply pending channel data from item drop
    if self.pendingChannels then
        self:SetChannelData(self.pendingChannels)
        self.pendingChannels = nil
    elseif not self:GetCh1Freq() or self:GetCh1Freq() == "" then
        -- Initialize default channel data if not set
        self:SetChannelData(ix.radio.GetDefaultChannels())
    end

    self:SetMicOn(false)

    -- Track hold E for pickup (stores start time)
    -- Track if UI was already opened this press (prevents reopening every tick)
    self.holdEStart = {}
    self.uiOpenedThisPress = {}
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local currentUser = self:GetUser()

    -- Track hold E for pickup
    if not self.holdEStart[activator] then
        self.holdEStart[activator] = CurTime()
        self.uiOpenedThisPress[activator] = false
    end

    local holdTime = CurTime() - self.holdEStart[activator]
    local pickupTime = ix.config.Get("itemPickupTime", 0.5)

    -- Check if held long enough for pickup
    if holdTime >= pickupTime then
        self:PickupByPlayer(activator)
        self.holdEStart[activator] = nil
        self.uiOpenedThisPress[activator] = nil
        return
    end
end

-- Check for press release and handle actions
function ENT:Think()
    for ply, startTime in pairs(self.holdEStart) do
        if not IsValid(ply) then
            self.holdEStart[ply] = nil
            self.uiOpenedThisPress[ply] = nil
            continue
        end

        -- Check if player released E
        if not ply:KeyDown(IN_USE) then
            local holdTime = CurTime() - startTime
            local pickupTime = ix.config.Get("itemPickupTime", 0.5)

            -- Short press (released before pickup time) = open UI
            if holdTime < pickupTime and not self.uiOpenedThisPress[ply] then
                local currentUser = self:GetUser()

                if IsValid(currentUser) and currentUser ~= ply then
                    ply:NotifyLocalized("stationaryRadioInUse")
                else
                    -- Open UI for this player
                    self:SetUser(ply)

                    net.Start("ixStationaryRadioOpen")
                    net.WriteEntity(self)
                    net.Send(ply)

                    -- Start distance check timer
                    local entRef = self
                    local timerName = "ixStationaryRadio_" .. ply:SteamID64()
                    timer.Create(timerName, 0.5, 0, function()
                        if not IsValid(ply) or not IsValid(entRef) then
                            timer.Remove(timerName)
                            return
                        end

                        -- Check if player moved too far
                        if ply:GetPos():DistToSqr(entRef:GetPos()) > (entRef.MaxUseDistance * entRef.MaxUseDistance) then
                            entRef:CloseForUser(ply, "stationaryRadioTooFar")
                        end
                    end)
                end
            end

            -- Clean up tracking
            self.holdEStart[ply] = nil
            self.uiOpenedThisPress[ply] = nil
        end
    end
end

function ENT:PickupByPlayer(client)
    if not IsValid(client) then return end

    local character, inventory = ix.constants.GetCharacterInventory(client)
    if not character or not inventory then return end

    -- Check if there's room in inventory
    if not inventory:FindEmptySlot(2, 1) then -- stationary_radio is 2x1
        client:NotifyLocalized("inventoryFull")
        return
    end

    -- Get channel data to save
    local channels = self:GetChannelData()

    -- Close UI if someone is using it
    local user = self:GetUser()
    if IsValid(user) then
        self:CloseForUser(user)
    end

    -- Add item to inventory with channel data
    inventory:Add("stationary_radio", 1, {
        channels = channels
    })

    -- Remove entity
    self:Remove()
end

function ENT:CloseForUser(client, reason)
    if not IsValid(client) then return end

    -- Only close if this client is the current user
    if self:GetUser() ~= client then return end

    -- Clear user
    self:SetUser(nil)

    -- Disable mic
    if self:GetMicOn() then
        self:SetMicOn(false)
        self:UnregisterTransmitter()
    end

    -- Stop distance timer
    timer.Remove("ixStationaryRadio_" .. client:SteamID64())

    -- Notify client if reason provided
    if reason then
        client:NotifyLocalized(reason)
    end
end

function ENT:RegisterTransmitter()
    Schema.radioTransmitters = Schema.radioTransmitters or {}

    local txFreqs = self:GetTXFrequencies()
    if table.IsEmpty(txFreqs) then
        self:UnregisterTransmitter()
        return
    end

    Schema.radioTransmitters[self] = {
        frequencies = txFreqs,
        entity = self,
        isStationary = true,
        user = self:GetUser()
    }
end

function ENT:UnregisterTransmitter()
    Schema.radioTransmitters = Schema.radioTransmitters or {}
    Schema.radioTransmitters[self] = nil
end

function ENT:OnRemove()
    -- Clean up
    self:UnregisterTransmitter()

    local user = self:GetUser()
    if IsValid(user) then
        timer.Remove("ixStationaryRadio_" .. user:SteamID64())
    end
end

-- Network receivers
net.Receive("ixStationaryRadioClose", function(len, client)
    local ent = net.ReadEntity()

    if not IsValid(ent) or ent:GetClass() ~= "ix_stationary_radio" then return end
    if ent:GetUser() ~= client then return end

    ent:CloseForUser(client)
end)

net.Receive("ixStationaryRadioConfig", function(len, client)
    local ent = net.ReadEntity()
    local channel = net.ReadUInt(3) -- 1-4
    local field = net.ReadString()
    local value

    if field == "freq" then
        value = net.ReadString()
        -- Validate frequency
        if not ix.radio.ValidateFrequency(value) then return end
    elseif field == "tx" or field == "rx" then
        value = net.ReadBool()
    elseif field == "vol" then
        value = net.ReadUInt(7) -- 0-100
    else
        return
    end

    if not IsValid(ent) or ent:GetClass() ~= "ix_stationary_radio" then return end
    if ent:GetUser() ~= client then return end
    if channel < 1 or channel > 4 then return end

    -- Set the value using the appropriate setter
    if field == "freq" then
        ent["SetCh" .. channel .. "Freq"](ent, value)
    elseif field == "tx" then
        ent["SetCh" .. channel .. "TX"](ent, value)
    elseif field == "rx" then
        ent["SetCh" .. channel .. "RX"](ent, value)
    elseif field == "vol" then
        ent["SetCh" .. channel .. "Vol"](ent, value)
    end

    -- Update transmitter registration if TX changed
    if field == "tx" then
        if ent:GetMicOn() then
            ent:RegisterTransmitter()
        end
    end
end)

net.Receive("ixStationaryRadioMic", function(len, client)
    local ent = net.ReadEntity()
    local micOn = net.ReadBool()

    if not IsValid(ent) or ent:GetClass() ~= "ix_stationary_radio" then return end
    if ent:GetUser() ~= client then return end

    ent:SetMicOn(micOn)

    if micOn then
        ent:RegisterTransmitter()
    else
        ent:UnregisterTransmitter()
    end
end)

net.Receive("ixStationaryRadioTransmit", function(len, client)
    local ent = net.ReadEntity()
    local message = net.ReadString()

    if not IsValid(ent) or ent:GetClass() ~= "ix_stationary_radio" then return end
    if ent:GetUser() ~= client then return end

    -- Get TX frequencies
    local txFreqs = ent:GetTXFrequencies()
    if table.IsEmpty(txFreqs) then
        client:NotifyLocalized("stationaryRadioNoTx")
        return
    end

    -- Sanitize message
    message = string.sub(message, 1, 256)
    if message == "" then return end

    -- Store original frequency
    local character = client:GetCharacter()
    if not character then return end

    local originalFreq = character:GetData("frequency", "100.0")

    -- Transmit on each TX frequency
    for freq, _ in pairs(txFreqs) do
        character:SetData("frequency", freq)
        ix.chat.Send(client, "radio", message)
    end

    -- Restore original frequency
    character:SetData("frequency", originalFreq)
end)

-- Clean up when player dies while using console
hook.Add("PlayerDeath", "ixStationaryRadioPlayerDeath", function(victim)
    for _, ent in ipairs(ents.FindByClass("ix_stationary_radio")) do
        if ent:GetUser() == victim then
            ent:CloseForUser(victim)
        end
    end
end)

-- Clean up when player disconnects while using console
hook.Add("PlayerDisconnected", "ixStationaryRadioPlayerDisconnect", function(client)
    for _, ent in ipairs(ents.FindByClass("ix_stationary_radio")) do
        if ent:GetUser() == client then
            ent:SetUser(nil)
            ent:SetMicOn(false)
            ent:UnregisterTransmitter()
        end
    end
end)
