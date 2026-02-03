--[[
    Pen (Red)

    A ballpoint pen with red ink.
]]--

ITEM.name = "Pen (Red)"
ITEM.description = "A ballpoint pen with red ink."
ITEM.model = "models/props_lab/clipboard.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Equipment"

ITEM.maxInk = 1000
ITEM.inkColor = {200, 80, 80}

-- Inherit all functions from base pen
ITEM.base = "pen"
