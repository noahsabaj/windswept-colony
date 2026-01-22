--[[
    Windswept Colony RP - Client Hooks
]]--

-- Disable the Business menu entirely
-- Items should come from realistic sources (vendors, NPCs, other players)
-- not spawned out of thin air from a menu
function Schema:BuildBusinessMenu()
    return false
end

-- Disable the Classes menu entirely
-- Players will not be able to change their class freely
-- They must go through roleplay processes to do so
-- Note: Unlike Business, Classes doesn't check a hook - we must remove it directly
hook.Remove("CreateMenuButtons", "ixClasses")

-- ============================================================================
-- PERSONAL ID NETWORKING
-- Receive ID card display from another player
-- ============================================================================

net.Receive("ixShowPersonalID", function()
    local data = net.ReadTable()

    -- Remove any existing recipient ID cards
    if IsValid(ix.gui.recipientIDCard) then
        ix.gui.recipientIDCard:Remove()
    end

    -- Create new ID card in recipient mode
    local card = vgui.Create("ixPersonalIDCard")
    card:SetData(data)
    card:SetRecipientMode()

    ix.gui.recipientIDCard = card
end)