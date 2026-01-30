--[[
    Physical Door Entity - Shared

    Custom door entity that replaces map doors.
    Allows different door types (wood, metal, gate) in any frame.
]]--

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Door"
ENT.Author = "Windswept"
ENT.Spawnable = false
ENT.AdminSpawnable = false

-- Door type configurations
ENT.DoorTypes = {
    wood = {
        model = "models/props_c17/door01_left.mdl",
        maxHealth = 100,
        ramResistance = 1.0,
        fistDamageable = true,
        material = "wood"
    },
    metal = {
        model = "models/props_doors/door03_slotted_left.mdl",
        maxHealth = 250,
        ramResistance = 0.4,
        fistDamageable = false,
        material = "metal"
    },
    gate = {
        model = "models/props_c17/gate_door01a.mdl",
        maxHealth = 175,
        ramResistance = 0.65,
        fistDamageable = false,
        material = "metal"
    }
}

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "DoorType")      -- "wood", "metal", "gate"
    self:NetworkVar("Int", 0, "Health")           -- Current HP
    self:NetworkVar("Int", 1, "MaxHealth")        -- Max HP for type
    self:NetworkVar("Bool", 0, "Locked")          -- Lock state
    self:NetworkVar("Bool", 1, "Open")            -- Open/closed state
    self:NetworkVar("String", 1, "LockDataJSON")  -- JSON: {keyings, durability, name}
    self:NetworkVar("String", 2, "FrameID")       -- MapCreationID of frame

    -- Set defaults
    if SERVER then
        self:SetDoorType("wood")
        self:SetHealth(100)
        self:SetMaxHealth(100)
        self:SetLocked(false)
        self:SetOpen(false)
        self:SetLockDataJSON("")
        self:SetFrameID("")
    end
end

function ENT:GetTypeConfig()
    local doorType = self:GetDoorType()
    return self.DoorTypes[doorType] or self.DoorTypes.wood
end

-- Lock data helpers (JSON encoded for networking)
function ENT:GetLockData()
    local json = self:GetLockDataJSON()
    if not json or json == "" then return nil end

    local data = util.JSONToTable(json)
    return data
end

function ENT:SetLockData(data)
    if data then
        self:SetLockDataJSON(util.TableToJSON(data))
    else
        self:SetLockDataJSON("")
    end
end

function ENT:HasLock()
    return self:GetLockData() ~= nil
end

function ENT:GetLockKeyings()
    local lockData = self:GetLockData()
    if not lockData then return {} end
    return lockData.keyings or {}
end

-- Health percentage for visual damage
function ENT:GetHealthPercent()
    local maxHealth = self:GetMaxHealth()
    if maxHealth <= 0 then return 0 end
    return (self:GetHealth() / maxHealth) * 100
end

function ENT:GetCondition()
    local percent = self:GetHealthPercent()
    if percent >= 76 then
        return "intact"
    elseif percent >= 51 then
        return "minor"
    elseif percent >= 26 then
        return "moderate"
    else
        return "severe"
    end
end
