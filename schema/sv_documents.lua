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
    local toolItemID = net.ReadUInt(32)
    local content = net.ReadString()
    local hasSignature = net.ReadBool()
    local signatureJSON = hasSignature and net.ReadString() or nil
    local isRename = net.ReadBool()
    local newTitle = net.ReadString()

    -- Validate character
    local char = client:GetCharacter()
    if not char then return end

    -- Validate paper item
    local item = ix.item.instances[itemID]
    if not item then return end
    if item.uniqueID ~= "paper" then return end

    -- Validate ownership
    local inv = char:GetInventory()
    if not inv then return end

    local foundPaper = false
    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == itemID then
            foundPaper = true
            break
        end
    end

    if not foundPaper then return end

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

    -- Validate writing tool from inventory
    local toolItem = ix.item.instances[toolItemID]
    if not toolItem then
        client:NotifyLocalized("needWritingTool")
        return
    end

    -- Verify tool is in player's inventory
    local foundTool = false
    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == toolItemID then
            foundTool = true
            break
        end
    end

    if not foundTool then
        client:NotifyLocalized("needWritingTool")
        return
    end

    -- Determine tool type, resource, and color
    local toolType
    local resourceKey
    local strokeColor

    -- Check if it's a pen (base pen or colored variants)
    local isPen = toolItem.uniqueID == "pen" or
                  toolItem.uniqueID == "pen_black" or
                  toolItem.uniqueID == "pen_red" or
                  toolItem.uniqueID == "pen_green"

    if isPen then
        toolType = "handwritten"
        resourceKey = "ink"
        strokeColor = toolItem:GetInkColor()
    elseif toolItem.uniqueID == "pencil" or toolItem.uniqueID == "pencil_eraser" then
        toolType = "pencil"
        resourceKey = "lead"
        strokeColor = {150, 150, 150}  -- Gray for pencil
    else
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
        currentResource = toolItem:GetLead()
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
        -- Add entry record with color
        table.insert(docData.entries, {
            author = char:GetName(),
            timestamp = os.time(),
            type = toolType,
            color = strokeColor,
            length = #content
        })

        -- Append to content
        if docData.content ~= "" then
            docData.content = docData.content .. "\n\n" .. content
        else
            docData.content = content
        end
    end

    -- Add signature (supports multiple signatures)
    if hasSignature and signatureJSON then
        local sigData = util.JSONToTable(signatureJSON)
        if sigData then
            -- Initialize signatures array if not present
            docData.signatures = docData.signatures or {}

            -- Add new signature with color
            table.insert(docData.signatures, {
                strokes = sigData,
                authorName = char:GetName(),
                timestamp = os.time(),
                color = strokeColor,
                type = toolType  -- "handwritten" for pen, "pencil" for pencil
            })
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
        -- Store count of signatures for display
        item:SetData("signatureCount", #(docData.signatures or {}))
    end

    -- Consume resource from tool
    if resourceKey == "ink" then
        toolItem:UseInk(totalCost)
    else
        toolItem:UseLead(totalCost)
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

    -- Build response (support both old signatureData and new signatures array)
    local response = {
        content = docData.content or "",
        title = item:GetTitle(),
        author = item:GetAuthor(),
        documentType = item:GetDocumentType(),
        wordCount = item:GetWordCount(),
        signatures = docData.signatures or {},
        entries = docData.entries or {}  -- Include entries for color info
    }

    -- Backwards compatibility: convert old single signature to array
    if docData.signatureData and #response.signatures == 0 then
        table.insert(response.signatures, docData.signatureData)
    end

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

    local foundPaper = false
    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == itemID then
            foundPaper = true
            break
        end
    end

    if not foundPaper then return end

    -- Check if document is erasable (pencil only)
    if item:GetDocumentType() ~= "pencil" then
        client:NotifyLocalized("cannotErasePen")
        return
    end

    -- Find eraser in inventory (standalone eraser or pencil with eraser)
    local eraserItem = nil
    for _, invItem in pairs(inv:GetItems()) do
        if invItem.uniqueID == "eraser" and invItem:GetDurability() > 0 then
            eraserItem = invItem
            break
        elseif invItem.uniqueID == "pencil_eraser" then
            eraserItem = invItem
            break
        end
    end

    if not eraserItem then
        client:NotifyLocalized("needEraser")
        return
    end

    -- Get document data for eraser cost calculation
    local paperID = item:GetPaperID()
    if not paperID then return end

    local docData = ix.documents.Load(paperID)
    if not docData then return end

    local contentLength = #(docData.content or "")

    -- Check and consume eraser durability (if standalone eraser)
    if eraserItem.uniqueID == "eraser" then
        local durability = eraserItem:GetDurability()
        if durability < contentLength then
            client:NotifyLocalized("eraserNotEnoughDurability")
            return
        end

        -- Consume durability
        eraserItem:UseDurability(contentLength)
    end
    -- Pencil with eraser has unlimited erasing (no durability cost)

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

-- ============================================================================
-- DOCUMENT DESTROY HANDLER
-- ============================================================================

net.Receive("ixDocumentDestroy", function(len, client)
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

    local foundPaper = false
    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == itemID then
            foundPaper = true
            break
        end
    end

    if not foundPaper then return end

    -- Delete document file if exists
    local paperID = item:GetPaperID()
    if paperID then
        ix.documents.Delete(paperID)
    end

    -- Remove the item
    item:Remove()

    client:NotifyLocalized("documentDestroyed")
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
