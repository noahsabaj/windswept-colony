--[[
    Battery Management Options
    Player preferences for automatic battery handling.
]]--

-- Auto-eject depleted batteries from devices
ix.option.Add("batteryAutoEject", ix.type.bool, true, {
    category = "inventory",
    bNetworked = true
})

-- Auto-load batteries from inventory when device slot is empty
ix.option.Add("batteryAutoLoad", ix.type.bool, true, {
    category = "inventory",
    bNetworked = true
})

-- Filter empty (0up) batteries from Load Battery dropdown
ix.option.Add("batteryFilterEmpty", ix.type.bool, true, {
    category = "inventory",
    bNetworked = true
})
