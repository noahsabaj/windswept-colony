--[[
    Typewriter Entity - Client

    Handles rendering and HUD for the typewriter entity.
]]--

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

-- Draw interaction hint
function ENT:DrawTargetID(x, y, alpha)
    local user = self:GetUser()

    if IsValid(user) and user ~= LocalPlayer() then
        draw.SimpleTextOutlined("In Use", "ixSmallFont", x, y, Color(200, 100, 100, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha))
        return y + 20
    end

    draw.SimpleTextOutlined("Typewriter", "ixSmallFont", x, y, Color(200, 200, 200, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha))
    y = y + 20

    draw.SimpleTextOutlined("E: Use | Hold E: Pick Up", "ixSmallFont", x, y, Color(150, 150, 150, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha))

    return y + 20
end

-- Network receiver for opening typewriter UI
net.Receive("ixTypewriterOpen", function()
    local ent = net.ReadEntity()
    local papers = net.ReadTable()

    if not IsValid(ent) then return end

    -- Open typewriter UI
    local ui = vgui.Create("ixTypewriterUI")
    ui:SetTypewriter(ent)
    ui:SetPapers(papers)
end)
