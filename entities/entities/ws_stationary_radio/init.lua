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
        self:SetChannelData(ws.radio.GetDefaultChannels())
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
    local pickupTime = ws.config.Get("itemPickupTime", 0.5)

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
            local pickupTime = ws.config.Get("itemPickupTime", 0.5)

            -- Short press (released before pickup time) = open UI
            if holdTime < pickupTime and not self.uiOpenedThisPress[ply] then
                local currentUser = self:GetUser()

                if IsValid(currentUser) and currentUser ~= ply then
                    ply:NotifyLocalized("stationaryRadioInUse")
                else
                    -- Open UI for this player
                    self:SetUser(ply)

                    net.Start("wsStationaryRadioOpen")
                    net.WriteEntity(self)
                    net.Send(ply)

                    -- Start distance check timer
                    local entRef = self
                    local timerName = "wsStationaryRadio_" .. ply:SteamID64()
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

    local character, inventory = ws.constants.GetCharacterInventory(client)
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
    timer.Remove("wsStationaryRadio_" .. client:SteamID64())

    -- Notify client if reason provided
    if reason then
        client:NotifyLocalized(reason)
    end
end

function ENT:RegisterTransmitter()
    ws.radio.transmitters = ws.radio.transmitters or {}

    local txFreqs = self:GetTXFrequencies()
    if table.IsEmpty(txFreqs) then
        self:UnregisterTransmitter()
        return
    end

    ws.radio.transmitters[self] = {
        frequencies = txFreqs,
        entity = self,
        isStationary = true,
        user = self:GetUser()
    }
end

function ENT:UnregisterTransmitter()
    ws.radio.transmitters = ws.radio.transmitters or {}
    ws.radio.transmitters[self] = nil
end

function ENT:OnRemove()
    -- Clean up
    self:UnregisterTransmitter()

    local user = self:GetUser()
    if IsValid(user) then
        timer.Remove("wsStationaryRadio_" .. user:SteamID64())
    end
end

-- Network receivers. Client->server config/mic/transmit/close go through ws.action with the
-- session shape: target = this entity, session = true requires ent:GetUser() == client (the
-- open-UI authority), so the wrapper enforces validity/class/session before run(). (session shape)
ws.action.Register("wsStationaryRadioClose", {
    target = true,
    targetClass = "ws_stationary_radio",
    session = true,
    range = "none",
    run = function(client, ctx)
        ctx.target:CloseForUser(client)
    end,
})

ws.action.Register("wsStationaryRadioConfig", {
    target = true,
    targetClass = "ws_stationary_radio",
    session = true,
    range = "none",
    -- Light rate limit on config churn. (sc-entities-interactive-2)
    rateLimit = 0.2,
    read = function()
        local channel = net.ReadUInt(3) -- 1-4
        local field = net.ReadString()
        local value

        if field == "freq" then
            value = net.ReadString()
            -- Validate frequency
            if not ws.radio.ValidateFrequency(value) then return nil end
        elseif field == "tx" or field == "rx" then
            value = net.ReadBool()
        elseif field == "vol" then
            -- UInt7 carries 0-127; clamp to the valid 0-100 range. (sc-entities-interactive-4)
            value = math.Clamp(net.ReadUInt(7), 0, 100)
        else
            return nil
        end

        return { channel = channel, field = field, value = value }
    end,
    onValidate = function(client, ctx)
        local data = ctx.data
        return data ~= nil and data.channel >= 1 and data.channel <= 4
    end,
    run = function(client, ctx)
        local ent = ctx.target
        local channel, field, value = ctx.data.channel, ctx.data.field, ctx.data.value

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
    end,
})

ws.action.Register("wsStationaryRadioMic", {
    target = true,
    targetClass = "ws_stationary_radio",
    session = true,
    range = "none",
    -- Rate limit mic-toggle (transmitter register/unregister churn). (sc-entities-interactive-2)
    rateLimit = 0.5,
    read = function()
        return net.ReadBool()
    end,
    run = function(client, ctx)
        local ent = ctx.target
        local micOn = ctx.data

        ent:SetMicOn(micOn)

        if micOn then
            ent:RegisterTransmitter()
        else
            ent:UnregisterTransmitter()
        end
    end,
})

ws.action.Register("wsStationaryRadioTransmit", {
    target = true,
    targetClass = "ws_stationary_radio",
    session = true,
    range = "none",
    -- Rate limit: this broadcasts chat to every TX frequency; cap like normal chat. (sc-entities-interactive-2)
    rateLimit = 1,
    read = function()
        return net.ReadString()
    end,
    run = function(client, ctx)
        local ent = ctx.target
        local message = ctx.data

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

        -- Transmit on each TX frequency. frequency is mutated as a side channel into ws.chat.Send,
        -- so wrap in pcall and ALWAYS restore originalFreq even if Send errors mid-loop - otherwise
        -- the character is left stuck on a TX frequency. (sc-entities-interactive-3)
        pcall(function()
            for freq, _ in pairs(txFreqs) do
                character:SetData("frequency", freq)
                ws.chat.Send(client, "radio", message)
            end
        end)

        -- Restore original frequency
        character:SetData("frequency", originalFreq)
    end,
})

-- Clean up when player dies while using console
hook.Add("PlayerDeath", "wsStationaryRadioPlayerDeath", function(victim)
    for _, ent in ipairs(ents.FindByClass("ws_stationary_radio")) do
        if ent:GetUser() == victim then
            ent:CloseForUser(victim)
        end
    end
end)

-- Clean up when player disconnects while using console
hook.Add("PlayerDisconnected", "wsStationaryRadioPlayerDisconnect", function(client)
    for _, ent in ipairs(ents.FindByClass("ws_stationary_radio")) do
        if ent:GetUser() == client then
            ent:SetUser(nil)
            ent:SetMicOn(false)
            ent:UnregisterTransmitter()
        end
    end
end)
