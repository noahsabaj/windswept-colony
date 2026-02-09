--[[
    Locksmith Machine - Server

    Year 2200, everything is automated.
    Handles lock/key programming operations.
]]--

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Network strings registered in schema/sv_netstrings.lua

function ENT:Initialize()
    self:SetModel("models/props_lab/reciever01b.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(CONTINUOUS_USE) -- For hold E detection

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    self:SetInUse(false)

    -- Track hold E for pickup
    self.holdEStart = {}
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    -- Track hold E for pickup
    if not self.holdEStart[activator] then
        self.holdEStart[activator] = CurTime()
    end

    local holdTime = CurTime() - self.holdEStart[activator]
    local pickupTime = ix.config.Get("itemPickupTime", 0.5)

    -- Check if held long enough for pickup
    if holdTime >= pickupTime then
        self:PickupByPlayer(activator)
        self.holdEStart[activator] = nil
        return
    end
end

-- Check for press release and handle actions
function ENT:Think()
    for ply, startTime in pairs(self.holdEStart or {}) do
        if not IsValid(ply) then
            self.holdEStart[ply] = nil
            continue
        end

        -- Check if player released E
        if not ply:KeyDown(IN_USE) then
            local holdTime = CurTime() - startTime
            local pickupTime = ix.config.Get("itemPickupTime", 0.5)

            -- Short press (released before pickup time) = open UI
            if holdTime < pickupTime then
                if self:GetInUse() and self:GetUser() ~= ply then
                    ply:NotifyLocalized("locksmithInUse")
                else
                    -- Open locksmith UI
                    self:SetInUse(true)
                    self:SetUser(ply)

                    net.Start("ixLocksmithOpen")
                        net.WriteEntity(self)
                    net.Send(ply)
                end
            end

            -- Clean up tracking
            self.holdEStart[ply] = nil
        end
    end
end

function ENT:PickupByPlayer(client)
    if not IsValid(client) then return end

    local character, inventory = ix.constants.GetCharacterInventory(client)
    if not character or not inventory then return end

    -- Check if there's room in inventory (locksmith_station is 2x1)
    if not inventory:FindEmptySlot(2, 1) then
        client:NotifyLocalized("inventoryFull")
        return
    end

    -- Close UI if someone is using it
    if self:GetInUse() then
        self:CloseForUser(self:GetUser())
    end

    -- Add item to inventory
    inventory:Add("locksmith_station", 1)

    -- Remove entity
    self:Remove()
end

function ENT:CloseForUser(user)
    if self:GetUser() == user then
        self:SetInUse(false)
        self:SetUser(NULL)
    end
end

-- ============================================================================
-- NETWORKING - Operations
-- ============================================================================

net.Receive("ixLocksmithClose", function(len, ply)
    local ent = net.ReadEntity()
    if not IsValid(ent) or ent:GetClass() ~= "ix_auto_locksmith" then return end

    ent:CloseForUser(ply)
end)

-- Program a blank lock
net.Receive("ixLocksmithProgramLock", function(len, ply)
    local ent = net.ReadEntity()
    local lockItemID = net.ReadUInt(32)

    if not IsValid(ent) or ent:GetClass() ~= "ix_auto_locksmith" then return end
    if ent:GetUser() ~= ply then return end

    local lockItem = ix.constants.VerifyItemOwnership(ply, lockItemID, "lock_blank")
    if not lockItem then
        ply:NotifyLocalized("locksmithInvalidItem")
        return
    end

    local _, inventory = ix.constants.GetCharacterInventory(ply)
    if not inventory then return end

    -- Generate keying
    local keying = ent:GenerateKeying()

    -- Remove blank lock, add programmed lock
    local quantity = lockItem:GetData("quantity", 1)
    if quantity > 1 then
        lockItem:SetData("quantity", quantity - 1)
    else
        inventory:Remove(lockItemID)
    end

    -- Add programmed lock
    inventory:Add("lock", 1, {
        keyings = {keying},
        durability = 100,
        lockName = ""
    })

    ply:EmitSound("buttons/button14.wav", 50)
    ply:NotifyLocalized("locksmithLockProgrammed", keying)

    -- Send result back
    net.Start("ixLocksmithResult")
        net.WriteString("programLock")
        net.WriteString(keying)
    net.Send(ply)
end)

-- Program a blank key from a lock or key
net.Receive("ixLocksmithProgramKey", function(len, ply)
    local ent = net.ReadEntity()
    local blankKeyID = net.ReadUInt(32)
    local sourceID = net.ReadUInt(32)

    if not IsValid(ent) or ent:GetClass() ~= "ix_auto_locksmith" then return end
    if ent:GetUser() ~= ply then return end

    local blankKey = ix.constants.VerifyItemOwnership(ply, blankKeyID, "key_blank")
    if not blankKey then
        ply:NotifyLocalized("locksmithInvalidItem")
        return
    end

    -- Source can be a lock or key (no uniqueID filter)
    local sourceItem = ix.constants.VerifyItemOwnership(ply, sourceID)
    if not sourceItem then
        ply:NotifyLocalized("locksmithNotYourItem")
        return
    end

    local _, inventory = ix.constants.GetCharacterInventory(ply)
    if not inventory then return end

    -- Source must be a lock or key
    local keying = nil
    if sourceItem.uniqueID == "lock" then
        local keyings = sourceItem:GetData("keyings", {})
        if #keyings == 0 then
            ply:NotifyLocalized("locksmithSourceNotProgrammed")
            return
        end
        keying = keyings[1]  -- Copy first keying
    elseif sourceItem.uniqueID == "key" then
        keying = sourceItem:GetData("keying", "")
        if keying == "" then
            ply:NotifyLocalized("locksmithSourceNotProgrammed")
            return
        end
    else
        ply:NotifyLocalized("locksmithInvalidSource")
        return
    end

    -- Remove blank key
    local quantity = blankKey:GetData("quantity", 1)
    if quantity > 1 then
        blankKey:SetData("quantity", quantity - 1)
    else
        inventory:Remove(blankKeyID)
    end

    -- Add programmed key
    inventory:Add("key", 1, {
        keying = keying,
        keyName = ""
    })

    ply:EmitSound("buttons/button14.wav", 50)
    ply:NotifyLocalized("locksmithKeyProgrammed", keying)

    net.Start("ixLocksmithResult")
        net.WriteString("programKey")
        net.WriteString(keying)
    net.Send(ply)
end)

-- Add a keying to a lock (using a key)
net.Receive("ixLocksmithAddKeying", function(len, ply)
    local ent = net.ReadEntity()
    local lockID = net.ReadUInt(32)
    local keyID = net.ReadUInt(32)

    if not IsValid(ent) or ent:GetClass() ~= "ix_auto_locksmith" then return end
    if ent:GetUser() ~= ply then return end

    local lockItem = ix.constants.VerifyItemOwnership(ply, lockID, "lock")
    if not lockItem then
        ply:NotifyLocalized("locksmithInvalidItem")
        return
    end

    local keyItem = ix.constants.VerifyItemOwnership(ply, keyID, "key")
    if not keyItem then
        ply:NotifyLocalized("locksmithNeedKey")
        return
    end

    local keyings = lockItem:GetData("keyings", {})
    local keyKeying = keyItem:GetData("keying", "")

    if keyKeying == "" then
        ply:NotifyLocalized("locksmithKeyNotProgrammed")
        return
    end

    -- Check if already has this keying
    for _, k in ipairs(keyings) do
        if k == keyKeying then
            ply:NotifyLocalized("locksmithAlreadyHasKeying")
            return
        end
    end

    -- Check max keyings
    if #keyings >= 3 then
        ply:NotifyLocalized("locksmithMaxKeyings")
        return
    end

    -- Add keying
    table.insert(keyings, keyKeying)
    lockItem:SetData("keyings", keyings)

    ply:EmitSound("buttons/button14.wav", 50)
    ply:NotifyLocalized("locksmithKeyingAdded", keyKeying)

    net.Start("ixLocksmithResult")
        net.WriteString("addKeying")
        net.WriteString(keyKeying)
    net.Send(ply)
end)

-- Rename a lock or key
net.Receive("ixLocksmithRename", function(len, ply)
    local ent = net.ReadEntity()
    local itemID = net.ReadUInt(32)
    local newName = net.ReadString()

    if not IsValid(ent) or ent:GetClass() ~= "ix_auto_locksmith" then return end
    if ent:GetUser() ~= ply then return end

    -- No uniqueID filter - rename works on both locks and keys
    local item = ix.constants.VerifyItemOwnership(ply, itemID)
    if not item then
        ply:NotifyLocalized("locksmithInvalidItem")
        return
    end

    -- Sanitize name
    newName = string.sub(newName, 1, 32)
    newName = string.Trim(newName)

    if item.uniqueID == "lock" then
        -- Check if already named
        local currentName = item:GetData("lockName", "")
        if currentName ~= "" then
            ply:NotifyLocalized("locksmithAlreadyNamed")
            return
        end

        item:SetData("lockName", newName)
        ply:NotifyLocalized("locksmithLockRenamed", newName)

    elseif item.uniqueID == "key" then
        -- Check if already named
        local currentName = item:GetData("keyName", "")
        if currentName ~= "" then
            ply:NotifyLocalized("locksmithAlreadyNamed")
            return
        end

        item:SetData("keyName", newName)
        ply:NotifyLocalized("locksmithKeyRenamed", newName)

    else
        ply:NotifyLocalized("locksmithInvalidItem")
        return
    end

    ply:EmitSound("buttons/button14.wav", 50)

    net.Start("ixLocksmithResult")
        net.WriteString("rename")
        net.WriteString(newName)
    net.Send(ply)
end)

-- View lock keyings
net.Receive("ixLocksmithViewKeyings", function(len, ply)
    local ent = net.ReadEntity()
    local lockID = net.ReadUInt(32)

    if not IsValid(ent) or ent:GetClass() ~= "ix_auto_locksmith" then return end
    if ent:GetUser() ~= ply then return end

    local lockItem = ix.constants.VerifyItemOwnership(ply, lockID, "lock")
    if not lockItem then
        ply:NotifyLocalized("locksmithInvalidItem")
        return
    end

    local keyings = lockItem:GetData("keyings", {})

    net.Start("ixLocksmithResult")
        net.WriteString("viewKeyings")
        net.WriteUInt(#keyings, 8)
        for _, k in ipairs(keyings) do
            net.WriteString(k)
        end
    net.Send(ply)
end)
