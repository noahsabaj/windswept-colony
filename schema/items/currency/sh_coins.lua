--[[
    Coins (Cents)

    CEG cents. 100 cents = $1.
    Inherits all functionality from base_currency.
]]--

ITEM.name = "Coins"
ITEM.description = "CEG cents."
ITEM.model = "models/stevencz/Other/coin/c001.mdl"
ITEM.base = "base_currency"

-- Currency configuration
ITEM.currencyValue = 1  -- cents per unit (1 coin = 1 cent)
ITEM.unitName = "cent"
ITEM.unitNamePlural = "cents"
ITEM.unitSymbol = "¢"
ITEM.symbolPrefix = false  -- 50¢ format
-- canDestroy defaults to false (coins cannot be destroyed)
