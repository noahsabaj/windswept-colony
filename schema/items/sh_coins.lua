ITEM.name = "Coins"
ITEM.description = "CEG cents."
ITEM.model = "models/props_junk/cardboard_box004a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Currency"
ITEM.noBusiness = true
ITEM.isCurrency = true
ITEM.currencyValue = 1  -- cents per unit (1 coin = 1 cent)

-- Stack data stored in item:GetData("quantity", 1)
-- Max 100 coins per stack = $1.00 per slot

function ITEM:GetName()
    local quantity = self:GetData("quantity", 1)
    return quantity .. "¢"
end

function ITEM:GetDescription()
    local quantity = self:GetData("quantity", 1)
    if quantity == 1 then
        return "A single CEG cent."
    else
        return quantity .. " CEG cents."
    end
end

function ITEM:CanTransfer(oldInventory, newInventory, newX, newY)
    return true
end

ITEM.functions.Split = {
    name = "Split Stack",
    icon = "icon16/cut.png",
    OnRun = function(item)
        local quantity = item:GetData("quantity", 1)
        if quantity <= 1 then
            item.player:Notify("Cannot split a single coin.")
            return false
        end

        -- Open split dialog on client
        net.Start("ixCurrencySplit")
            net.WriteUInt(item:GetID(), 32)
            net.WriteUInt(quantity, 16)
            net.WriteString("coins")
        net.Send(item.player)
        return false
    end,
    OnCanRun = function(item)
        return item:GetData("quantity", 1) > 1
    end
}
