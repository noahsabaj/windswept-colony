--[[
    Stationary Radio (Dispatch Console)
    Multi-channel radio for fixed locations
]]--

ITEM.name = "Stationary Radio"
ITEM.description = "A multi-channel dispatch radio console. Place it down to use."
ITEM.model = Model("models/props_lab/citizenradio.mdl")
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Equipment"

-- Don't inherit base_equipment, we're a simple droppable item
ITEM.base = "base_misc"

-- Initialize default channel data on spawn
function ITEM:OnInstanced()
    if not self:GetData("channels") then
        -- Safety check for library availability (defensive against load order issues)
        if ix.radio and ix.radio.GetDefaultChannels then
            self:SetData("channels", ix.radio.GetDefaultChannels())
        else
            -- Fallback to inline defaults
            self:SetData("channels", {
                {freq = "100.0", tx = false, rx = false, vol = 50},
                {freq = "100.0", tx = false, rx = false, vol = 50},
                {freq = "100.0", tx = false, rx = false, vol = 50},
                {freq = "100.0", tx = false, rx = false, vol = 50}
            })
        end
    end
end

if SERVER then
    -- Override drop behavior to spawn our custom entity
    function ITEM:OnDrop()
        local client = self:GetOwner()
        if not IsValid(client) then return end

        -- Get drop position
        local trace = client:GetEyeTrace()
        local pos = trace.HitPos + trace.HitNormal * 5

        -- Create the stationary radio entity
        local ent = ents.Create("ix_stationary_radio")

        if not IsValid(ent) then
            return -- Allow default behavior as fallback
        end

        ent:SetPos(pos)
        ent:SetAngles(Angle(0, client:EyeAngles().y, 0))

        -- Transfer channel data to entity before spawn
        local channels = self:GetData("channels") or ix.radio.GetDefaultChannels()
        ent.pendingChannels = channels

        ent:Spawn()
        ent:Activate()

        -- Remove item from inventory
        local inventory = self:GetInventory()
        if inventory then
            inventory:Remove(self:GetID())
        end

        return false -- Prevent default ix_item spawn
    end
end

-- Tooltip shows channel summary
function ITEM:PopulateTooltip(tooltip)
    local channels = self:GetData("channels") or ix.radio.GetDefaultChannels()

    local panel = tooltip:AddRowAfter("description", "channels")
    panel:SetBackgroundColor(Color(0, 0, 0, 0))

    local text = ""
    for i, ch in ipairs(channels) do
        local status = ""
        if ch.tx then status = status .. "TX " end
        if ch.rx then status = status .. "RX" end
        if status == "" then status = "OFF" end

        text = text .. string.format("CH%d: %s [%s]\n", i, ch.freq, status)
    end

    panel:SetText(text:Trim())
    panel:SizeToContents()
end
