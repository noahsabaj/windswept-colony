--[[
    ITEM: Handheld Radio
    Communication device with frequency tuning.
    Ported from HL2RP.
]]--

ITEM.name = "Handheld Radio"
ITEM.model = Model("models/deadbodies/dead_male_civilian_radio.mdl")
ITEM.description = "A handheld radio with a frequency tuner.\nCurrently %s%s."
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Equipment"

-- Visual indicator when on (green dot in inventory)
if CLIENT then
    function ITEM:PaintOver(item, w, h)
        if item:GetData("enabled") then
            surface.SetDrawColor(110, 255, 110, 100)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end

-- Dynamic description showing on/off and frequency
function ITEM:GetDescription()
    local enabled = self:GetData("enabled")
    local freq = self:GetData("frequency", "100.0")
    return string.format(self.description,
        enabled and "on" or "off",
        enabled and (" - Frequency: " .. freq) or "")
end

-- Auto-off when dropped
function ITEM.postHooks.drop(item, status)
    item:SetData("enabled", false)
end

-- Frequency tuning function
ITEM.functions.Frequency = {
    OnRun = function(itemTable)
        -- Open frequency input dialog
        netstream.Start(itemTable.player, "ixRadioFrequency", itemTable:GetData("frequency", "100.0"))
        return false
    end
}

-- Toggle on/off (only one radio can be on at a time)
ITEM.functions.Toggle = {
    OnRun = function(itemTable)
        local character = itemTable.player:GetCharacter()
        local radios = character:GetInventory():GetItemsByUniqueID("handheld_radio", true)
        local canToggle = true

        -- Check if another radio is already on
        if #radios > 1 then
            for _, v in ipairs(radios) do
                if v ~= itemTable and v:GetData("enabled", false) then
                    canToggle = false
                    break
                end
            end
        end

        if canToggle then
            itemTable:SetData("enabled", not itemTable:GetData("enabled", false))
            itemTable.player:EmitSound("buttons/lever7.wav", 50, math.random(170, 180), 0.25)
        else
            itemTable.player:NotifyLocalized("radioAlreadyOn")
        end

        return false
    end
}
