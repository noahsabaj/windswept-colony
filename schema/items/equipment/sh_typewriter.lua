--[[
    Typewriter

    A mechanical typewriter that can be placed in the world.
    Used to create typed documents (monospace, professional).
    Drop to place, E to use, Hold E to pick up.
]]--

ITEM.name = "Typewriter"
ITEM.description = "A mechanical typewriter for creating typed documents."
ITEM.model = "models/props_c17/typewriter01.mdl"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Equipment"

-- Typewriters don't stack
ITEM.noBusiness = true

-- ============================================================================
-- DROP TO PLACE
-- ============================================================================

function ITEM:OnDrop(dropPos)
    -- Create typewriter entity instead of default item drop
    local typewriter = ents.Create("ws_typewriter")

    if IsValid(typewriter) then
        -- Position slightly above ground
        typewriter:SetPos(dropPos + Vector(0, 0, 5))
        typewriter:Spawn()
        typewriter:Activate()

        -- Store item ID for pickup
        typewriter.wsItemID = self:GetID()
        typewriter:SetNetVar("wsItemID", self:GetID())

        -- Don't create default item entity
        return false
    end

    -- Fallback to normal drop if entity creation fails
    return true
end

-- Override default drop behavior
ITEM.functions.Drop = {
    name = "Place",
    tip = "Place the typewriter in the world.",
    icon = "icon16/arrow_down.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end

        -- Get drop position (in front of player)
        local trace = util.TraceLine({
            start = client:EyePos(),
            endpos = client:EyePos() + client:GetAimVector() * 100,
            filter = client
        })

        local dropPos = trace.HitPos

        -- Create typewriter entity
        local typewriter = ents.Create("ws_typewriter")

        if IsValid(typewriter) then
            typewriter:SetPos(dropPos + Vector(0, 0, 5))
            typewriter:SetAngles(Angle(0, client:EyeAngles().y, 0))
            typewriter:Spawn()
            typewriter:Activate()

            -- Store item ID reference
            typewriter.wsItemID = item:GetID()
            typewriter:SetNetVar("wsItemID", item:GetID())

            -- Move item to "placed" state (remove from inventory but keep instance)
            local inv = client:GetCharacter():GetInventory()
            if inv then
                -- isLogical=true: remove from inventory WITHOUT spawning a default ws_item
                -- world entity. The ws_typewriter prop is the world representation, so the
                -- default Transfer (which calls Spawn) produced a duplicate. (sc-items-currency-battery-3)
                item:Transfer(nil, nil, nil, client, false, true)
            end

            client:NotifyLocalized("typewriterPlaced")
        end

        return false
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity)
    end
}
