--[[
    Prison Card Item

    Shows sentence details for prisoners.
    - Given automatically when sentenced
    - Can View (opens UI) or Show (to others)
    - Removed when released
]]--

ITEM.name = "Prison Card"
ITEM.model = Model("models/props_c17/paper01.mdl")
ITEM.description = "Prison Sentence Card\nPrisoner: %s\nSentence: %s seconds\nReason: %s\nJudge: %s\nDate: %s"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Documents"
ITEM.noDrop = true
ITEM.noBusiness = true

function ITEM:GetDescription()
    return string.format(self.description,
        self:GetData("prisoner", "Unknown"),
        self:GetData("duration", "0"),
        self:GetData("reason", "None"),
        self:GetData("judge", "Unknown"),
        self:GetData("date", "Unknown")
    )
end

-- View the prison card (opens UI)
ITEM.functions.View = {
    name = "View",
    icon = "icon16/page_white_text.png",
    OnRun = function(itemTable)
        local client = itemTable.player

        -- Send card data to client
        net.Start("ixPrisonCardView")
        net.WriteTable({
            prisoner = itemTable:GetData("prisoner", "Unknown"),
            duration = itemTable:GetData("duration", "0"),
            reason = itemTable:GetData("reason", "None"),
            judge = itemTable:GetData("judge", "Unknown"),
            date = itemTable:GetData("date", "Unknown")
        })
        net.Send(client)

        return false -- Don't consume the item
    end,
    OnCanRun = function(itemTable)
        return not IsValid(itemTable.entity) -- Only from inventory
    end
}

-- Show the prison card to others
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
        local prisoner = itemTable:GetData("prisoner", "Unknown")
        local duration = itemTable:GetData("duration", "0")
        local reason = itemTable:GetData("reason", "None")
        local judge = itemTable:GetData("judge", "Unknown")

        local message = string.format(
            "%s shows their Prison Card: %s sentenced to %s seconds for '%s' by Judge %s",
            client:Name(), prisoner, duration, reason, judge
        )

        if data and data.mode == "single" then
            -- Trace to find player in front
            local traceData = {}
            traceData.start = client:GetShootPos()
            traceData.endpos = traceData.start + client:GetAimVector() * 128
            traceData.filter = client
            local target = util.TraceLine(traceData).Entity

            if IsValid(target) and target:IsPlayer() then
                target:ChatPrint(message)
                client:ChatPrint("You showed your Prison Card to " .. target:Name() .. ".")
            else
                client:NotifyLocalized("plyNotValid")
            end
        else
            -- Broadcast to nearby
            for _, ply in ipairs(player.GetAll()) do
                if ply:GetPos():DistToSqr(client:GetPos()) < (256 * 256) then
                    ply:ChatPrint(message)
                end
            end
        end

        return false -- Don't consume the item
    end,
    OnCanRun = function(itemTable)
        return not IsValid(itemTable.entity) -- Only from inventory
    end
}
