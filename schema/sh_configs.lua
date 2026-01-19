--[[
    Windswept Colony RP - Configuration

    Note: Use ix.config.SetDefault only for configs that are guaranteed to exist.
    These configs are defined by Helix core, so SetDefault is safe here.
    The values below override Helix's defaults for this schema.
]]--

-- Wrap in a hook to ensure Helix configs are loaded first
hook.Add("InitializedConfig", "WindsweptConfigDefaults", function()
    -- Starting money for new characters
    ix.config.SetDefault("defaultMoney", 100)

    -- Character creation settings
    ix.config.SetDefault("maxCharacters", 3)

    -- Inventory settings
    ix.config.SetDefault("invW", 6)
    ix.config.SetDefault("invH", 4)
end)
