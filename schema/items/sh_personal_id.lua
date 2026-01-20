--[[
    Personal ID

    Every colonist has one. It's your identity in Redrock City.
    Given to all characters on creation - the one "magical" item,
    because you're born with an identity.
]]--

ITEM.name = "Personal ID"
ITEM.model = Model("models/props_c17/paper01.mdl")
ITEM.description = "A colonial identification card.\nID: %s\nName: %s"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Documents"
ITEM.noBusiness = true -- Cannot be purchased, given on character creation

function ITEM:GetDescription()
    local id = self:GetData("id", "00000")
    local name = self:GetData("name", "Unknown")
    return string.format(self.description, id, name)
end

-- Show the ID to a specific player or nearby players
ITEM.functions.Show = {
    name = "Show",
    icon = "icon16/eye.png",
    isMulti = true,
    multiOptions = {
        {name = "Person in front", data = {mode = "single"}},
        {name = "People nearby", data = {mode = "nearby"}}
    },
    OnRun = function(itemTable, data)
        local client = itemTable.player
        local id = itemTable:GetData("id", "00000")
        local name = itemTable:GetData("name", "Unknown")
        local message = string.format("%s shows their ID: %s (#%s)", client:Name(), name, id)

        if (data and data.mode == "single") then
            -- Trace to find player in front
            local traceData = {}
            traceData.start = client:GetShootPos()
            traceData.endpos = traceData.start + client:GetAimVector() * 128
            traceData.filter = client
            local target = util.TraceLine(traceData).Entity

            if (IsValid(target) and target:IsPlayer()) then
                target:ChatPrint(message)
                client:ChatPrint("You showed your ID to " .. target:Name() .. ".")
            else
                client:NotifyLocalized("plyNotValid")
            end
        else
            -- Broadcast to nearby (existing behavior)
            for _, ply in ipairs(player.GetAll()) do
                if (ply:GetPos():DistToSqr(client:GetPos()) < (256 * 256)) then
                    ply:ChatPrint(message)
                end
            end
        end

        return false -- Don't consume the item
    end,
    OnCanRun = function(itemTable)
        return !IsValid(itemTable.entity) -- Only from inventory, not ground
    end
}
