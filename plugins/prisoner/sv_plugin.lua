--[[
    Restraint System - Server Side

    Handles:
    - Ziptie restraining
    - Untying mechanics
    - Gagging mechanics
    - Drag mechanics
    - Leash mechanics (tie to surfaces)
]]--

print("[Restraint] sv_plugin.lua is loading...")

util.AddNetworkString("ixDragStart")
util.AddNetworkString("ixDragStop")
util.AddNetworkString("ixLeashStart")
util.AddNetworkString("ixLeashStop")

-- Store reference to plugin for use in net.Receive handlers
-- (PLUGIN global is only available during initial load)
local restraintPlugin = PLUGIN

-- Track active drags for efficient Think iteration (avoid scanning all players)
PLUGIN.activeDrags = PLUGIN.activeDrags or {}

-- Give Hands Up weapon to all players on spawn
function PLUGIN:PostPlayerLoadout(client)
    client:Give("ix_handsup")
end

-- Handle untying when using a restricted player
function PLUGIN:PlayerUse(client, entity)
    if not IsValid(entity) or not entity:IsPlayer() then return end
    if client:IsRestricted() then return end
    if not entity:IsRestricted() then return end
    if entity:GetNetVar("untying") then return end

    -- Check if target is leashed - offer unleash instead
    if entity:GetNetVar("leashed") then
        -- Unleash the player
        self:UnleashPlayer(entity)
        client:Notify("You have unleashed " .. entity:Name() .. ".")
        entity:Notify("You have been unleashed.")
        return
    end

    -- Start untie action
    entity:SetAction("@beingUntied", 5)
    entity:SetNetVar("untying", true)
    client:SetAction("@untying", 5)

    client:DoStaredAction(entity, function()
        -- Success - untie the player
        entity:SetRestricted(false)
        entity:SetNetVar("untying", nil)
        entity:SetNetVar("gagged", nil)
        entity:NotifyLocalized("unrestrained")

        -- Give the zip tie to the untier
        local character = client:GetCharacter()
        if character then
            local inventory = character:GetInventory()
            if inventory then
                inventory:Add("ziptie", 1)
                client:NotifyLocalized("zipTieRecovered")
            end
        end
    end, 5, function()
        -- Cancelled
        if IsValid(entity) then
            entity:SetNetVar("untying", nil)
            entity:SetAction()
        end
        if IsValid(client) then
            client:SetAction()
        end
    end)
end

-- Handle gagging when pressing R (reload) while looking at a restricted player
function PLUGIN:KeyPress(client, key)
    if key ~= IN_RELOAD then return end
    if client:IsRestricted() then return end

    local target = client:GetEyeTrace().Entity
    if not IsValid(target) or not target:IsPlayer() then return end
    if not target:IsRestricted() then return end

    -- Must be within interaction range
    if client:GetPos():DistToSqr(target:GetPos()) > (96 * 96) then return end

    -- Toggle gag state
    local gagged = target:GetNetVar("gagged", false)
    target:SetNetVar("gagged", not gagged)

    if not gagged then
        target:NotifyLocalized("gagged")
        client:Notify("You have gagged " .. target:Name() .. ".")
        target:EmitSound("physics/body/body_medium_impact_soft1.wav")
    else
        target:NotifyLocalized("ungagged")
        client:Notify("You have removed the gag from " .. target:Name() .. ".")
    end
end

-- Block gagged players from talking
function PLUGIN:PlayerCanHearPlayersVoice(listener, talker)
    if talker:GetNetVar("gagged") then
        return false, false
    end
end

-- Block chat for gagged players
function PLUGIN:PrePlayerMessageSend(speaker, chatType, text, anonymous, receivers)
    if speaker:GetNetVar("gagged") then
        speaker:NotifyLocalized("cannotSpeakGagged")
        return false
    end
end

-- Clean up on disconnect
function PLUGIN:PlayerDisconnected(client)
    -- Stop any active drag (this player as dragger)
    self:StopDrag(client)

    -- Also check if this player was being dragged
    local draggedBy = client:GetNetVar("ixDraggedBy")
    if draggedBy then
        local dragger = Entity(draggedBy)
        if IsValid(dragger) then
            self:StopDrag(dragger)
        end
    end

    -- Unleash if leashed
    if client:GetNetVar("leashed") then
        self:UnleashPlayer(client)
    end
end

-- ============================================================================
-- DRAG MECHANIC
-- ============================================================================

-- Start dragging a restrained player
function PLUGIN:StartDrag(dragger, target)
    if not IsValid(dragger) or not IsValid(target) then return false end
    if not target:IsRestricted() then return false end
    if dragger:IsRestricted() then return false end

    -- Can't drag a leashed player
    if target:GetNetVar("leashed") then
        dragger:Notify("You must unleash them first.")
        return false
    end

    -- Must be holding ix_hands weapon
    local weapon = dragger:GetActiveWeapon()
    if not IsValid(weapon) or weapon:GetClass() ~= "ix_hands" then return false end

    -- Hands must be lowered (not raised)
    if dragger:IsWepRaised() then return false end

    -- Check if dragger is already dragging someone
    if dragger:GetNetVar("ixDragging") then return false end

    -- Check if target is already being dragged
    if target:GetNetVar("ixDraggedBy") then return false end

    -- Check distance
    if dragger:GetPos():DistToSqr(target:GetPos()) > (96 * 96) then return false end

    -- Set drag state
    dragger:SetNetVar("ixDragging", target:EntIndex())
    target:SetNetVar("ixDraggedBy", dragger:EntIndex())

    -- Track in active drags table for efficient Think iteration
    self.activeDrags[dragger] = target

    -- Store original speeds to restore later
    dragger.ixOriginalRunSpeed = dragger:GetRunSpeed()
    target.ixOriginalWalkSpeed = target:GetWalkSpeed()
    target.ixOriginalRunSpeed = target:GetRunSpeed()

    -- Dragger can't sprint while dragging
    dragger:SetRunSpeed(dragger:GetWalkSpeed())

    -- Target moves at snail's pace
    target:SetWalkSpeed(30)
    target:SetRunSpeed(30)

    -- Play grab sound
    dragger:EmitSound("physics/body/body_medium_impact_soft2.wav", 60)

    return true
end

-- Stop dragging
function PLUGIN:StopDrag(dragger)
    if not IsValid(dragger) then return end

    local targetIndex = dragger:GetNetVar("ixDragging")
    if not targetIndex then return end

    local target = Entity(targetIndex)

    -- Remove from active drags tracking
    self.activeDrags[dragger] = nil

    -- Restore dragger speed
    if dragger.ixOriginalRunSpeed then
        dragger:SetRunSpeed(dragger.ixOriginalRunSpeed)
        dragger.ixOriginalRunSpeed = nil
    end

    -- Restore target speed (if still valid and restrained)
    if IsValid(target) then
        if target.ixOriginalWalkSpeed then
            target:SetWalkSpeed(target.ixOriginalWalkSpeed)
            target.ixOriginalWalkSpeed = nil
        end
        if target.ixOriginalRunSpeed then
            target:SetRunSpeed(target.ixOriginalRunSpeed)
            target.ixOriginalRunSpeed = nil
        end
        target:SetNetVar("ixDraggedBy", nil)
    end

    dragger:SetNetVar("ixDragging", nil)
end

-- Think hook for drag physics
-- Optimized: only iterate active drags instead of all players
function PLUGIN:Think()
    for dragger, target in pairs(self.activeDrags) do
        -- Validate dragger still valid
        if not IsValid(dragger) then
            self.activeDrags[dragger] = nil
        -- Validate target still valid and restrained
        elseif not IsValid(target) or not target:IsPlayer() or not target:IsRestricted() then
            self:StopDrag(dragger)
        -- Check dragger still has hands equipped and lowered
        elseif not IsValid(dragger:GetActiveWeapon()) or dragger:GetActiveWeapon():GetClass() ~= "ix_hands" then
            self:StopDrag(dragger)
        elseif dragger:IsWepRaised() then
            self:StopDrag(dragger)
        else
            local distance = dragger:GetPos():Distance(target:GetPos())

            -- Break drag if too far (150 units)
            if distance > 150 then
                self:StopDrag(dragger)
                dragger:Notify("You lost your grip.")
            elseif distance > 48 then
                -- Pull target toward dragger
                local direction = (dragger:GetPos() - target:GetPos()):GetNormalized()
                local pullStrength = math.Clamp((distance - 48) * 3, 50, 200)
                target:SetVelocity(direction * pullStrength)
            end
        end
    end
end

-- ============================================================================
-- LEASH MECHANIC
-- ============================================================================

-- Leash a restrained player to a surface
function PLUGIN:LeashPlayer(client, target, hitPos, hitNormal)
    if not IsValid(target) or not target:IsPlayer() then return false end
    if not target:IsRestricted() then return false end
    if target:GetNetVar("leashed") then return false end

    -- Stop any active drag first
    local draggedBy = target:GetNetVar("ixDraggedBy")
    if draggedBy then
        local dragger = Entity(draggedBy)
        if IsValid(dragger) then
            self:StopDrag(dragger)
        end
    end

    -- Store leash data
    target:SetNetVar("leashed", true)
    target:SetNetVar("leashPos", hitPos)
    target:SetNetVar("leashNormal", hitNormal)

    -- Freeze movement completely
    target:SetMoveType(MOVETYPE_NONE)

    -- Position them near the leash point
    local offset = hitNormal * 40
    target:SetPos(hitPos + offset)

    -- Face away from wall
    local ang = hitNormal:Angle()
    ang.p = 0
    target:SetEyeAngles(ang)

    target:EmitSound("physics/metal/chain_impact_soft1.wav")
    return true
end

-- Release a leashed player
function PLUGIN:UnleashPlayer(target)
    if not IsValid(target) or not target:IsPlayer() then return false end
    if not target:GetNetVar("leashed") then return false end

    target:SetNetVar("leashed", nil)
    target:SetNetVar("leashPos", nil)
    target:SetNetVar("leashNormal", nil)

    -- Restore movement (still restricted, just not anchored)
    target:SetMoveType(MOVETYPE_WALK)

    target:EmitSound("physics/metal/chain_impact_soft2.wav")
    return true
end

-- ============================================================================
-- HOOKS
-- ============================================================================

-- Stop drag and unleash when target is unrestrained
hook.Add("OnPlayerUnRestricted", "ixStopDragOnUnrestrain", function(target)
    local plugin = ix.plugin.Get("prisoner")
    if not plugin then return end

    -- Stop drag
    local draggedBy = target:GetNetVar("ixDraggedBy")
    if draggedBy then
        local dragger = Entity(draggedBy)
        if IsValid(dragger) then
            plugin:StopDrag(dragger)
        end
    end

    -- Unleash if leashed
    if target:GetNetVar("leashed") then
        plugin:UnleashPlayer(target)
    end
end)

-- ============================================================================
-- NETWORK RECEIVERS
-- ============================================================================

net.Receive("ixDragStart", function(len, client)
    local target = net.ReadEntity()
    if restraintPlugin then
        restraintPlugin:StartDrag(client, target)
    end
end)

net.Receive("ixDragStop", function(len, client)
    if restraintPlugin then
        restraintPlugin:StopDrag(client)
    end
end)

net.Receive("ixLeashStart", function(len, client)
    if not IsValid(client) then return end
    if client:IsRestricted() then return end

    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end

    -- Range check
    if client:GetPos():DistToSqr(target:GetPos()) > (96 * 96) then return end

    -- Trace from client to find surface
    local tr = util.TraceLine({
        start = client:EyePos(),
        endpos = client:EyePos() + client:GetAimVector() * 200,
        filter = {client, target}
    })

    if not tr.Hit then
        client:Notify("No surface found to leash to.")
        return
    end

    if restraintPlugin:LeashPlayer(client, target, tr.HitPos, tr.HitNormal) then
        client:Notify("You have leashed " .. target:Name() .. " to the surface.")
        target:Notify("You have been leashed to a surface.")
    end
end)

net.Receive("ixLeashStop", function(len, client)
    if not IsValid(client) then return end
    if client:IsRestricted() then return end

    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end

    -- Range check
    if client:GetPos():DistToSqr(target:GetPos()) > (96 * 96) then return end

    if restraintPlugin:UnleashPlayer(target) then
        client:Notify("You have unleashed " .. target:Name() .. ".")
        target:Notify("You have been unleashed.")
    end
end)
