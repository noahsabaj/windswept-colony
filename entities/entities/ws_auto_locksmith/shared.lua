--[[
    Locksmith Machine - Shared

    A machine for programming locks and keys.
    Year 2200, everything is automated.

    Operations:
    - Program Lock: Blank Lock -> Lock with auto-generated keying
    - Program Key: Blank Key + Lock/Key -> Key with copied keying
    - Add Keying: Lock + Key -> Lock accepts that key's keying
    - Rename Lock/Key: One-time cosmetic rename
    - View Lock Keyings: Shows all accepted keyings
]]--

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Locksmith"
ENT.Author = "Windswept"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.Category = "Windswept"

-- Keying generation settings (same as locksmith station)
ENT.KeyingLength = 6
ENT.KeyingChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  -- No I, O, 0, 1 to avoid confusion

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "InUse")
    self:NetworkVar("Entity", 0, "User")
end

-- Generate a random keying ID
function ENT:GenerateKeying()
    local keying = ""
    for i = 1, self.KeyingLength do
        local idx = math.random(1, #self.KeyingChars)
        keying = keying .. string.sub(self.KeyingChars, idx, idx)
    end
    return keying
end

-- Validate keying format
function ENT:ValidateKeying(keying)
    if not keying or type(keying) ~= "string" then return false end
    if #keying ~= self.KeyingLength then return false end

    keying = string.upper(keying)
    for i = 1, #keying do
        local char = string.sub(keying, i, i)
        if not string.find(self.KeyingChars, char, 1, true) then
            return false
        end
    end

    return true
end
