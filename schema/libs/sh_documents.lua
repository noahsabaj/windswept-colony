--[[
    Document Library

    File-based storage for document content (like the photo system).
    Documents are stored in data/ix_documents/ as JSON files.
    Items only store reference IDs, preventing inventory sync overflow.

    Document data structure:
    {
        content = "Text content of the document",
        entries = {
            {
                author = "Character Name",
                timestamp = 1234567890,
                type = "handwritten" | "pencil" | "typed",
                content = "Entry content"
            },
            ...
        },
        signatureData = {
            strokes = {{x=0.1, y=0.2}, ...},
            authorName = "Signer Name",
            timestamp = 1234567890
        }
    }
]]--

ix.documents = ix.documents or {}

-- Document storage directory
ix.documents.STORAGE_DIR = "ix_documents"

-- Maximum content length per write (prevents abuse)
ix.documents.MAX_CONTENT_LENGTH = 10000

-- ============================================================================
-- ID GENERATION AND VALIDATION
-- ============================================================================

-- Generate unique document ID (timestamp + random)
function ix.documents.GenerateID()
    return os.time() .. "_" .. math.random(10000, 99999)
end

-- Validate document ID format (prevents path traversal)
function ix.documents.ValidateID(id)
    return isstring(id) and id:match("^%d+_%d+$") ~= nil
end

-- Get file path for document
function ix.documents.GetFilePath(documentID)
    if not ix.documents.ValidateID(documentID) then return nil end
    return ix.documents.STORAGE_DIR .. "/" .. documentID .. ".json"
end

-- ============================================================================
-- SERVER-SIDE FILE OPERATIONS
-- ============================================================================

if SERVER then
    -- Ensure storage directory exists
    file.CreateDir(ix.documents.STORAGE_DIR)

    -- Save document content to file
    -- @param documentID string The document's unique ID
    -- @param data table The document data to save
    -- @return boolean Success
    function ix.documents.Save(documentID, data)
        if not ix.documents.ValidateID(documentID) then return false end

        local path = ix.documents.GetFilePath(documentID)
        if not path then return false end

        local json = util.TableToJSON(data, true)
        if not json then return false end

        file.Write(path, json)
        return true
    end

    -- Load document content from file
    -- @param documentID string The document's unique ID
    -- @return table|nil The document data or nil if not found
    function ix.documents.Load(documentID)
        if not ix.documents.ValidateID(documentID) then return nil end

        local path = ix.documents.GetFilePath(documentID)
        if not path then return nil end

        if not file.Exists(path, "DATA") then return nil end

        local content = file.Read(path, "DATA")
        if not content then return nil end

        return util.JSONToTable(content)
    end

    -- Delete document file
    -- @param documentID string The document's unique ID
    -- @return boolean Success
    function ix.documents.Delete(documentID)
        if not ix.documents.ValidateID(documentID) then return false end

        local path = ix.documents.GetFilePath(documentID)
        if not path then return false end

        if file.Exists(path, "DATA") then
            file.Delete(path)
            return true
        end

        return false
    end

    -- Check if document exists
    -- @param documentID string The document's unique ID
    -- @return boolean Exists
    function ix.documents.Exists(documentID)
        if not ix.documents.ValidateID(documentID) then return false end

        local path = ix.documents.GetFilePath(documentID)
        if not path then return false end

        return file.Exists(path, "DATA")
    end
end

-- ============================================================================
-- SHARED UTILITY FUNCTIONS
-- ============================================================================

-- Count words in text
-- @param text string The text to count words in
-- @return number Word count
function ix.documents.CountWords(text)
    if not text or text == "" then return 0 end

    local count = 0
    for _ in text:gmatch("%S+") do
        count = count + 1
    end

    return count
end

-- Check if content type is erasable (pencil only)
-- @param contentType string "handwritten", "pencil", or "typed"
-- @return boolean Erasable
function ix.documents.IsErasable(contentType)
    return contentType == "pencil"
end

-- Format document type for display
-- @param docType string The document type
-- @return string Formatted name
function ix.documents.FormatType(docType)
    local types = {
        handwritten = "Handwritten",
        pencil = "Pencil",
        typed = "Typed"
    }
    return types[docType] or "Unknown"
end
