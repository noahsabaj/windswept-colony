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

-- Colony RP is set in the year 2200. The framework's date engine defaults to no offset
-- (in-game year = real year); the schema owns the setting's era, so we offset the in-game
-- clock here (real 2026 + 174 = 2200). ws.date.Initialize() reads this in GM:InitializedConfig,
-- which fires after the schema loads, so setting it at schema-load time is in time.
ws.date.yearOffset = 174