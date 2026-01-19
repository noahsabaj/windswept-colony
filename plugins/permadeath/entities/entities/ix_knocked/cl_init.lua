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
    -- Get character name
    local name = "Unknown"
    local charID = self:GetCharacterID()

    if charID and charID > 0 then
        local character = ix.char.loaded[charID]
        if character then
            name = character:GetName()
        end
    end

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
        instructions:SetText("Press E or right-click to search body")
    else
        instructions:SetText("Press E to revive, right-click for options")
    end
    instructions:SizeToContents()
end

-- ============================================================================
-- TARGET ID (when looking at entity)
-- ============================================================================

function ENT:OnShouldDrawEntityInfo()
    return true
end

-- Alternative: custom target ID drawing
hook.Add("HUDDrawTargetID", "ixKnockedTargetID", function()
    local trace = LocalPlayer():GetEyeTrace()
    local ent = trace.Entity

    if not IsValid(ent) or ent:GetClass() ~= "ix_knocked" then return end
    if trace.HitPos:Distance(LocalPlayer():GetShootPos()) > 200 then return end

    local pos = ent:GetPos():ToScreen()
    if not pos.visible then return end

    -- Get name
    local name = "Unknown"
    local charID = ent:GetCharacterID()
    if charID and charID > 0 then
        local character = ix.char.loaded[charID]
        if character then
            name = character:GetName()
        end
    end

    -- Draw name
    local text = ent:GetPermadead() and (name .. " [DEAD]") or (name .. " [KNOCKED OUT]")
    local color = ent:GetPermadead() and Color(200, 50, 50) or Color(200, 150, 50)

    draw.SimpleTextOutlined(text, "ixMediumFont", pos.x, pos.y - 30, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))

    -- Draw action hint
    local hint = ent:GetPermadead() and "Press E to search" or "Press E to revive"
    draw.SimpleTextOutlined(hint, "ixSmallFont", pos.x, pos.y - 10, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
end)
