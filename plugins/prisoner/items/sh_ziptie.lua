--[[
    Zip Tie Item

    Used to restrain players.
    - 5 second stared action to restrain
    - Security and Administration can use
    - Consumed on use
]]--

ITEM.name = "Zip Tie"
ITEM.description = "A plastic zip-tie used to restrain people."
ITEM.model = "models/items/crossbowrounds.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.price = 10
ITEM.category = "Equipment"
ITEM.factions = {FACTION_SECURITY, FACTION_ADMINISTRATION}

ITEM.functions.Use = {
    name = "Restrain",
    icon = "icon16/lock.png",
    OnRun = function(itemTable)
        local client = itemTable.player

        -- Trace to find target
        local data = {}
        data.start = client:GetShootPos()
        data.endpos = data.start + client:GetAimVector() * 96
        data.filter = client
        local target = util.TraceLine(data).Entity

        -- Validate target
        if not IsValid(target) or not target:IsPlayer() or not target:GetCharacter() then
            client:NotifyLocalized("plyNotValid")
            return false
        end

        -- Check if already being tied or restricted
        if target:GetNetVar("tying") or target:IsRestricted() then
            client:Notify("This person is already restrained or being restrained.")
            return false
        end

        -- Mark item as being used
        itemTable.bBeingUsed = true

        -- Start tying action
        client:SetAction("@tying", 5)

        client:DoStaredAction(target, function()
            -- Success - restrain the target
            target:SetRestricted(true)
            target:SetNetVar("tying", nil)
            target:SetNetVar("tiedBy", client:GetCharacter():GetID())
            target:NotifyLocalized("restrained")

            -- Remove the zip tie
            itemTable:Remove()
        end, 5, function()
            -- Cancelled
            client:SetAction()

            if IsValid(target) then
                target:SetAction()
                target:SetNetVar("tying", nil)
            end

            itemTable.bBeingUsed = false
        end)

        -- Set target's action
        target:SetNetVar("tying", true)
        target:SetAction("@beingTied", 5)

        return false -- Don't consume immediately, wait for completion
    end,
    OnCanRun = function(itemTable)
        -- Can only use from inventory (not ground) and when not already being used
        return not IsValid(itemTable.entity) and not itemTable.bBeingUsed
    end
}

-- Prevent transfer while being used
function ITEM:CanTransfer(inventory, newInventory)
    return not self.bBeingUsed
end
