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

-- Clear the User netvar if the entity is removed while someone has the UI open,
-- mirroring ws_stationary_radio's cleanup. (sc-entities-interactive-8)
function ENT:OnRemove()
    local user = self:GetUser()

    if IsValid(user) then
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

-- Handle typewriter close from client. session = true now requires ent:GetUser() == client,
-- so only the player who opened the UI can close it (previously any player could close
-- another player's open typewriter). (session shape)
ws.action.Register("wsTypewriterClose", {
    target = true,
    targetClass = "ws_typewriter",
    session = true,
    range = "none",
    run = function(client, ctx)
        ctx.target:CloseUI(client)
    end,
})

-- Handle typewriter write request. session = true requires ent:GetUser() == client; the 200u
-- proximity re-check (and server-side UI close when exceeded) moves into onValidate so the
-- client UI can never enforce range. (sc-entities-interactive-1 / session shape)
ws.action.Register("wsTypewriterWrite", {
    target = true,
    targetClass = "ws_typewriter",
    session = true,
    range = "none",
    read = function()
        return {
            paperID = net.ReadUInt(32),
            content = net.ReadString(),
        }
    end,
    onValidate = function(client, ctx)
        if client:GetPos():DistToSqr(ctx.target:GetPos()) > (200 * 200) then
            ctx.target:CloseUI(client)
            return false
        end
        return true
    end,
    run = function(client, ctx)
        local ent = ctx.target
        local paperID = ctx.data.paperID
        local content = ctx.data.content

        -- Validate character and item ownership via the shared guard, matching
        -- sv_documents.lua's wsDocumentWrite. (sc-entities-interactive-6)
        local char = client:GetCharacter()
        if not char then return end

        local item = ws.constants.VerifyItemOwnership(client, paperID, "paper")
        if not item then return end

        local inv = char:GetInventory()
        if not inv then return end

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

        -- Cap total accumulated document size to prevent unbounded growth. (sc-schema-glue-1)
        if content ~= "" and #docData.content + #content > ws.documents.MAX_DOCUMENT_LENGTH then
            local room = ws.documents.MAX_DOCUMENT_LENGTH - #docData.content

            if room <= 0 then
                client:NotifyLocalized("documentFull")
                return
            end

            content = string.sub(content, 1, room)
        end

        -- Append typed content. Fog-of-war: entries do NOT record the writer's character name;
        -- a document is anonymous unless signed or the writer types their name into the content.
        -- Documents remain collaborative — any owner of the paper may append. (sc-schema-glue-2 / sc-entities-interactive-10)
        if content ~= "" then
            table.insert(docData.entries, {
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

        -- Fog-of-war: don't store the author's character name. (sc-schema-glue-2)
        if isNewDocument then
            item:SetData("documentType", "typed")
            item:SetData("timestamp", os.time())
        end

        item:SetData("wordCount", ws.documents.CountWords(docData.content))
        item:SetData("lastEdited", os.time())

        client:NotifyLocalized("documentSaved")

        -- Close UI
        ent:CloseUI(client)
    end,
})

-- Clear the User netvar on death/disconnect so the typewriter isn't left locked
-- to an absent player, mirroring ws_stationary_radio. (sc-entities-interactive-8)
hook.Add("PlayerDeath", "wsTypewriterPlayerDeath", function(victim)
    for _, ent in ipairs(ents.FindByClass("ws_typewriter")) do
        if ent:GetUser() == victim then
            ent:CloseUI(victim)
        end
    end
end)

hook.Add("PlayerDisconnected", "wsTypewriterPlayerDisconnect", function(client)
    for _, ent in ipairs(ents.FindByClass("ws_typewriter")) do
        if ent:GetUser() == client then
            ent:SetUser(NULL)
        end
    end
end)
