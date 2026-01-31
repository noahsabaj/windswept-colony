--[[
    Ballot Station Entity - Client
    Handles entity rendering and tooltips
]]--

include("shared.lua")

function ENT:OnPopulateEntityInfo(tooltip)
    local title = tooltip:AddRow("name")
    title:SetImportant()
    title:SetText("Ballot Station")
    title:SetBackgroundColor(Color(70, 100, 140))
    title:SizeToContents()

    local instructions = tooltip:AddRow("instructions")
    instructions:SetText("Press E to view/cast ballot")
    instructions:SizeToContents()

    tooltip:SizeToContents()
end

function ENT:OnShouldDrawEntityInfo()
    local ply = LocalPlayer()
    local dist = ply:GetPos():Distance(self:GetPos())
    return dist < 150
end

function ENT:Draw()
    self:DrawModel()
end

-- HUD hint fallback (in case entity info system doesn't work)
hook.Add("HUDPaint", "ixBallotStationHint", function()
    local ply = LocalPlayer()
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid(ent) or ent:GetClass() ~= "ix_ballot_station" then return end
    if ply:GetPos():Distance(ent:GetPos()) > 150 then return end

    local text = "Press E to use Ballot Station"

    draw.SimpleText(text, "ixSmallFont", ScrW() / 2, ScrH() * 0.6,
        Color(255, 255, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
