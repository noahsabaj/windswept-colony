--[[
    Toolkit SWEP

    Controls:
    - RMB on door with lock: Remove lock (door must be unlocked - no key needed)
    - RMB on door without lock: Remove door (door must be unlocked)
    - LMB on damaged door: Repair door (requires materials)
    - LMB on damaged lock: Repair lock (requires metal)

    Note: A door cannot be removed while it has a lock installed. Remove the lock first.
    If a door is locked and you lost the key, use a lockpick to unlock it first.
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Toolkit"
SWEP.Purpose = "Work on doors and locks."
SWEP.Instructions = "RMB: Remove | LMB: Repair"

SWEP.WorldModel = "models/props_c17/tools_wrench01a.mdl"

-- Maximum distance to interact
SWEP.MaxUseDistance = 96

-- Base times (modified by toolkit size)
SWEP.BaseDoorRemoveTime = 20
SWEP.BaseLockRemoveTime = 6
SWEP.BaseRepairRate = 10  -- HP per second

-- ============================================================================
-- NETWORKING
-- ============================================================================

-- Network strings registered in schema/sv_netstrings.lua

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Working")
    self:NetworkVar("Float", 0, "WorkStartTime")
    self:NetworkVar("Float", 1, "WorkDuration")
    self:NetworkVar("String", 0, "WorkType")  -- "removeDoor", "removeLock", "repairDoor", "repairLock"
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Deploy()
    self.BaseClass.Deploy(self)
    self:CancelWork()
    return true
end

function SWEP:Holster()
    self:CancelWork()
    return true
end

function SWEP:OnRemove()
    self:CancelWork()
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function SWEP:IsWorking()
    if not self.GetWorking then return false end
    return self:GetWorking()
end

function SWEP:GetTargetDoor()
    local owner = self:GetOwner()
    if not IsValid(owner) then return nil end

    -- Cache trace result on server to avoid TraceLine every frame during work
    -- (Think() calls this repeatedly while working)
    if SERVER and self:IsWorking() then
        local now = CurTime()
        if self._lastTraceTime and (now - self._lastTraceTime) < 0.1 then
            return self._cachedDoor
        end
        self._lastTraceTime = now
    end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.MaxUseDistance,
        filter = owner
    })

    local ent = tr.Entity
    if not IsValid(ent) then
        self._cachedDoor = nil
        return nil
    end

    -- Check if it's our managed door
    if ent.ixIsWindsweptDoor then
        self._cachedDoor = ent
        return ent
    end

    self._cachedDoor = nil
    return nil
end

function SWEP:GetTimeMultiplier(workType)
    local item = self.ixItem
    if not item then return 1 end

    if workType == "removeDoor" then
        return item:GetDoorRemoveMultiplier()
    elseif workType == "removeLock" then
        return item:GetLockRemoveMultiplier()
    elseif workType == "repairDoor" then
        return item:GetDoorInstallMultiplier()  -- Use install multiplier for repair
    elseif workType == "repairLock" then
        return item:GetLockInstallMultiplier()
    end

    return 1
end

function SWEP:HasRepairMaterial(materialType)
    local owner = self:GetOwner()
    if not IsValid(owner) then return false, nil end

    local character, inventory = ix.constants.GetCharacterInventory(owner)
    if not character or not inventory then return false, nil end

    local targetID = materialType == "wood" and "wood_planks" or "metal_sheets"

    for _, item in pairs(inventory:GetItems()) do
        if item.uniqueID == targetID then
            return true, item
        end
    end

    return false, nil
end

function SWEP:HasMatchingKey(door)
    local owner = self:GetOwner()
    if not IsValid(owner) then return false end

    local character, inventory = ix.constants.GetCharacterInventory(owner)
    if not character or not inventory then return false end

    local lockData = door.ixLockData
    if not lockData or not lockData.keyings then return false end

    -- Check inventory for a key with matching keying
    for _, item in pairs(inventory:GetItems()) do
        if item.uniqueID == "key" then
            local keyKeying = item:GetData("keying", "")
            for _, lockKeying in ipairs(lockData.keyings) do
                if keyKeying == lockKeying then
                    return true
                end
            end
        end
    end

    return false
end

-- ============================================================================
-- NET RECEIVERS (Server)
-- ============================================================================

if SERVER then
    ix.weapon.NetReceive("ixToolkitStartRemove", "ix_toolkit", "StartRemove")
    ix.weapon.NetReceive("ixToolkitStartRepair", "ix_toolkit", "StartRepair")
    ix.weapon.NetReceive("ixToolkitCancel", "ix_toolkit", "CancelWork")
end

-- ============================================================================
-- START REMOVE (Determines what to remove)
-- ============================================================================

function SWEP:StartRemove()
    if CLIENT then return end
    if not self.SetWorking then return end
    if self:IsWorking() then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("toolkitNoDoor")
        return
    end

    -- Door must be unlocked
    if door:IsLocked() then
        owner:NotifyLocalized("toolkitDoorLocked")
        return
    end

    local hasLock = ix.doors.HasLock(door)

    if hasLock then
        -- Door has lock - since door is already verified unlocked, we can remove the lock
        -- (the lock mechanism is disengaged when unlocked, so no key needed to remove it)
        self:StartRemoveLock(door)
    else
        -- No lock - can remove door
        self:StartRemoveDoor(door)
    end
end

function SWEP:StartRemoveDoor(door)
    local owner = self:GetOwner()

    local workTime = self.BaseDoorRemoveTime * self:GetTimeMultiplier("removeDoor")
    self:SetWorking(true)
    self:SetWorkStartTime(CurTime())
    self:SetWorkDuration(workTime)
    self:SetWorkType("removeDoor")
    self.targetDoor = door

    door:EmitSound("physics/metal/metal_box_scrape1.wav", 50)
end

function SWEP:StartRemoveLock(door)
    local owner = self:GetOwner()

    local workTime = self.BaseLockRemoveTime * self:GetTimeMultiplier("removeLock")
    self:SetWorking(true)
    self:SetWorkStartTime(CurTime())
    self:SetWorkDuration(workTime)
    self:SetWorkType("removeLock")
    self.targetDoor = door

    door:EmitSound("physics/metal/metal_box_scrape2.wav", 50)
end

-- ============================================================================
-- START REPAIR (Determines what to repair)
-- ============================================================================

function SWEP:StartRepair()
    if CLIENT then return end
    if not self.SetWorking then return end
    if self:IsWorking() then return end

    local owner = self:GetOwner()
    local door = self:GetTargetDoor()

    if not IsValid(door) then
        owner:NotifyLocalized("toolkitNoDoor")
        return
    end

    local lockData = door.ixLockData
    local config = ix.doors.GetTypeConfig(door)
    local maxHealth = door.ixMaxHealth or config.maxHealth
    local health = door.ixHealth or maxHealth
    local doorDamaged = health < maxHealth
    local lockDamaged = lockData and lockData.durability and lockData.durability < 100

    -- Prioritize lock repair if lock is damaged and unlocked
    if lockData and lockDamaged and not door:IsLocked() then
        self:StartRepairLock(door)
    elseif doorDamaged then
        self:StartRepairDoor(door)
    else
        owner:NotifyLocalized("toolkitNothingToRepair")
    end
end

function SWEP:StartRepairDoor(door)
    local owner = self:GetOwner()

    -- Determine material needed
    local config = ix.doors.GetTypeConfig(door)
    local materialType = config.material or "wood"
    local hasMaterial, materialItem = self:HasRepairMaterial(materialType)

    if not hasMaterial then
        if materialType == "wood" then
            owner:NotifyLocalized("toolkitNeedWood")
        else
            owner:NotifyLocalized("toolkitNeedMetal")
        end
        return
    end

    -- Calculate repair time based on damage
    local maxHealth = door.ixMaxHealth or config.maxHealth
    local health = door.ixHealth or maxHealth
    local damagePercent = 1 - (health / maxHealth)
    local baseRepairTime = 10  -- Base time for full repair
    local repairTime = baseRepairTime * damagePercent * self:GetTimeMultiplier("repairDoor")

    self:SetWorking(true)
    self:SetWorkStartTime(CurTime())
    self:SetWorkDuration(math.max(repairTime, 2))  -- Minimum 2 seconds
    self:SetWorkType("repairDoor")
    self.targetDoor = door
    self.repairMaterial = materialItem

    door:EmitSound("physics/metal/metal_box_scrape1.wav", 50)
end

function SWEP:StartRepairLock(door)
    local owner = self:GetOwner()

    -- Need metal sheets for lock repair
    local hasMaterial, materialItem = self:HasRepairMaterial("metal")
    if not hasMaterial then
        owner:NotifyLocalized("toolkitNeedMetal")
        return
    end

    -- Calculate repair time based on damage
    local durability = door.ixLockData.durability or 100
    local damagePercent = 1 - (durability / 100)
    local baseRepairTime = 6  -- Base time for full lock repair
    local repairTime = baseRepairTime * damagePercent * self:GetTimeMultiplier("repairLock")

    self:SetWorking(true)
    self:SetWorkStartTime(CurTime())
    self:SetWorkDuration(math.max(repairTime, 2))
    self:SetWorkType("repairLock")
    self.targetDoor = door
    self.repairMaterial = materialItem

    door:EmitSound("physics/metal/metal_box_scrape2.wav", 50)
end

-- ============================================================================
-- CANCEL WORK
-- ============================================================================

function SWEP:CancelWork()
    ix.constants.CancelSWEPAction(self, function() return self:IsWorking() end, function()
        self:SetWorking(false)
        self.targetDoor = nil
        self.repairMaterial = nil
    end)
end

-- ============================================================================
-- COMPLETE WORK
-- ============================================================================

function SWEP:CompleteWork()
    if CLIENT then return end

    local owner = self:GetOwner()
    local door = self.targetDoor
    local workType = self:GetWorkType()

    if not IsValid(door) then
        self:CancelWork()
        return
    end

    local item = self.ixItem

    if workType == "removeDoor" then
        self:CompleteRemoveDoor(owner, door, item)
    elseif workType == "removeLock" then
        self:CompleteRemoveLock(owner, door, item)
    elseif workType == "repairDoor" then
        self:CompleteRepairDoor(owner, door, item)
    elseif workType == "repairLock" then
        self:CompleteRepairLock(owner, door, item)
    end

    self:SetWorking(false)
    self.targetDoor = nil
    self.repairMaterial = nil
end

function SWEP:CompleteRemoveDoor(owner, door, item)
    local character, inventory = ix.constants.GetCharacterInventory(owner)
    if not character or not inventory then
        self:CancelWork()
        return
    end

    -- Determine door type item
    local doorType = door.ixDoorType or "wood"
    local doorItemID = "door_" .. doorType
    local doorHealth = door.ixHealth or 100
    local doorPos = door:GetPos()

    -- Try to add door to inventory
    local success = inventory:Add(doorItemID, 1, {
        health = doorHealth
    })

    if not success then
        -- Inventory full - drop door on ground
        ix.item.Spawn(doorItemID, doorPos + Vector(0, 0, 10), nil, nil, {
            health = doorHealth
        })
        owner:NotifyLocalized("toolkitDoorDropped")
    end

    -- Clear frame and remove door
    local frameID = door.ixFrameID
    if frameID then
        local mapID = tonumber(frameID)
        if mapID and ix.doors.frames[mapID] then
            ix.doors.frames[mapID].hasDoor = false
            ix.doors.frames[mapID].doorEntity = nil
        end
    end

    -- Remove door entity
    door:Remove()

    -- Damage toolkit
    if item and item.TakeDurabilityDamage then
        item:TakeDurabilityDamage(2)
    end

    owner:EmitSound("physics/wood/wood_crate_impact_soft2.wav", 60)
    owner:NotifyLocalized("toolkitDoorRemoved")

    -- Sync and save
    ix.doors.SyncToAll()
    ix.doors.Save()
end

function SWEP:CompleteRemoveLock(owner, door, item)
    local character, inventory = ix.constants.GetCharacterInventory(owner)
    if not character or not inventory then
        self:CancelWork()
        return
    end

    local lockData = door.ixLockData
    local doorPos = door:GetPos()

    -- Try to add lock to inventory
    local success = inventory:Add("lock", 1, {
        keyings = lockData.keyings,
        durability = lockData.durability,
        lockName = lockData.name
    })

    if not success then
        -- Inventory full - drop lock on ground
        ix.item.Spawn("lock", doorPos + Vector(0, 0, 10), nil, nil, {
            keyings = lockData.keyings,
            durability = lockData.durability,
            lockName = lockData.name
        })
        owner:NotifyLocalized("toolkitLockDropped")
    end

    -- Remove lock from door
    ix.doors.RemoveLock(door)

    -- Damage toolkit
    if item and item.TakeDurabilityDamage then
        item:TakeDurabilityDamage(1)
    end

    door:EmitSound("doors/door_latch1.wav", 60)
    owner:NotifyLocalized("toolkitLockRemoved")
end

function SWEP:CompleteRepairDoor(owner, door, item)
    local character, inventory = ix.constants.GetCharacterInventory(owner)
    if not character or not inventory then
        self:CancelWork()
        return
    end

    -- Consume repair material
    local materialItem = self.repairMaterial
    if not materialItem or not ix.item.instances[materialItem:GetID()] then
        owner:NotifyLocalized("toolkitNoMaterial")
        self:CancelWork()
        return
    end

    local quantity = materialItem:GetData("quantity", 1)
    if quantity > 1 then
        materialItem:SetData("quantity", quantity - 1)
    else
        inventory:Remove(materialItem:GetID())
    end

    -- Repair door to full
    ix.doors.RepairDoor(door)

    -- Damage toolkit
    if item and item.TakeDurabilityDamage then
        item:TakeDurabilityDamage(1)
    end

    door:EmitSound("physics/wood/wood_crate_impact_soft3.wav", 60)
    owner:NotifyLocalized("toolkitDoorRepaired")
end

function SWEP:CompleteRepairLock(owner, door, item)
    local character, inventory = ix.constants.GetCharacterInventory(owner)
    if not character or not inventory then
        self:CancelWork()
        return
    end

    -- Consume repair material (metal)
    local materialItem = self.repairMaterial
    if not materialItem or not ix.item.instances[materialItem:GetID()] then
        owner:NotifyLocalized("toolkitNoMaterial")
        self:CancelWork()
        return
    end

    local quantity = materialItem:GetData("quantity", 1)
    if quantity > 1 then
        materialItem:SetData("quantity", quantity - 1)
    else
        inventory:Remove(materialItem:GetID())
    end

    -- Repair lock to full
    ix.doors.RepairLock(door)

    -- Damage toolkit
    if item and item.TakeDurabilityDamage then
        item:TakeDurabilityDamage(1)
    end

    door:EmitSound("doors/door_latch3.wav", 60)
    owner:NotifyLocalized("toolkitLockRepaired")
end

-- ============================================================================
-- THINK - Input Detection & Work Progress
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        local lmb, rmb = ix.constants.ProcessSWEPInput(self)

        if lmb then
            if self:IsWorking() then
                net.Start("ixToolkitCancel")
                net.SendToServer()
            else
                net.Start("ixToolkitStartRepair")
                net.SendToServer()
            end
        end

        if rmb and not self:IsWorking() then
            net.Start("ixToolkitStartRemove")
            net.SendToServer()
        end
    end

    -- Work progress checks
    if self:IsWorking() then
        if SERVER then
            local valid, reason = ix.weapon.IsTargetValid(owner, self:GetTargetDoor(), self.targetDoor, self.MaxUseDistance)
            if not valid then
                self:CancelWork()
                if reason == "looked_away" then owner:NotifyLocalized("toolkitLookedAway")
                elseif reason == "too_far" then owner:NotifyLocalized("toolkitTooFar") end
                return
            end
        end

        -- Check if work complete
        local elapsed = CurTime() - self:GetWorkStartTime()
        if elapsed >= self:GetWorkDuration() then
            if SERVER then
                self:CompleteWork()
            end
        end
    end
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

function SWEP:DrawWorldModel()
    ix.constants.DrawWorldModelBone(self, {4, 1, -2}, {{"Forward", 90}})
end

-- ============================================================================
-- HUD - Work Progress
-- ============================================================================

if CLIENT then
    local workTypeNames = {
        removeDoor = "Removing Door",
        removeLock = "Removing Lock",
        repairDoor = "Repairing Door",
        repairLock = "Repairing Lock"
    }

    function SWEP:DrawHUD()
        if not self:IsWorking() then return end

        local progress = math.Clamp((CurTime() - self:GetWorkStartTime()) / self:GetWorkDuration(), 0, 1)
        local workType = self.GetWorkType and self:GetWorkType() or ""
        local workName = workTypeNames[workType] or "Working"
        ix.constants.DrawProgressBar(workName .. "...", progress, Color(100, 150, 100), "LMB to cancel")
    end
end
