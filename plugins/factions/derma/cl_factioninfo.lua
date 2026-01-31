--[[
    Faction Info Panel
    Shows detailed faction information with org charts
    Tabs: Classes list, Class Org Chart, Member Org Chart
]]--

local PANEL = {}

function PANEL:Init()
    self:SetSize(700, 500)
    self:SetTitle("")
    self:Center()
    self:MakePopup()
    self:SetDraggable(true)

    self.factionName = ""
    self.classes = {}
    self.members = {}
end

function PANEL:SetData(factionName, classes, members)
    self.factionName = factionName
    self.classes = classes
    self.members = members
    self:BuildUI()
end

function PANEL:BuildUI()
    -- Tabs
    self.tabs = self:Add("DPropertySheet")
    self.tabs:Dock(FILL)
    self.tabs:DockMargin(10, 40, 10, 10)

    -- Tab 1: Class List
    local listPanel = vgui.Create("DPanel")
    listPanel.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 42, 48))
    end
    self:BuildClassList(listPanel)
    self.tabs:AddSheet("Classes", listPanel, "icon16/group.png")

    -- Tab 2: Class Org Chart
    local classOrgPanel = vgui.Create("DPanel")
    classOrgPanel.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 42, 48))
    end
    self:BuildClassOrgChart(classOrgPanel)
    self.tabs:AddSheet("Class Org Chart", classOrgPanel, "icon16/chart_organisation.png")

    -- Tab 3: Member Org Chart
    local memberOrgPanel = vgui.Create("DPanel")
    memberOrgPanel.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 42, 48))
    end
    self:BuildMemberOrgChart(memberOrgPanel)
    self.tabs:AddSheet("Member Org Chart", memberOrgPanel, "icon16/group_link.png")
end

function PANEL:BuildClassList(parent)
    local list = parent:Add("DListView")
    list:Dock(FILL)
    list:DockMargin(10, 10, 10, 10)
    list:SetMultiSelect(false)

    list:AddColumn("Rank"):SetWidth(50)
    list:AddColumn("Class"):SetWidth(150)
    list:AddColumn("Pay"):SetWidth(80)
    list:AddColumn("Members"):SetWidth(70)
    list:AddColumn("Type"):SetWidth(80)

    for _, classData in ipairs(self.classes) do
        local typeStr = "Dynamic"
        if classData.isAnchor then typeStr = "Anchor"
        elseif classData.isDefault then typeStr = "Default" end

        local line = list:AddLine(
            classData.rank,
            classData.name,
            "$" .. classData.pay,
            classData.memberCount,
            typeStr
        )
        line.classData = classData
    end

    list.OnRowSelected = function(lst, idx, row)
        self:ShowClassDetails(row.classData)
    end
end

function PANEL:BuildClassOrgChart(parent)
    local scroll = parent:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    -- Group classes by rank
    local byRank = {}
    for _, classData in ipairs(self.classes) do
        byRank[classData.rank] = byRank[classData.rank] or {}
        table.insert(byRank[classData.rank], classData)
    end

    -- Sort ranks descending
    local ranks = {}
    for rank, _ in pairs(byRank) do
        table.insert(ranks, rank)
    end
    table.sort(ranks, function(a, b) return a > b end)

    -- Draw hierarchy
    local y = 10
    for _, rank in ipairs(ranks) do
        local classes = byRank[rank]

        -- Rank label
        local rankLabel = scroll:Add("DLabel")
        rankLabel:SetPos(10, y)
        rankLabel:SetSize(680, 25)
        rankLabel:SetText("Rank " .. rank)
        rankLabel:SetFont("ixMediumFont")
        rankLabel:SetTextColor(Color(150, 180, 220))
        y = y + 30

        -- Class boxes
        local x = 30
        for _, classData in ipairs(classes) do
            local box = scroll:Add("DButton")
            box:SetPos(x, y)
            box:SetSize(150, 60)
            box:SetText("")
            box.classData = classData

            box.Paint = function(pnl, w, h)
                local col = classData.isAnchor and Color(80, 60, 100) or
                           classData.isDefault and Color(60, 80, 60) or
                           Color(50, 55, 65)
                if pnl:IsHovered() then
                    col = Color(col.r + 20, col.g + 20, col.b + 20)
                end
                draw.RoundedBox(4, 0, 0, w, h, col)
                surface.SetDrawColor(80, 85, 95)
                surface.DrawOutlinedRect(0, 0, w, h)

                draw.SimpleText(classData.name, "ixSmallFont", w/2, 20,
                    color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(classData.memberCount .. " member(s)", "ixSmallFont", w/2, 40,
                    Color(180, 180, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            box.DoClick = function()
                self:ShowClassDetails(classData)
            end

            x = x + 160
        end

        y = y + 70
    end

    scroll:GetCanvas():SetTall(y + 20)
end

function PANEL:BuildMemberOrgChart(parent)
    local scroll = parent:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    -- Group members by rank
    local byRank = {}
    for _, member in ipairs(self.members) do
        byRank[member.rank] = byRank[member.rank] or {}
        table.insert(byRank[member.rank], member)
    end

    -- Sort ranks descending
    local ranks = {}
    for rank, _ in pairs(byRank) do
        table.insert(ranks, rank)
    end
    table.sort(ranks, function(a, b) return a > b end)

    -- Draw hierarchy
    local y = 10
    for _, rank in ipairs(ranks) do
        local members = byRank[rank]

        -- Rank label
        local rankLabel = scroll:Add("DLabel")
        rankLabel:SetPos(10, y)
        rankLabel:SetSize(680, 25)
        rankLabel:SetText("Rank " .. rank)
        rankLabel:SetFont("ixMediumFont")
        rankLabel:SetTextColor(Color(150, 180, 220))
        y = y + 30

        -- Member boxes
        local x = 30
        for _, member in ipairs(members) do
            local box = scroll:Add("DPanel")
            box:SetPos(x, y)
            box:SetSize(150, 60)

            box.Paint = function(pnl, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(50, 55, 65))
                surface.SetDrawColor(80, 85, 95)
                surface.DrawOutlinedRect(0, 0, w, h)

                draw.SimpleText(member.name, "ixSmallFont", w/2, 20,
                    color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(member.className, "ixSmallFont", w/2, 40,
                    Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            x = x + 160
            if x > 500 then
                x = 30
                y = y + 70
            end
        end

        y = y + 70
    end

    scroll:GetCanvas():SetTall(y + 20)
end

function PANEL:ShowClassDetails(classData)
    -- Create detail popup
    local popup = vgui.Create("DFrame")
    popup:SetSize(300, 250)
    popup:SetTitle(classData.name)
    popup:Center()
    popup:MakePopup()

    local content = popup:Add("DPanel")
    content:Dock(FILL)
    content:DockMargin(10, 10, 10, 10)
    content.Paint = function() end

    local addRow = function(label, value)
        local row = content:Add("DPanel")
        row:Dock(TOP)
        row:SetTall(25)
        row.Paint = function() end

        local lbl = row:Add("DLabel")
        lbl:Dock(LEFT)
        lbl:SetWide(100)
        lbl:SetText(label .. ":")
        lbl:SetFont("ixSmallFont")
        lbl:SetTextColor(Color(150, 150, 150))

        local val = row:Add("DLabel")
        val:Dock(FILL)
        val:SetText(tostring(value))
        val:SetFont("ixSmallFont")
        val:SetTextColor(color_white)
    end

    addRow("Rank", classData.rank)
    addRow("Pay", "$" .. classData.pay)
    addRow("Members", classData.memberCount)
    addRow("Type", classData.isAnchor and "Anchor" or (classData.isDefault and "Default" or "Dynamic"))

    -- Permissions
    if classData.permissions then
        local permLabel = content:Add("DLabel")
        permLabel:Dock(TOP)
        permLabel:DockMargin(0, 10, 0, 5)
        permLabel:SetTall(20)
        permLabel:SetText("Permissions:")
        permLabel:SetFont("ixSmallFont")
        permLabel:SetTextColor(Color(150, 150, 150))

        local perms = {}
        for perm, has in pairs(classData.permissions) do
            if has then
                table.insert(perms, perm)
            end
        end

        local permText = content:Add("DLabel")
        permText:Dock(TOP)
        permText:SetTall(40)
        permText:SetText(#perms > 0 and table.concat(perms, ", ") or "None")
        permText:SetFont("ixSmallFont")
        permText:SetTextColor(color_white)
        permText:SetWrap(true)
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, Color(35, 38, 45, 250))

    -- Header
    draw.RoundedBoxEx(4, 0, 0, w, 35, Color(50, 80, 120), true, true, false, false)
    draw.SimpleText(self.factionName .. " - Faction Info", "ixMediumFont", w/2, 17,
        color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(60, 60, 70)
    surface.DrawOutlinedRect(0, 0, w, h)
end

vgui.Register("ixFactionInfoPanel", PANEL, "DFrame")
