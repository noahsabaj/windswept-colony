--[[
    Typewriter Entity - Server

    Handles placement, use (E to open UI), and pickup (Hold E).
]]--

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_c17/typewriter01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(CONTINUOUS_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)  -- Stationary by default
    end

    self.useTime = 0
    self.lastUser = nil
end

function ENT:Use(activator, caller, useType, value)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local char = activator:GetCharacter()
    if not char then return end

    -- Track continuous use for hold-to-pickup
    if not self.useStartTime then
        self.useStartTime = CurTime()
        self.usePlayer = activator
    end

    -- Check if different player started using
    if self.usePlayer ~= activator then
        self.useStartTime = CurTime()
        self.usePlayer = activator
    end

    local holdTime = ws.config.Get("itemPickupTime", 0.5)
    local heldDuration = CurTime() - self.useStartTime

    -- Check for hold to pickup
    if heldDuration >= holdTime then
        self:PickUp(activator)
        return
    end

    -- Quick press opens UI (only trigger once per press)
    if useType == USE_ON and heldDuration < 0.1 then
        -- Check if someone else is using it
        local currentUser = self:GetUser()
        if IsValid(currentUser) and currentUser ~= activator then
            activator:NotifyLocalized("typewriterInUse")
            return
        end

        -- Open typewriter UI
        self:SetUser(activator)
        self:OpenUI(activator)
    end
end

function ENT:Think()
    -- Reset use tracking when not being used
    if self.usePlayer and IsValid(self.usePlayer) then
        if not self.usePlayer:KeyDown(IN_USE) then
            self.useStartTime = nil
            self.usePlayer = nil
        end
    else
        self.useStartTime = nil
        self.usePlayer = nil
    end
end

function ENT:OpenUI(client)
    -- Get papers from player's inventory
    local char = client:GetCharacter()
    if not char then return end

    local inv = char:GetInventory()
    if not inv then return end

    -- Find papers
    local papers = {}
    for _, item in ipairs(inv:GetItemsByUniqueID("paper", false)) do
        table.insert(papers, {
            id = item:GetID(),
            name = item:GetName(),
            hasContent = item:HasContent()
        })
    end

    -- Send UI open message
    net.Start("wsTypewriterOpen")
        net.WriteEntity(self)
        net.WriteTable(papers)
    net.Send(client)
end

function ENT:CloseUI(client)
    if self:GetUser() == client then
        self:SetUser(NULL)
    end
end

function ENT:PickUp(client)
    local char = client:GetCharacter()
    if not char then return end

    local inv = char:GetInventory()
    if not inv then return end

    -- Find empty slot
    local item = ws.item.instances[self.wsItemID or self:GetNetVar("wsItemID", 0)]
    if not item then
        -- Create new typewriter item if original doesn't exist
        local success = inv:Add("typewriter", 1)
        if success then
            self:Remove()
            client:NotifyLocalized("typewriterPickedUp")
        else
            client:NotifyLocalized("inventoryFull")
        end
        return
    end

    -- Transfer item back to inventory
    local x, y = inv:FindEmptySlot(item.width, item.height)
    if x and y then
        item:Transfer(inv:GetID(), x, y, client)
        self:Remove()
        client:NotifyLocalized("typewriterPickedUp")
    else
        client:NotifyLocalized("inventoryFull")
    end
end

-- Handle typewriter close from client
net.Receive("wsTypewriterClose", function(len, client)
    local ent = net.ReadEntity()

    if IsValid(ent) and ent:GetClass() == "ix_typewriter" then
        ent:CloseUI(client)
    end
end)

-- Handle typewriter write request
net.Receive("wsTypewriterWrite", function(len, client)
    local ent = net.ReadEntity()
    local paperID = net.ReadUInt(32)
    local content = net.ReadString()

    if not IsValid(ent) or ent:GetClass() ~= "ix_typewriter" then return end
    if ent:GetUser() ~= client then return end

    -- Validate character and item
    local char = client:GetCharacter()
    if not char then return end

    local item = ws.item.instances[paperID]
    if not item or item.uniqueID ~= "paper" then return end

    -- Validate ownership
    local inv = char:GetInventory()
    if not inv then return end

    local found = false
    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == paperID then
            found = true
            break
        end
    end

    if not found then return end

    -- Limit content length
    if #content > ws.documents.MAX_CONTENT_LENGTH then
        content = string.sub(content, 1, ws.documents.MAX_CONTENT_LENGTH)
    end

    -- Create or get paper ID
    local docID = item:GetPaperID()
    local isNewDocument = not docID

    if isNewDocument then
        docID = ws.documents.GenerateID()
    end

    -- Load or create document
    local docData = ws.documents.Load(docID) or {
        content = "",
        entries = {}
    }

    -- Append typed content
    if content ~= "" then
        table.insert(docData.entries, {
            author = char:GetName(),
            timestamp = os.time(),
            type = "typed",
            length = #content
        })

        if docData.content ~= "" then
            docData.content = docData.content .. "\n\n" .. content
        else
            docData.content = content
        end
    end

    -- Save document
    if not ws.documents.Save(docID, docData) then
        client:NotifyLocalized("documentSaveFailed")
        return
    end

    -- Update item data
    item:SetData("paperID", docID)

    if isNewDocument then
        item:SetData("documentType", "typed")
        item:SetData("author", char:GetName())
        item:SetData("timestamp", os.time())
    end

    item:SetData("wordCount", ws.documents.CountWords(docData.content))
    item:SetData("lastEdited", os.time())

    client:NotifyLocalized("documentSaved")

    -- Close UI
    ent:CloseUI(client)
end)
