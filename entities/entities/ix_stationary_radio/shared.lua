--[[
    Stationary Radio Entity - Shared
]]--

ENT.Type = "anim"
ENT.PrintName = "Stationary Radio"
ENT.Author = "Windswept"
ENT.Spawnable = false
ENT.AdminOnly = false

-- Max distance from console before UI closes
ENT.MaxUseDistance = 200

function ENT:SetupDataTables()
    -- Current user (nil if none)
    self:NetworkVar("Entity", 0, "User")

    -- Mic state
    self:NetworkVar("Bool", 0, "MicOn")

    -- Channel 1
    self:NetworkVar("String", 0, "Ch1Freq")
    self:NetworkVar("Bool", 1, "Ch1TX")
    self:NetworkVar("Bool", 2, "Ch1RX")
    self:NetworkVar("Int", 0, "Ch1Vol")

    -- Channel 2
    self:NetworkVar("String", 1, "Ch2Freq")
    self:NetworkVar("Bool", 3, "Ch2TX")
    self:NetworkVar("Bool", 4, "Ch2RX")
    self:NetworkVar("Int", 1, "Ch2Vol")

    -- Channel 3
    self:NetworkVar("String", 2, "Ch3Freq")
    self:NetworkVar("Bool", 5, "Ch3TX")
    self:NetworkVar("Bool", 6, "Ch3RX")
    self:NetworkVar("Int", 2, "Ch3Vol")

    -- Channel 4
    self:NetworkVar("String", 3, "Ch4Freq")
    self:NetworkVar("Bool", 7, "Ch4TX")
    self:NetworkVar("Bool", 8, "Ch4RX")
    self:NetworkVar("Int", 3, "Ch4Vol")
end

-- Get all channel data as a table
function ENT:GetChannelData()
    return {
        {
            freq = self:GetCh1Freq() or "100.0",
            tx = self:GetCh1TX(),
            rx = self:GetCh1RX(),
            vol = self:GetCh1Vol() or 50
        },
        {
            freq = self:GetCh2Freq() or "100.0",
            tx = self:GetCh2TX(),
            rx = self:GetCh2RX(),
            vol = self:GetCh2Vol() or 50
        },
        {
            freq = self:GetCh3Freq() or "100.0",
            tx = self:GetCh3TX(),
            rx = self:GetCh3RX(),
            vol = self:GetCh3Vol() or 50
        },
        {
            freq = self:GetCh4Freq() or "100.0",
            tx = self:GetCh4TX(),
            rx = self:GetCh4RX(),
            vol = self:GetCh4Vol() or 50
        }
    }
end

-- Set all channel data from a table
function ENT:SetChannelData(channels)
    if not channels or #channels < 4 then
        channels = ix.radio.GetDefaultChannels()
    end

    self:SetCh1Freq(channels[1].freq or "100.0")
    self:SetCh1TX(channels[1].tx or false)
    self:SetCh1RX(channels[1].rx or false)
    self:SetCh1Vol(channels[1].vol or 50)

    self:SetCh2Freq(channels[2].freq or "100.0")
    self:SetCh2TX(channels[2].tx or false)
    self:SetCh2RX(channels[2].rx or false)
    self:SetCh2Vol(channels[2].vol or 50)

    self:SetCh3Freq(channels[3].freq or "100.0")
    self:SetCh3TX(channels[3].tx or false)
    self:SetCh3RX(channels[3].rx or false)
    self:SetCh3Vol(channels[3].vol or 50)

    self:SetCh4Freq(channels[4].freq or "100.0")
    self:SetCh4TX(channels[4].tx or false)
    self:SetCh4RX(channels[4].rx or false)
    self:SetCh4Vol(channels[4].vol or 50)
end

-- Get all TX-enabled frequencies
function ENT:GetTXFrequencies()
    local freqs = {}
    local channels = self:GetChannelData()

    for _, ch in ipairs(channels) do
        if ch.tx then
            freqs[ch.freq] = true
        end
    end

    return freqs
end

-- Get all RX-enabled frequencies with their volumes
function ENT:GetRXFrequencies()
    local freqs = {}
    local channels = self:GetChannelData()

    for _, ch in ipairs(channels) do
        if ch.rx then
            -- If same frequency on multiple channels, use highest volume
            if not freqs[ch.freq] or freqs[ch.freq] < ch.vol then
                freqs[ch.freq] = ch.vol
            end
        end
    end

    return freqs
end
