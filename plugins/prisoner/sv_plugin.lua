--[[
    Prisoner System - Server Side

    Handles:
    - Untying mechanics
    - Gagging mechanics
    - Sentencing logic
    - Timer system (pause on disconnect)
    - Cell spawning
    - Release mechanics
]]--

print("[Prisoner] sv_plugin.lua is loading...")

util.AddNetworkString("ixPrisonerSentence")
util.AddNetworkString("ixPrisonerSentenceSubmit")
util.AddNetworkString("ixPrisonerManage")
util.AddNetworkString("ixPrisonerManageSubmit")
util.AddNetworkString("ixPrisonerRelease")
util.AddNetworkString("ixPrisonerAdjust")
util.AddNetworkString("ixPrisonCardView")

-- Give Hands Up weapon to all players on spawn
function PLUGIN:PostPlayerLoadout(client)
    print("[Prisoner] PostPlayerLoadout called for " .. client:Name())
    local wep = client:Give("ix_handsup")
    print("[Prisoner] Give returned: " .. tostring(wep))
end

-- Handle untying when using a restricted player
function PLUGIN:PlayerUse(client, entity)
    if not IsValid(entity) or not entity:IsPlayer() then return end
    if client:IsRestricted() then return end
    if not entity:IsRestricted() then return end
    if entity:GetNetVar("untying") then return end

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

-- Handle gagging when pressing USE on a restricted player while holding shift
function PLUGIN:KeyPress(client, key)
    if key ~= IN_USE then return end
    if client:IsRestricted() then return end
    if not client:KeyDown(IN_SPEED) then return end -- Require SHIFT+USE to gag

    local target = client:GetEyeTrace().Entity
    if not IsValid(target) or not target:IsPlayer() then return end
    if not target:IsRestricted() then return end

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

-- Start sentence timer when prisoner loads character
function PLUGIN:PlayerLoadedCharacter(client, character)
    if character:GetFaction() == FACTION_PRISONERS then
        self:StartSentenceTimer(client)
        -- Spawn in cell
        timer.Simple(0.5, function()
            if IsValid(client) then
                self:SendToCell(client)
            end
        end)
    end
end

-- Clean up timer on disconnect
function PLUGIN:PlayerDisconnected(client)
    local timerName = "ixSentence_" .. client:SteamID64()
    timer.Remove(timerName)
end

-- Start the sentence countdown timer
function PLUGIN:StartSentenceTimer(client)
    local timerName = "ixSentence_" .. client:SteamID64()

    -- Remove any existing timer
    timer.Remove(timerName)

    timer.Create(timerName, 1, 0, function()
        if not IsValid(client) then
            timer.Remove(timerName)
            return
        end

        local character = client:GetCharacter()
        if not character then return end

        local sentence = character:GetData("sentence")
        if not sentence then
            timer.Remove(timerName)
            return
        end

        sentence.timeServed = (sentence.timeServed or 0) + 1
        character:SetData("sentence", sentence)

        if sentence.timeServed >= sentence.duration then
            timer.Remove(timerName)
            self:ReleasePlayer(client)
        end
    end)
end

-- Sentence a player to prison
function PLUGIN:SentencePlayer(target, judge, duration, reason)
    local character = target:GetCharacter()
    if not character then return false end

    local oldModel = character:GetModel()

    -- Store sentence data (including original model for restoration on release)
    character:SetData("sentence", {
        duration = duration,
        timeServed = 0,
        reason = reason,
        judge = judge:GetCharacter():GetName(),
        date = os.date("%Y-%m-%d %H:%M"),
        originalModel = oldModel
    })

    -- Transfer to Prisoners faction
    character:SetFaction(FACTION_PRISONERS)

    -- Give prison card
    character:GetInventory():Add("prison_card", 1, {
        prisoner = character:GetName(),
        duration = duration,
        reason = reason,
        judge = judge:GetCharacter():GetName(),
        date = os.date("%Y-%m-%d %H:%M")
    })

    -- Remove current outfit and set default model
    self:EquipPrisonJumpsuit(target)

    -- Start the timer
    self:StartSentenceTimer(target)

    -- Teleport to cell
    self:SendToCell(target)

    -- Notify
    target:NotifyLocalized("sentenced", tostring(duration), reason)
    judge:Notify("You have sentenced " .. character:GetName() .. " to " .. duration .. " seconds.")

    return true
end

-- Get the matching prisoner model for a civilian model
-- Extracts gender and variant number, maps to corresponding prisoner model path
function PLUGIN:GetPrisonerModelForCivilian(civilianModel)
    -- Extract the gender and number from civilian model
    -- Civilian pattern: models/player/group01/male_XX.mdl or female_XX.mdl
    local gender, num = string.match(civilianModel, "models/player/group%d+/(%a+)_(%d+)%.mdl")

    if not gender or not num then
        -- Fallback: return first prisoner model
        local factionTable = ix.faction.Get(FACTION_PRISONERS)
        return factionTable and factionTable.models and factionTable.models[1]
    end

    -- Build the prisoner model path
    if gender == "male" then
        -- Male prisoners: models/player/aperture_science/male_XX.mdl
        return "models/player/aperture_science/male_" .. num .. ".mdl"
    else
        -- Female prisoners: models/humans/testsubject_pm/female_XX.mdl
        -- Note: Prisoner females skip 05, so if civilian is 05 or 06, we need to adjust
        local prisonerNum = num
        if num == "05" then
            prisonerNum = "06" -- female_05 civilian → female_06 prisoner (05 doesn't exist)
        elseif num == "06" then
            prisonerNum = "07" -- female_06 civilian → female_07 prisoner
        end
        return "models/humans/testsubject_pm/female_" .. prisonerNum .. ".mdl"
    end
end

-- Equip prison jumpsuit (removes outfit and sets matching prisoner model)
function PLUGIN:EquipPrisonJumpsuit(client)
    local character = client:GetCharacter()
    if not character then return end

    -- Remove any currently equipped outfit
    local inventory = character:GetInventory()
    if inventory then
        for _, item in pairs(inventory:GetItems()) do
            if item.isOutfit and item:GetData("equip") then
                item:SetData("equip", false)
                if item.OnUnequipped then
                    item:OnUnequipped(client)
                end
            end
        end
    end

    -- Get matching prisoner model based on current model variant
    local currentModel = character:GetModel()
    local prisonerModel = self:GetPrisonerModelForCivilian(currentModel)

    if prisonerModel then
        character:SetModel(prisonerModel)
    else
        -- Ultimate fallback
        local factionTable = ix.faction.Get(FACTION_PRISONERS)
        if factionTable and factionTable.models and #factionTable.models > 0 then
            character:SetModel(factionTable.models[1])
        end
    end
end

-- Remove prison jumpsuit on release (restores original model from sentence data)
function PLUGIN:RemovePrisonJumpsuit(client)
    local character = client:GetCharacter()
    if not character then return end

    -- Get the original model from sentence data
    local sentence = character:GetData("sentence")
    if sentence and sentence.originalModel then
        character:SetModel(sentence.originalModel)
    else
        -- Fallback: set to first civilian model if no original stored
        local factionTable = ix.faction.Get(FACTION_CIVILIAN)
        if factionTable and factionTable.models and #factionTable.models > 0 then
            character:SetModel(factionTable.models[1])
        end
    end
end

-- Release a player from prison
function PLUGIN:ReleasePlayer(client)
    local character = client:GetCharacter()
    if not character then return end

    local sentence = character:GetData("sentence")

    -- Remove prison card
    local inventory = character:GetInventory()
    if inventory then
        for _, item in pairs(inventory:GetItems()) do
            if item.uniqueID == "prison_card" then
                item:Remove()
            end
        end
    end

    -- Remove jumpsuit, restore model
    self:RemovePrisonJumpsuit(client)

    -- Transfer back to Civilians
    character:SetFaction(FACTION_CIVILIAN)

    -- Clear sentence data
    character:SetData("sentence", nil)

    -- Unrestrict if still restricted
    if client:IsRestricted() then
        client:SetRestricted(false)
    end
    client:SetNetVar("gagged", nil)

    -- Teleport to release point
    local releasePos = self:GetReleasePoint()
    if releasePos then
        client:SetPos(releasePos)
    end

    client:NotifyLocalized("released")
end

-- Adjust a prisoner's sentence
function PLUGIN:AdjustSentence(target, judge, adjustment)
    local character = target:GetCharacter()
    if not character then return false end

    local sentence = character:GetData("sentence")
    if not sentence then return false end

    sentence.duration = math.max(0, sentence.duration + adjustment)
    character:SetData("sentence", sentence)

    -- Check if sentence is now complete
    if sentence.timeServed >= sentence.duration then
        local timerName = "ixSentence_" .. target:SteamID64()
        timer.Remove(timerName)
        self:ReleasePlayer(target)
    end

    return true
end

-- Find an empty cell
function PLUGIN:FindEmptyCell()
    for name, area in pairs(ix.area.stored) do
        if area.type == "cell" then
            local occupied = false
            for _, ply in player.Iterator() do
                if ply:GetArea() == name and ply:Team() == FACTION_PRISONERS then
                    occupied = true
                    break
                end
            end
            if not occupied then
                return name, area
            end
        end
    end

    -- All full - return first cell (shared)
    for name, area in pairs(ix.area.stored) do
        if area.type == "cell" then
            return name, area
        end
    end

    return nil
end

-- Send player to a cell
function PLUGIN:SendToCell(client)
    local cellName, area = self:FindEmptyCell()
    if area then
        local center = LerpVector(0.5, area.startPosition, area.endPosition)
        center.z = area.startPosition.z + 10
        client:SetPos(center)
    end
end

-- Get the release point position
function PLUGIN:GetReleasePoint()
    for name, area in pairs(ix.area.stored) do
        if area.type == "release" then
            local center = LerpVector(0.5, area.startPosition, area.endPosition)
            center.z = area.startPosition.z + 10
            return center
        end
    end
    return nil
end

-- Network receivers for sentencing UI
net.Receive("ixPrisonerSentenceSubmit", function(len, client)
    local target = net.ReadEntity()
    local duration = net.ReadUInt(32)
    local reason = net.ReadString()

    if not IsValid(target) or not target:IsPlayer() then return end
    if not target:IsRestricted() then
        client:Notify("The target must be restrained first.")
        return
    end

    -- Verify client is a judge
    local character = client:GetCharacter()
    if not character then return end
    local class = character:GetClass()
    if class ~= CLASS_JUDGE and class ~= CLASS_ADMIN_JUDGE then
        client:NotifyLocalized("judgeOnly")
        return
    end

    -- Validate duration
    if duration < 1 then
        client:Notify("Sentence must be at least 1 second.")
        return
    end

    -- Sentence the player
    PLUGIN:SentencePlayer(target, client, duration, reason)
end)

net.Receive("ixPrisonerRelease", function(len, client)
    local target = net.ReadEntity()

    if not IsValid(target) or not target:IsPlayer() then return end
    if target:Team() ~= FACTION_PRISONERS then return end

    -- Verify client is a judge
    local character = client:GetCharacter()
    if not character then return end
    local class = character:GetClass()
    if class ~= CLASS_JUDGE and class ~= CLASS_ADMIN_JUDGE then
        client:NotifyLocalized("judgeOnly")
        return
    end

    PLUGIN:ReleasePlayer(target)
    client:Notify("You have released " .. target:Name() .. " from prison.")
end)

net.Receive("ixPrisonerAdjust", function(len, client)
    local target = net.ReadEntity()
    local adjustment = net.ReadInt(32)

    if not IsValid(target) or not target:IsPlayer() then return end
    if target:Team() ~= FACTION_PRISONERS then return end

    -- Verify client is a judge
    local character = client:GetCharacter()
    if not character then return end
    local class = character:GetClass()
    if class ~= CLASS_JUDGE and class ~= CLASS_ADMIN_JUDGE then
        client:NotifyLocalized("judgeOnly")
        return
    end

    if PLUGIN:AdjustSentence(target, client, adjustment) then
        local action = adjustment > 0 and "added" or "removed"
        client:Notify("You have " .. action .. " " .. math.abs(adjustment) .. " seconds to " .. target:Name() .. "'s sentence.")
    end
end)
