-- One-time migration for factionless support
-- Converts all "civilians" faction characters to NULL (factionless)

hook.Add("InitPostEntity", "ixFactionlessMigration", function()
    -- Check if migration has already run
    if (file.Exists("helix/migrations/factionless_v1.txt", "DATA")) then
        return
    end

    timer.Simple(5, function() -- Wait for database connection
        local query = mysql:Update("ix_characters")
        query:Update("faction", "NULL")
        query:Where("faction", "civilians")
        query:Where("schema", Schema.folder)
        query:Callback(function(result, status, lastID)
            if (status) then
                -- Mark migration as complete
                file.CreateDir("helix/migrations")
                file.Write("helix/migrations/factionless_v1.txt", os.date())
            else
            end
        end)
        query:Execute()
    end)
end)
