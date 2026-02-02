--[[
    Radio Utilities Library
    Shared functions for handheld and stationary radios
]]--

ix.radio = ix.radio or {}

-- Frequency constraints
ix.radio.FREQ_MIN = 100.0
ix.radio.FREQ_MAX = 999.9
ix.radio.FREQ_STEP = 0.1

-- Validate frequency format (###.#)
function ix.radio.ValidateFrequency(freq)
    if not freq then return false end

    -- Must be string in ###.# format
    if not string.match(tostring(freq), "^%d%d%d%.%d$") then
        return false
    end

    local num = tonumber(freq)
    if not num then return false end

    return num >= ix.radio.FREQ_MIN and num <= ix.radio.FREQ_MAX
end

-- Format frequency to ensure ###.# format
function ix.radio.FormatFrequency(freq)
    local num = tonumber(freq)
    if not num then return "100.0" end

    -- Clamp to valid range
    num = math.Clamp(num, ix.radio.FREQ_MIN, ix.radio.FREQ_MAX)

    -- Round to nearest 0.1
    num = math.Round(num, 1)

    -- Format as ###.#
    return string.format("%05.1f", num)
end

-- Increment frequency by step
function ix.radio.IncrementFrequency(freq)
    local num = tonumber(freq) or ix.radio.FREQ_MIN
    num = num + ix.radio.FREQ_STEP

    if num > ix.radio.FREQ_MAX then
        num = ix.radio.FREQ_MIN -- Wrap around
    end

    return ix.radio.FormatFrequency(num)
end

-- Decrement frequency by step
function ix.radio.DecrementFrequency(freq)
    local num = tonumber(freq) or ix.radio.FREQ_MIN
    num = num - ix.radio.FREQ_STEP

    if num < ix.radio.FREQ_MIN then
        num = ix.radio.FREQ_MAX -- Wrap around
    end

    return ix.radio.FormatFrequency(num)
end

-- Get default channel configuration for stationary radio
function ix.radio.GetDefaultChannels()
    return {
        {freq = "100.0", tx = false, rx = false, vol = 50},
        {freq = "100.0", tx = false, rx = false, vol = 50},
        {freq = "100.0", tx = false, rx = false, vol = 50},
        {freq = "100.0", tx = false, rx = false, vol = 50}
    }
end
