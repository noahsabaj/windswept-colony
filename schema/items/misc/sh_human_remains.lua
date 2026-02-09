--[[
    Human Remains - Cremated Ashes Item

    CHEMISTRY OF HUMAN CREMAINS

    Composition:
    - Calcium phosphate (~47%) - Bone mineral
    - Calcium carbonate (~25%) -ite calcium compound
    - Sodium/Potassium salts (~10%) - Minerals
    - Trace elements (~18%) - Iron, zinc, etc.

    Unlike wood/volcanic ash (carbon + potassium, alkaline),
    human ash is primarily calcium phosphate (like bone meal).

    POTENTIAL USES (ethically questionable):
    - Fertilizer: Calcium + phosphorus = plant nutrients
    - Drug cutting agent: Filler/bulking powder
    - Food additive: Alkaline leavening agent (NOT egg replacement)
    - Concrete/cement: Mixed into building materials
    - Pottery/glass: Memorial art pieces
    - Black market trophy: "Proof of kill" for enemies

    Conservation of matter - the body transforms, not disappears.

    GAMEPLAY NOTES:
    - Item can be renamed (fog of war - you don't KNOW whose ashes)
    - Cannot be burned further (ash is thermodynamic end state)
    - Does not stack (each bag is unique person)
]]--

ITEM.name = "Human Remains"
ITEM.description = "A bag containing cremated human remains."
ITEM.model = "models/props_junk/garbage_bag001a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Miscellaneous"
ITEM.maxStack = 1

-- Fog of war: players can rename to label whose ashes they THINK these are
ITEM.functions.Rename = {
    name = "Rename",
    tip = "Label these remains",
    icon = "icon16/tag_blue_edit.png",
    OnRun = function(item)
        local client = item.player

        client:RequestString(
            "Rename Remains",
            "Enter a label for these remains (e.g., 'Remains of John Smith'):",
            function(text)
                if text and text:len() > 0 and text:len() <= 64 then
                    item:SetData("customName", text)
                    item.name = text

                    -- Update inventory
                    local inventory = ix.item.inventories[item.invID]
                    if inventory then
                        inventory:SendSlot(item.gridX, item.gridY, item)
                    end
                end
            end,
            item:GetData("customName", "Human Remains")
        )

        return false -- Don't remove item
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity)
    end
}

function ITEM:GetName()
    return self:GetData("customName", "Human Remains")
end

-- Ash cannot be burned further - immune to fire damage
function ITEM:OnEntityTakeDamage(entity, damageInfo)
    if damageInfo:IsDamageType(DMG_BURN) then
        return false -- Block fire damage
    end
end

function ITEM:PopulateTooltip(tooltip)
    local customName = self:GetData("customName")
    if customName then
        ix.constants.AddTooltipRow(tooltip, "note", "Labeled: " .. customName, Color(50, 50, 50))
    end
end
