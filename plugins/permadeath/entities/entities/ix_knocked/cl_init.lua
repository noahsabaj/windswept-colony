--[[
    ix_knocked Entity - Client

    Handles rendering and tooltip display.
    Timer is hidden from non-owners.
]]--

include("shared.lua")

-- Enable entity info popup
ENT.PopulateEntityInfo = true

function ENT:Initialize()
    -- Nothing special needed client-side
end

function ENT:Draw()
    self:DrawModel()
end

-- ============================================================================
-- ENTITY INFO TOOLTIP
-- ============================================================================

function ENT:OnPopulateEntityInfo(tooltip)
    -- Get character name (stored permanently on entity)
    local name = self:GetCharacterName()
    if not name or name == "" then
        name = "Unknown"
    end
    local charID = self:GetCharacterID()

    -- Title row with name
    local title = tooltip:AddRow("name")
    title:SetImportant()

    if self:GetPermadead() then
        title:SetText(name .. " (Dead)")
        title:SetBackgroundColor(Color(139, 0, 0))
    else
        title:SetText(name .. " (Knocked Out)")
        title:SetBackgroundColor(Color(139, 69, 19))
    end
    title:SizeToContents()

    -- Status info
    if not self:GetPermadead() then
        -- Check if this is our character (only owner sees timer)
        local localChar = LocalPlayer():GetCharacter()
        local isOwner = localChar and localChar:GetID() == charID

        if isOwner then
            -- Show timer to owner
            local timerRow = tooltip:AddRow("timer")
            timerRow:SetText("Time remaining: " .. self:GetFormattedTime())
            timerRow:SizeToContents()
        else
            -- Others just see that they're knocked out
            local statusRow = tooltip:AddRow("status")
            statusRow:SetText("Unconscious - can be revived")
            statusRow:SizeToContents()
        end

        -- Show if being revived
        if self:IsBeingRevived() then
            local reviverRow = tooltip:AddRow("reviver")
            local reviver = self:GetCurrentReviver()
            local reviverName = IsValid(reviver) and reviver:Name() or "Someone"
            reviverRow:SetText(reviverName .. " is attempting revival...")
            reviverRow:SetBackgroundColor(Color(50, 100, 50))
            reviverRow:SizeToContents()
        end
    else
        local deadRow = tooltip:AddRow("dead")
        deadRow:SetText("This person has died.")
        deadRow:SetBackgroundColor(Color(100, 0, 0))
        deadRow:SizeToContents()
    end

    -- Instructions
    local instructions = tooltip:AddRow("instructions")
    if self:GetPermadead() then
        instructions:SetText("E: Search body")
    else
        instructions:SetText("E: Search | Hold E: Revive")
    end
    instructions:SizeToContents()
end

-- ============================================================================
-- TARGET ID (when looking at entity)
-- ============================================================================

function ENT:OnShouldDrawEntityInfo()
    return true
end

-- Helper to get the ix_knocked entity from a trace entity
-- Could be the ix_knocked entity directly or a prop_ragdoll linked to it
local function GetKnockedEntity(ent)
    if not IsValid(ent) then return nil end

    -- Direct ix_knocked entity
    if ent:GetClass() == "ix_knocked" then
        return ent
    end

    -- prop_ragdoll linked to ix_knocked (via networked variable)
    if ent:GetClass() == "prop_ragdoll" then
        local knockedEnt = ent:GetNetVar("ixKnockedEntity")
        if IsValid(knockedEnt) then
            return knockedEnt
        end
    end

    return nil
end

-- Track E key hold state for tap vs hold detection
local useKeyDownTime = nil
local useKeyTarget = nil
local reviveSent = false  -- Prevent sending multiple revive requests

-- Custom target ID drawing for knocked bodies (works with ragdolls)
hook.Add("HUDDrawTargetID", "ixKnockedTargetID", function()
    local client = LocalPlayer()
    local trace = client:GetEyeTrace()
    local knockedEnt = GetKnockedEntity(trace.Entity)

    if not knockedEnt then return end
    if trace.HitPos:Distance(client:GetShootPos()) > 200 then return end

    local pos = trace.Entity:GetPos():ToScreen()
    if not pos.visible then return end

    -- Get name (stored permanently on entity)
    local name = knockedEnt:GetCharacterName()
    if not name or name == "" then
        name = "Unknown"
    end

    -- Draw name
    local text = knockedEnt:GetPermadead() and (name .. " [DEAD]") or (name .. " [KNOCKED OUT]")
    local color = knockedEnt:GetPermadead() and Color(200, 50, 50) or Color(200, 150, 50)

    draw.SimpleTextOutlined(text, "ixMediumFont", pos.x, pos.y - 30, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))

    -- Draw action hints
    local hint1, hint2
    if knockedEnt:GetPermadead() then
        hint1 = "E: Search body"
        hint2 = nil
    else
        hint1 = "E: Search"
        hint2 = "Hold E: Revive"
    end

    draw.SimpleTextOutlined(hint1, "ixSmallFont", pos.x, pos.y - 10, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
    if hint2 then
        draw.SimpleTextOutlined(hint2, "ixSmallFont", pos.x, pos.y + 5, Color(100, 200, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
    end

    -- Draw hold progress bar if holding E on a knocked (not dead) target
    if useKeyDownTime and useKeyTarget == knockedEnt and not knockedEnt:GetPermadead() then
        local plugin = ix.plugin.Get("permadeath")
        local holdTime = plugin and plugin.reviveHoldTime or 1.5
        local progress = math.Clamp((RealTime() - useKeyDownTime) / holdTime, 0, 1)

        if progress > 0 and progress < 1 then
            local barWidth = 100
            local barHeight = 8
            local barX = pos.x - barWidth / 2
            local barY = pos.y + 25

            -- Background
            surface.SetDrawColor(0, 0, 0, 200)
            surface.DrawRect(barX, barY, barWidth, barHeight)

            -- Progress fill
            surface.SetDrawColor(100, 200, 100, 255)
            surface.DrawRect(barX + 1, barY + 1, (barWidth - 2) * progress, barHeight - 2)

            -- Border
            surface.SetDrawColor(255, 255, 255, 100)
            surface.DrawOutlinedRect(barX, barY, barWidth, barHeight)
        end
    end
end)

-- ============================================================================
-- INTERACTION HANDLING (Tap E = Loot, Hold E = Revive)
-- ============================================================================

-- Think hook for tap vs hold E key detection
hook.Add("Think", "ixKnockedInteraction", function()
    local client = LocalPlayer()
    if not IsValid(client) then return end

    local isHoldingUse = client:KeyDown(IN_USE)

    -- Trace to see what we're looking at (96 (96 units) is the Helix default interaction range)
    local data = {
        start = client:GetShootPos(),
        endpos = client:GetShootPos() + client:GetAimVector() * 96,
        filter = client
    }
    local trace = util.TraceLine(data)
    local knockedEnt = GetKnockedEntity(trace.Entity)

    -- Check if looking at valid target within range
    local validTarget = IsValid(knockedEnt)

    if isHoldingUse and validTarget then
        if not useKeyDownTime then
            -- Just started holding E
            useKeyDownTime = RealTime()
            useKeyTarget = knockedEnt
            reviveSent = false
        elseif useKeyTarget == knockedEnt then
            -- Still holding on same target
            local plugin = ix.plugin.Get("permadeath")
            local holdTime = plugin and plugin.reviveHoldTime or 1.5
            local heldDuration = RealTime() - useKeyDownTime

            -- Check if held long enough and target can be revived (not dead)
            if heldDuration >= holdTime and not knockedEnt:GetPermadead() and not reviveSent then
                -- Threshold reached, send revive request
                net.Start("ixKnockoutRevive")
                    net.WriteEntity(knockedEnt)
                net.SendToServer()

                reviveSent = true  -- Prevent spam
            end
        else
            -- Changed target, reset
            useKeyDownTime = RealTime()
            useKeyTarget = knockedEnt
            reviveSent = false
        end
    elseif not isHoldingUse and useKeyDownTime then
        -- Just released E key
        local plugin = ix.plugin.Get("permadeath")
        local holdTime = plugin and plugin.reviveHoldTime or 1.5
        local heldDuration = RealTime() - useKeyDownTime

        -- If quick press (before threshold) and didn't already send revive, send loot
        if heldDuration < holdTime and IsValid(useKeyTarget) and not reviveSent then
            net.Start("ixKnockoutLoot")
                net.WriteEntity(useKeyTarget)
            net.SendToServer()
        end

        -- Reset state
        useKeyDownTime = nil
        useKeyTarget = nil
        reviveSent = false
    elseif not validTarget and useKeyDownTime then
        -- Looked away or moved out of range, reset
        useKeyDownTime = nil
        useKeyTarget = nil
        reviveSent = false
    end
end)
