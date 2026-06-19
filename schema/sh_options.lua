--[[
    Battery Management Options
    Player preferences for automatic battery handling.
]]--

-- Auto-eject depleted batteries from devices
ws.option.Add("batteryAutoEject", ws.type.bool, true, {
    category = "inventory",
    bNetworked = true
})

-- Auto-load batteries from inventory when device slot is empty
ws.option.Add("batteryAutoLoad", ws.type.bool, true, {
    category = "inventory",
    bNetworked = true
})

-- Filter empty (0up) batteries from Load Battery dropdown
ws.option.Add("batteryFilterEmpty", ws.type.bool, true, {
    category = "inventory",
    bNetworked = true
})
