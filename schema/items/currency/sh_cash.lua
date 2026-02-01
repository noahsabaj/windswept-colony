--[[
    Cash (Dollar Bills)

    CEG Dollar bills. $1 = 100 cents.
    Inherits all functionality from base_currency.
]]--

ITEM.name = "Cash"
ITEM.description = "CEG Dollar bills."
ITEM.model = "models/props/cs_assault/Dollar.mdl"
ITEM.base = "base_currency"

-- Currency configuration
ITEM.currencyValue = 100  -- cents per unit (1 bill = $1 = 100 cents)
ITEM.unitName = "dollar"
ITEM.unitNamePlural = "dollars"
ITEM.unitSymbol = "$"
ITEM.symbolPrefix = true  -- $50 format
ITEM.canDestroy = true    -- Cash can be destroyed
