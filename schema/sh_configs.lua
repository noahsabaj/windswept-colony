--[[
    Windswept Colony RP - Configuration
]]--

ws.currency.symbol = "$"
ws.currency.singular = "dollar"
ws.currency.plural = "dollars"

-- Register the Colony currency denominations with the framework. The framework's currency
-- logic is denomination-agnostic and reads only this registry, so the schema (not the
-- framework) owns which items are money and what they're worth. Values are in cents:
-- cash = $1 (100c), coins = 1c. (layer-2)
ws.currency.RegisterDenomination("cash", 100, 100)
ws.currency.RegisterDenomination("coins", 1, 100)