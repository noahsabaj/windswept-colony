--[[
    Server-Side Document Handlers

    Network handlers for the document system.
    Handles writing, reading, erasing, and signatures.
]]--

-- ============================================================================
-- DOCUMENT WRITE HANDLER
-- ============================================================================

net.Receive("wsDocumentWrite", function(len, client)
    local itemID = net.ReadUInt(32)
    local toolItemID = net.ReadUInt(32)
    local content = net.ReadString()
    local hasSignature = net.ReadBool()
    local signatureJSON = hasSignature and net.ReadString() or nil

    -- Validate paper item ownership
    local item = ws.constants.VerifyItemOwnership(client, itemID, "paper")
    if not item then return end

    local char = client:GetCharacter()
    if not char then return end

    -- Check if there's content to write
    if content == "" and not hasSignature then
        return
    end

    -- Validate writing tool ownership
    local toolItem = ws.constants.VerifyItemOwnership(client, toolItemID)
    if not toolItem then
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

    -- Limit content length BEFORE costing it (so ink/lead isn't charged for text
    -- that gets discarded by truncation)
    if #content > ws.documents.MAX_CONTENT_LENGTH then
        content = string.sub(content, 1, ws.documents.MAX_CONTENT_LENGTH)
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

    -- Get or create paper ID
    local paperID = item:GetPaperID()
    local isNewDocument = not paperID

    if isNewDocument then
        paperID = ws.documents.GenerateID()
    end

    -- Load existing document or create new
    local docData = ws.documents.Load(paperID) or {
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

    -- Add signature (supports multiple signatures). Validate/limit stroke data so
    -- this path can't bypass the caps enforced by wsSignatureSave.
    if hasSignature and signatureJSON then
        local sigData = ws.documents.ValidateSignature(util.JSONToTable(signatureJSON))
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
    if not ws.documents.Save(paperID, docData) then
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

    item:SetData("wordCount", ws.documents.CountWords(docData.content))
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

net.Receive("wsDocumentRead", function(len, client)
    local itemID = net.ReadUInt(32)
    local forEditor = net.ReadBool()

    -- Validate paper item is accessible to the requester (held in their own
    -- inventory or in a container they own). Prevents reading arbitrary documents
    -- by enumerating itemIDs.
    local item = ws.constants.VerifyItemAccessible(client, itemID, "paper")
    if not item then return end

    local paperID = item:GetPaperID()
    if not paperID then return end

    -- Load document
    local docData = ws.documents.Load(paperID)
    if not docData then return end

    local response = {
        content = docData.content or "",
        author = item:GetAuthor(),
        documentType = item:GetDocumentType(),
        wordCount = item:GetWordCount(),
        signatures = docData.signatures or {},
        entries = docData.entries or {}
    }

    net.Start("wsDocumentData")
        net.WriteBool(forEditor)
        net.WriteString(util.TableToJSON(response))
    net.Send(client)
end)

-- ============================================================================
-- DOCUMENT ERASE HANDLER
-- ============================================================================

net.Receive("wsDocumentErase", function(len, client)
    local itemID = net.ReadUInt(32)

    -- Validate paper item ownership
    local item = ws.constants.VerifyItemOwnership(client, itemID, "paper")
    if not item then return end

    -- Check if document is erasable (pencil only)
    if item:GetDocumentType() ~= "pencil" then
        client:NotifyLocalized("cannotErasePen")
        return
    end

    -- Find eraser in inventory (standalone eraser or pencil with eraser)
    local _, inv = ws.constants.GetCharacterInventory(client)
    if not inv then return end

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

    local docData = ws.documents.Load(paperID)
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
    ws.documents.Delete(paperID)

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

net.Receive("wsDocumentDestroy", function(len, client)
    local itemID = net.ReadUInt(32)

    -- Validate character
    -- Validate paper item ownership
    local item = ws.constants.VerifyItemOwnership(client, itemID, "paper")
    if not item then return end

    -- Delete document file if exists
    local paperID = item:GetPaperID()
    if paperID then
        ws.documents.Delete(paperID)
    end

    -- Remove the item
    item:Remove()

    client:NotifyLocalized("documentDestroyed")
end)

-- ============================================================================
-- CONTAINER RENAME HANDLER (envelopes, folders)
-- ============================================================================

net.Receive("wsContainerRename", function(len, client)
    local itemID = net.ReadUInt(32)
    local newName = net.ReadString()

    -- Validate container ownership (no specific uniqueID filter)
    local item = ws.constants.VerifyItemOwnership(client, itemID)
    if not item then return end

    -- Only allow renaming containers (envelopes, folders)
    local validContainers = {
        envelope_small = true,
        envelope_large = true,
        folder = true
    }

    if not validContainers[item.uniqueID] then return end

    -- Check for writing tool in inventory
    if not ws.documents.HasWritingTool(client) then
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

net.Receive("wsSignatureSave", function(len, client)
    local signatureJSON = net.ReadString()

    -- Validate character
    local char = client:GetCharacter()
    if not char then return end

    -- Parse signature data (silent return on malformed JSON)
    local parsed = util.JSONToTable(signatureJSON)
    if type(parsed) ~= "table" then return end

    -- Validate and limit stroke data (prevent abuse)
    local strokes = ws.documents.ValidateSignature(parsed)
    if not strokes then
        client:NotifyLocalized("signatureTooComplex")
        return
    end

    -- Save to character data
    char:SetData("savedSignature", strokes)

    client:NotifyLocalized("signatureSaved")
end)

-- NOTE: pen refilling is handled by the writer base's `combine` function
-- (schema/items/base/sh_writer.lua), which is properly ownership-checked. The old
-- wsPenRefill net handler here was dead (no client ever sent it) and broken
-- (referenced a non-existent maxInk field), so it was removed along with its
-- network string in sv_netstrings.lua.
