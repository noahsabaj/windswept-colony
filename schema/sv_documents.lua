--[[
    Server-Side Document Handlers

    Network handlers for the document system.
    Handles writing, reading, erasing, and signatures.
]]--

-- Check if a specific item (by ID) exists in an inventory
local function InvHasItem(inv, itemID)
    for _, invItem in pairs(inv:GetItems()) do
        if invItem:GetID() == itemID then
            return true
        end
    end
    return false
end

-- ============================================================================
-- DOCUMENT WRITE HANDLER
-- ============================================================================

net.Receive("ixDocumentWrite", function(len, client)
    local itemID = net.ReadUInt(32)
    local toolItemID = net.ReadUInt(32)
    local content = net.ReadString()
    local hasSignature = net.ReadBool()
    local signatureJSON = hasSignature and net.ReadString() or nil

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

    if not InvHasItem(inv, itemID) then return end

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
    if not InvHasItem(inv, toolItemID) then
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

    local response = {
        content = docData.content or "",
        author = item:GetAuthor(),
        documentType = item:GetDocumentType(),
        wordCount = item:GetWordCount(),
        signatures = docData.signatures or {},
        entries = docData.entries or {}
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

    if not InvHasItem(inv, itemID) then return end

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

    if not InvHasItem(inv, itemID) then return end

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
-- CONTAINER RENAME HANDLER (envelopes, folders)
-- ============================================================================

net.Receive("ixContainerRename", function(len, client)
    local itemID = net.ReadUInt(32)
    local newName = net.ReadString()

    -- Validate character
    local char = client:GetCharacter()
    if not char then return end

    -- Validate item
    local item = ix.item.instances[itemID]
    if not item then return end

    -- Only allow renaming containers (envelopes, folders)
    local validContainers = {
        envelope_small = true,
        envelope_large = true,
        folder = true
    }

    if not validContainers[item.uniqueID] then return end

    -- Validate ownership
    local inv = char:GetInventory()
    if not inv then return end

    if not InvHasItem(inv, itemID) then return end

    -- Check for writing tool in inventory
    if not ix.documents.HasWritingTool(client) then
        client:NotifyLocalized("needWritingTool")
        return
    end

    -- Set the custom name (empty string clears it)
    if newName == "" then
        item:SetData("customName", nil)
    else
        item:SetData("customName", string.sub(newName, 1, 32))
    end

    client:NotifyLocalized("containerRenamed")
end)

-- ============================================================================
-- SIGNATURE SAVE HANDLER
-- ============================================================================

net.Receive("ixSignatureSave", function(len, client)
    local signatureJSON = net.ReadString()

    -- Validate character
    local char = client:GetCharacter()
    if not char then return end

    -- Parse signature data
    local strokes = util.JSONToTable(signatureJSON)
    if not strokes or type(strokes) ~= "table" then return end

    -- Validate and limit stroke data (prevent abuse)
    local maxStrokes = 50
    local maxPointsTotal = 500
    local totalPoints = 0

    if #strokes > maxStrokes then
        -- Truncate to max strokes
        local truncated = {}
        for i = 1, maxStrokes do
            truncated[i] = strokes[i]
        end
        strokes = truncated
    end

    -- Count and limit total points
    for i, stroke in ipairs(strokes) do
        if type(stroke) ~= "table" then
            strokes[i] = {}
        else
            totalPoints = totalPoints + #stroke
        end
    end

    if totalPoints > maxPointsTotal then
        -- Too many points, reject
        client:NotifyLocalized("signatureTooComplex")
        return
    end

    -- Save to character data
    char:SetData("savedSignature", strokes)

    client:NotifyLocalized("signatureSaved")
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

    if not InvHasItem(inv, penItemID) or not InvHasItem(inv, cartridgeItemID) then return end

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
