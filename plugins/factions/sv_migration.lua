--[[
    Factions Plugin - Database Migration
    Bootstrap anchor and default classes on first run
]]--

ix.factions = ix.factions or {}
ix.factions.migrations = ix.factions.migrations or {}

function ix.factions.RunMigrations()
    -- Check migration version
    local query = mysql:Select("ix_faction_config")
    query:Limit(1)
    query:Callback(function(result)
        if not result or #result == 0 then
            -- First run - create anchor and default classes
            ix.factions.BootstrapClasses()
        end
    end)
    query:Execute()
end

function ix.factions.BootstrapClasses()
    local now = os.time()

    -- Define anchor classes (rank 255) - faction leaders
    local anchorClasses = {
        -- Administration (Mayor elected, appoints Judge, CMO, Fire Chief)
        {faction = "administration", uniqueID = "mayor", name = "Mayor", pay = 200},

        -- Security (Commissioner elected)
        {faction = "security", uniqueID = "commissioner", name = "Commissioner", pay = 150},

        -- Miners Union (Union President elected)
        {faction = "minersunion", uniqueID = "union_president", name = "Union President", pay = 150},

        -- Medical (CMO appointed by Mayor)
        {faction = "medical", uniqueID = "cmo", name = "Chief Medical Officer", pay = 140},

        -- Fire Brigade (Fire Chief appointed by Mayor)
        {faction = "firebrigade", uniqueID = "fire_chief", name = "Fire Chief", pay = 100},

        -- Corrections (Warden appointed by Commissioner)
        {faction = "corrections", uniqueID = "warden", name = "Warden", pay = 100},

        -- Conglomerate - Governor has subordinate authority over Administration AND Security
        -- Governor is appointed by admin, Head Foreman by Confederation
        {faction = "conglomerate", uniqueID = "governor", name = "Governor", pay = 300},
        {faction = "conglomerate", uniqueID = "head_foreman", name = "Head Foreman", pay = 200},
    }

    -- Define high-ranking non-anchor classes (these are static, defined in Lua)
    -- Deputies are rank 254 (directly below their leader), others are rank 200
    local staticClasses = {
        {faction = "administration", uniqueID = "deputy_mayor", name = "Deputy Mayor", pay = 150, rank = 254},
        {faction = "administration", uniqueID = "judge", name = "Judge", pay = 120, rank = 200},
        {faction = "security", uniqueID = "deputy_commissioner", name = "Deputy Commissioner", pay = 120, rank = 254},
        {faction = "minersunion", uniqueID = "vice_president", name = "Vice President", pay = 130, rank = 254},
    }

    -- Define default classes (rank 0) - entry point for each faction
    local defaultClasses = {
        {faction = "administration", uniqueID = "admin_default", name = "Administrator", pay = 75},
        {faction = "security", uniqueID = "security_default", name = "Recruit", pay = 50},
        {faction = "minersunion", uniqueID = "union_default", name = "Union Member", pay = 115},
        {faction = "medical", uniqueID = "medical_default", name = "Orderly", pay = 70},
        {faction = "corrections", uniqueID = "corrections_default", name = "Guard", pay = 60},
        {faction = "firebrigade", uniqueID = "fire_default", name = "Firefighter", pay = 40},
        {faction = "conglomerate", uniqueID = "conglomerate_default", name = "Worker", pay = 150},
        {faction = "confederation", uniqueID = "confederation_default", name = "Agent", pay = 200},
        {faction = "prisoners", uniqueID = "prisoner_default", name = "Prisoner", pay = 0},
    }

    -- Insert anchor classes (rank 255)
    for _, class in ipairs(anchorClasses) do
        local query = mysql:Insert("ix_faction_classes")
        query:Insert("faction", class.faction)
        query:Insert("unique_id", class.uniqueID)
        query:Insert("name", class.name)
        query:Insert("description", "Faction leader position.")
        query:Insert("rank", 255)
        query:Insert("pay", class.pay)
        query:Insert("permissions", "{}")
        query:Insert("is_anchor", 1)
        query:Insert("is_default", 0)
        query:Insert("created_at", now)
        query:Insert("updated_at", now)
        query:Execute()
    end

    -- Insert static non-anchor classes (Deputy Mayor, Judge, Deputy Commissioner, Vice President)
    for _, class in ipairs(staticClasses) do
        local query = mysql:Insert("ix_faction_classes")
        query:Insert("faction", class.faction)
        query:Insert("unique_id", class.uniqueID)
        query:Insert("name", class.name)
        query:Insert("description", "Appointed position.")
        query:Insert("rank", class.rank)
        query:Insert("pay", class.pay)
        query:Insert("permissions", "{}")
        query:Insert("is_anchor", 0)
        query:Insert("is_default", 0)
        query:Insert("created_at", now)
        query:Insert("updated_at", now)
        query:Execute()
    end

    -- Insert default classes (rank 0)
    for _, class in ipairs(defaultClasses) do
        local query = mysql:Insert("ix_faction_classes")
        query:Insert("faction", class.faction)
        query:Insert("unique_id", class.uniqueID)
        query:Insert("name", class.name)
        query:Insert("description", "Default entry class.")
        query:Insert("rank", 0)
        query:Insert("pay", class.pay)
        query:Insert("permissions", "{}")
        query:Insert("is_anchor", 0)
        query:Insert("is_default", 1)
        query:Insert("created_at", now)
        query:Insert("updated_at", now)
        query:Execute()
    end

    -- Insert faction config (9 factions)
    -- Hierarchy: Confederation (CEG) oversees Administration and Security
    -- Administration oversees Medical and Fire Brigade
    -- Security oversees Corrections
    -- Miners Union, Conglomerate (EEC), and Prisoners are independent
    local factionConfigs = {
        {faction = "administration", subordinateOf = "confederation"},  -- CEG oversees Mayor
        {faction = "security", subordinateOf = "confederation"},        -- CEG oversees Commissioner
        {faction = "minersunion", subordinateOf = nil},                 -- Independent labor union
        {faction = "medical", subordinateOf = "administration"},        -- Mayor appoints CMO
        {faction = "corrections", subordinateOf = "security"},          -- Commissioner appoints Warden
        {faction = "firebrigade", subordinateOf = "administration"},    -- Mayor appoints Fire Chief
        {faction = "conglomerate", subordinateOf = nil},                -- Independent corporation (EEC)
        {faction = "confederation", subordinateOf = nil},               -- Top level (admin/event)
        {faction = "prisoners", subordinateOf = nil},                   -- No leadership structure
    }

    for _, config in ipairs(factionConfigs) do
        local query = mysql:Insert("ix_faction_config")
        query:Insert("faction", config.faction)
        if config.subordinateOf then
            query:Insert("subordinate_of", config.subordinateOf)
        end
        query:Insert("updated_at", now)
        query:Execute()
    end

    print("[Factions] Bootstrap complete - created anchor, static, and default classes")
end

-- Migration: Add offline promotion columns to votes table
function ix.factions.MigrateVotesTable()
    -- Add anchor_class_id column if it doesn't exist
    local query1 = mysql:RawQuery([[
        ALTER TABLE ix_faction_votes
        ADD COLUMN IF NOT EXISTS anchor_class_id INT NULL,
        ADD COLUMN IF NOT EXISTS promotion_applied TINYINT(1) DEFAULT 0
    ]])
    query1:Callback(function(result, status, err)
        if err then
            -- Column might already exist, or syntax not supported - try individual statements
            local q1 = mysql:RawQuery("ALTER TABLE ix_faction_votes ADD COLUMN anchor_class_id INT NULL")
            q1:Execute()

            local q2 = mysql:RawQuery("ALTER TABLE ix_faction_votes ADD COLUMN promotion_applied TINYINT(1) DEFAULT 0")
            q2:Execute()
        end
    end)
    query1:Execute()
end

-- Run on server start
hook.Add("InitPostEntity", "ixFactionMigration", function()
    timer.Simple(5, function()
        ix.factions.RunMigrations()
        ix.factions.MigrateVotesTable()
    end)
end)
