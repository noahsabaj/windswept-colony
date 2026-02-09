--[[
    Photo System Library

    Shared utilities and base VGUI panel for the photo and photo album systems.
    Provides: ownership verification, file I/O, material loading, and a base
    fullscreen photo viewer panel that both ixPhotoViewer and ixPhotoAlbumViewer
    inherit from.
]]--

ix.photo = ix.photo or {}

-- ============================================================================
-- SERVER UTILITIES
-- ============================================================================

if SERVER then
    --- Verify that a client owns an item in their inventory.
    -- Replaces the repeated character→inventory→find item pattern.
    -- @param client Player to check
    -- @param itemID Numeric item ID
    -- @param expectedUniqueID Optional uniqueID to validate (e.g., "photo")
    -- @return item if found and valid, nil otherwise
    function ix.photo.VerifyOwnership(client, itemID, expectedUniqueID)
        local item = ix.item.instances[itemID]
        if not item then return nil end

        if expectedUniqueID and item.uniqueID ~= expectedUniqueID then
            return nil
        end

        local character, inventory = ix.constants.GetCharacterInventory(client)
        if not character or not inventory then return nil end

        for _, invItem in pairs(inventory:GetItems()) do
            if invItem:GetID() == itemID then
                return item
            end
        end

        return nil
    end

    --- Read a photo file by ID with path traversal protection.
    -- @param photoID The photo identifier (format: "timestamp_random")
    -- @return imageData Raw binary JPEG data if found, nil otherwise
    function ix.photo.ReadPhotoFile(photoID)
        if not photoID or photoID == "" then return nil end

        -- Validate format to prevent path traversal
        if not photoID:match("^%d+_%d+$") then return nil end

        return file.Read("ix_photos/" .. photoID .. ".dat", "DATA")
    end

    --- Delete a photo file by ID.
    -- @param photoID The photo identifier
    function ix.photo.DeletePhotoFile(photoID)
        if not photoID or photoID == "" then return end
        if not photoID:match("^%d+_%d+$") then return end

        file.Delete("ix_photos/" .. photoID .. ".dat")
    end
end

-- ============================================================================
-- CLIENT UTILITIES
-- ============================================================================

if CLIENT then
    --- Create a Material from raw JPEG binary data.
    -- Writes to a unique temp file to avoid Material() cache returning stale textures.
    -- @param imageData Raw JPEG binary string
    -- @param identifier Unique string for temp file naming
    -- @return material IMaterial or nil
    -- @return tempPath String path to temp file (for cleanup), or nil
    function ix.photo.LoadMaterial(imageData, identifier)
        if not imageData or #imageData == 0 then return nil, nil end

        local tempPath = "ixphoto_" .. (identifier or SysTime()) .. ".jpg"
        file.Write(tempPath, imageData)

        return Material("../data/" .. tempPath, "smooth"), tempPath
    end

    --- Delete a temp photo file.
    -- @param path Data-relative path to delete
    function ix.photo.CleanupTempFile(path)
        if path and file.Exists(path, "DATA") then
            file.Delete(path)
        end
    end
end

-- ============================================================================
-- CLIENT: Base Photo Viewer Panel
-- ============================================================================

if CLIENT then
    local PANEL = {}

    function PANEL:Init()
        self:SetSize(ScrW(), ScrH())
        self:SetPos(0, 0)
        self:MakePopup()
        self:SetKeyboardInputEnabled(true)

        self.closeKeys = {KEY_W, KEY_A, KEY_S, KEY_D}
    end

    -- Override these in child panels
    function PANEL:GetPhotoMat() return nil end
    function PANEL:GetPhotoTitle() return "Untitled Photograph" end
    function PANEL:IsPhotoLoading() return false end
    function PANEL:GetEmptyText() return "No Image" end
    function PANEL:GetCloseText() return "Press LMB or WASD to close" end
    function PANEL:DrawExtraContent(w, h, imgSize, imgX, imgY) end
    function PANEL:OnExtraKeyPress(key) return false end
    function PANEL:OnCleanup() end

    function PANEL:Paint(w, h)
        -- Dark background
        surface.SetDrawColor(0, 0, 0, 240)
        surface.DrawRect(0, 0, w, h)

        -- Scale photo to 65% of screen height
        local imgSize = math.floor(h * 0.65)
        local imgX = (w - imgSize) / 2
        local imgY = (h - imgSize) / 2 - 30

        -- White border
        surface.SetDrawColor(255, 255, 255)
        surface.DrawOutlinedRect(imgX - 4, imgY - 4, imgSize + 8, imgSize + 8, 2)

        -- Draw photo, loading state, or empty state
        local mat = self:GetPhotoMat()

        if mat and not mat:IsError() then
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255)
            surface.DrawTexturedRect(imgX, imgY, imgSize, imgSize)
        else
            surface.SetDrawColor(40, 40, 40)
            surface.DrawRect(imgX, imgY, imgSize, imgSize)

            if self:IsPhotoLoading() then
                draw.SimpleText("Loading...", "ixMediumFont", w / 2, imgY + imgSize / 2, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                draw.SimpleText(self:GetEmptyText(), "ixMediumFont", w / 2, imgY + imgSize / 2, Color(100, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- Title below image
        draw.SimpleText(self:GetPhotoTitle(), "ixMediumFont", w / 2, imgY + imgSize + 30, Color(255, 255, 255), TEXT_ALIGN_CENTER)

        -- Let child panels draw extra content (navigation arrows, counters, etc.)
        self:DrawExtraContent(w, h, imgSize, imgX, imgY)

        -- Close instructions
        draw.SimpleText(self:GetCloseText(), "ixSmallFont", w / 2, h - 40, Color(100, 100, 100), TEXT_ALIGN_CENTER)
    end

    function PANEL:OnKeyCodePressed(key)
        -- Let child handle first (e.g., arrow navigation)
        if self:OnExtraKeyPress(key) then return end

        for _, closeKey in ipairs(self.closeKeys) do
            if key == closeKey then
                self:Remove()
                return
            end
        end
    end

    function PANEL:OnMousePressed(mouseCode)
        if mouseCode == MOUSE_LEFT then
            self:Remove()
        end
    end

    function PANEL:OnRemove()
        self:OnCleanup()
    end

    vgui.Register("ixPhotoViewerBase", PANEL, "DPanel")
end
