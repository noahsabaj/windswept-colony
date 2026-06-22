--[[
    Door System (Colony schema)

    The Colony's physical door system: map-door frame detection, breakable
    prop_door_rotating entities with health/types, lockable doors with physical
    keys, battering-ram breaching, per-map persistence, and client frame
    visualization.

    Split for hygiene from the former 1328-line sh_doors.lua god-file into
    one-responsibility fragments under doors/ (the public ws.doors.* API is
    unchanged). This loader fixes include order: the shared core first, then the
    server fragments, then the client visualization. Cross-fragment references
    are all runtime, so only the core (which defines the ws.doors table and the
    config it reads) must load before the rest.
]]--

ws.util.Include("doors/sh_doors_core.lua")        -- state, type/model config, shared helpers
ws.util.Include("doors/sv_doors_frames.lua")      -- map-door frame detection + visual capture/restore
ws.util.Include("doors/sv_doors_sync.lua")        -- server->client frame sync
ws.util.Include("doors/sv_doors_spawn.lua")       -- door entity spawn/remove + type-config accessor
ws.util.Include("doors/sv_doors_locks.lua")       -- lock install/remove/lock/unlock/damage/repair
ws.util.Include("doors/sv_doors_damage.lua")      -- door health: damage/destruction/repair
ws.util.Include("doors/sv_doors_breach.lua")      -- battering-ram breach + debris
ws.util.Include("doors/sv_doors_persistence.lua") -- save/load + debounced flush + bootstrap
ws.util.Include("doors/sv_doors_partners.lua")    -- double-door partner linking
ws.util.Include("doors/sv_doors_init.lua")        -- InitPostEntity orchestrator + shutdown/autosave
ws.util.Include("doors/sv_doors_commands.lua")    -- admin frame commands
ws.util.Include("doors/cl_doors_frames.lua")      -- client frame visualization
