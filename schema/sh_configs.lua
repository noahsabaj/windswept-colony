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

-- Wire the Colony wallet item + denominations into the framework wallet plugin and turn
-- on wallet routing (received money flows into wallets before the main inventory). The
-- wallet item itself is Colony content (schema/items/currency/sh_wallet.lua); the plugin
-- only provides the routing. (layer-wallet)
ws.wallet = ws.wallet or {}
ws.wallet.itemID = "wallet"
ws.wallet.cashID = "cash"
ws.wallet.coinID = "coins"
hook.Add("InitializedConfig", "wsColonyEnableWallet", function()
    ws.config.Set("walletEnabled", true)
end)

-- Colony RP is set in the year 2200. The framework's date engine defaults to no offset
-- (in-game year = real year); the schema owns the setting's era, so we offset the in-game
-- clock here (real 2026 + 174 = 2200). ws.date.Initialize() reads this in GM:InitializedConfig,
-- which fires after the schema loads, so setting it at schema-load time is in time.
ws.date.yearOffset = 174