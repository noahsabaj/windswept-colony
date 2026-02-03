--[[
    Server-Side Document Handlers

    Network handlers for the document system.
    Handles writing, reading, erasing, and signatures.
]]--

-- ============================================================================
-- DOCUMENT WRITE HANDLER
-- ============================================================================

net.Receive("ixDocumentWrite", function(len, client)
    local itemID = net.ReadUInt(32)
    local content = net.ReadString()
    local hasSignature = net.ReadBool()
    local signatureJSON = hasSignature and net.ReadString() or nil
    local isRename = net.ReadBool()
    local newTitle = net.ReadString()

    -- Validate character
    local char = client:GetCharacter()
    if not char then return end

    -- Validate item
    local item = ix.item.instances[itemID]
    if not item then return end
    if item.uniqueID ~= "paper" then return end

    -- Validate ownership
    local inv = char:GetInventory()
    if not inv then return end

    local found = false
    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == itemID then
            found = true
            break
        end
    end

    if not found then return end

    -- Handle rename-only operation
    if isRename and newTitle ~= "" then
        if not item:HasTitle() then
            item:SetData("title", string.sub(newTitle, 1, 64))
            item:SetData("titleSet", true)
            client:NotifyLocalized("documentRenamed", newTitle)
        else
            client:NotifyLocalized("documentAlreadyNamed")
        end
        return
    end

    -- Check if there's content to write
    if content == "" and not hasSignature then
        return
    end

    -- Validate writing tool
    local weapon = client:GetActiveWeapon()
    if not IsValid(weapon) then
        client:NotifyLocalized("needWritingTool")
        return
    end

    local toolType
    local toolItem
    local resourceKey

    if weapon:GetClass() == "ix_pen" then
        toolType = "handwritten"
        toolItem = client.ixPenItem
        resourceKey = "ink"
    elseif weapon:GetClass() == "ix_pencil" then
        toolType = "pencil"
        toolItem = client.ixPencilItem
        resourceKey = "lead"
    else
        client:NotifyLocalized("needWritingTool")
        return
    end

    if not toolItem then
        client:NotifyLocalized("needWritingTool")
        return
    end

    -- Calculate resource cost
    local contentCost = #content
    local signatureCost = hasSignature and 50 or 0
    local totalCost = contentCost + signatureCost

    -- Check resource availability
    local currentResource
    if resourceKey == "ink" then
        currentResource = toolItem:GetInk()
    else
        currentResource = toolItem:GetData("lead", 500)
    end

    if totalCost > currentResource then
        client:NotifyLocalized("notEnough" .. (resourceKey == "ink" and "Ink" or "Lead"))
        return
    end

    -- Limit content length
    if #content > ix.documents.MAX_CONTENT_LENGTH then
        content = string.sub(content, 1, ix.documents.MAX_CONTENT_LENGTH)
    end

    -- Get or create paper ID
    local paperID = item:GetPaperID()
    local isNewDocument = not paperID

    if isNewDocument then
        paperID = ix.documents.GenerateID()
    end

    -- Load existing document or create new
    local docData = ix.documents.Load(paperID) or {
        content = "",
        entries = {}
    }

    -- Append new content
    if content ~= "" then
        -- Add entry record
        table.insert(docData.entries, {
            author = char:GetName(),
            timestamp = os.time(),
            type = toolType,
            length = #content
        })

        -- Append to content
        if docData.content ~= "" then
            docData.content = docData.content .. "\n\n" .. content
        else
            docData.content = content
        end
    end

    -- Add signature
    if hasSignature and signatureJSON then
        local sigData = util.JSONToTable(signatureJSON)
        if sigData then
            docData.signatureData = {
                strokes = sigData,
                authorName = char:GetName(),
                timestamp = os.time()
            }
        end
    end

    -- Save document file
    if not ix.documents.Save(paperID, docData) then
        client:NotifyLocalized("documentSaveFailed")
        return
    end

    -- Update item data
    item:SetData("paperID", paperID)

    -- Only set document type on first write
    if isNewDocument then
        item:SetData("documentType", toolType)
        item:SetData("author", char:GetName())
        item:SetData("timestamp", os.time())
    end

    item:SetData("wordCount", ix.documents.CountWords(docData.content))
    item:SetData("lastEdited", os.time())

    if hasSignature then
        item:SetData("hasSignature", true)
        item:SetData("signatureAuthor", char:GetName())
    end

    -- Consume resource
    if resourceKey == "ink" then
        toolItem:UseInk(totalCost)
    else
        local newLead = math.max(0, toolItem:GetData("lead", 500) - totalCost)
        toolItem:SetData("lead", newLead)
    end

    client:NotifyLocalized("documentSaved")
end)

-- ============================================================================
-- DOCUMENT READ HANDLER
-- ============================================================================

net.Receive("ixDocumentRead", function(len, client)
    local itemID = net.ReadUInt(32)
    local forEditor = net.ReadBool()

    -- Validate item
    local item = ix.item.instances[itemID]
    if not item then return end
    if item.uniqueID ~= "paper" then return end

    local paperID = item:GetPaperID()
    if not paperID then return end

    -- Load document
    local docData = ix.documents.Load(paperID)
    if not docData then return end

    -- Build response
    local response = {
        content = docData.content or "",
        title = item:GetTitle(),
        author = item:GetAuthor(),
        documentType = item:GetDocumentType(),
        wordCount = item:GetWordCount(),
        signatureData = docData.signatureData
    }

    net.Start("ixDocumentData")
        net.WriteBool(forEditor)
        net.WriteString(util.TableToJSON(response))
    net.Send(client)
end)

-- ============================================================================
-- DOCUMENT ERASE HANDLER
-- ============================================================================

net.Receive("ixDocumentErase", function(len, client)
    local itemID = net.ReadUInt(32)

    -- Validate character
    local char = client:GetCharacter()
    if not char then return end

    -- Validate item
    local item = ix.item.instances[itemID]
    if not item then return end
    if item.uniqueID ~= "paper" then return end

    -- Validate ownership
    local inv = char:GetInventory()
    if not inv then return end

    local found = false
    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == itemID then
            found = true
            break
        end
    end

    if not found then return end

    -- Check if document is erasable (pencil only)
    if item:GetDocumentType() ~= "pencil" then
        client:NotifyLocalized("cannotErasePen")
        return
    end

    -- Validate eraser tool
    local weapon = client:GetActiveWeapon()
    if not IsValid(weapon) then
        client:NotifyLocalized("needEraser")
        return
    end

    local hasEraser = false
    local eraserItem = nil

    if weapon:GetClass() == "ix_eraser" then
        hasEraser = true
        eraserItem = client.ixEraserItem
    elseif weapon:GetClass() == "ix_pencil" then
        local pencilItem = client.ixPencilItem
        if pencilItem and pencilItem.hasEraser then
            hasEraser = true
            eraserItem = pencilItem
        end
    end

    if not hasEraser then
        client:NotifyLocalized("needEraser")
        return
    end

    -- Get document data for eraser cost calculation
    local paperID = item:GetPaperID()
    if not paperID then return end

    local docData = ix.documents.Load(paperID)
    if not docData then return end

    local contentLength = #(docData.content or "")

    -- Check eraser durability (if standalone eraser)
    if eraserItem and eraserItem.uniqueID == "eraser" then
        local durability = eraserItem:GetData("durability", 500)
        if durability < contentLength then
            client:NotifyLocalized("eraserNotEnoughDurability")
            return
        end

        -- Consume durability
        eraserItem:SetData("durability", durability - contentLength)
    end

    -- Delete the document file
    ix.documents.Delete(paperID)

    -- Reset item data to blank paper
    item:SetData("paperID", nil)
    item:SetData("documentType", nil)
    item:SetData("author", nil)
    item:SetData("title", nil)
    item:SetData("titleSet", nil)
    item:SetData("wordCount", nil)
    item:SetData("hasSignature", nil)
    item:SetData("signatureAuthor", nil)
    item:SetData("timestamp", nil)
    item:SetData("lastEdited", nil)

    client:NotifyLocalized("documentErased")
end)

-- ============================================================================
-- PEN REFILL HANDLER
-- ============================================================================

net.Receive("ixPenRefill", function(len, client)
    local penItemID = net.ReadUInt(32)
    local cartridgeItemID = net.ReadUInt(32)

    -- Validate character
    local char = client:GetCharacter()
    if not char then return end

    -- Validate items
    local penItem = ix.item.instances[penItemID]
    local cartridgeItem = ix.item.instances[cartridgeItemID]

    if not penItem or not cartridgeItem then return end
    if penItem.uniqueID ~= "pen" then return end
    if cartridgeItem.uniqueID ~= "ink_cartridge" then return end

    -- Validate ownership
    local inv = char:GetInventory()
    if not inv then return end

    local foundPen = false
    local foundCartridge = false

    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == penItemID then foundPen = true end
        if invItem:GetID() == cartridgeItemID then foundCartridge = true end
    end

    if not foundPen or not foundCartridge then return end

    -- Check if pen needs refill
    if penItem:GetInk() >= penItem.maxInk then
        client:NotifyLocalized("penAlreadyFull")
        return
    end

    -- Refill pen
    penItem:Refill(penItem.maxInk)

    -- Remove cartridge
    cartridgeItem:Remove()

    client:NotifyLocalized("penRefilled")
end)
