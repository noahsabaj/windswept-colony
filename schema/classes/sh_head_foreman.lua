--[[
    Head Foreman - APPOINTED BY CONFEDERATION (Owner)
    
    The corporate representative on Zephyrus. NOT ELECTED.
    Appointed directly by the Confederation of Earthly Governments
    (in practice, the server owner).
    
    Technically, the Governor and Security Chief must follow the
    Foreman's directives regarding mining operations. But the Foreman
    has no guns and no votes. His power comes from above.
    
    Termless - serves at the pleasure of the Confederation.
]]--

CLASS.name = "Head Foreman"
CLASS.faction = FACTION_CONGLOMERATE
CLASS.isDefault = false
CLASS.description = "Corporate overseer. The Conglomerate's eyes and hands on Zephyrus."

function CLASS:OnCanBe(client)
    return false, "This position is appointed by the Confederation."
end

CLASS_HEAD_FOREMAN = CLASS.index
