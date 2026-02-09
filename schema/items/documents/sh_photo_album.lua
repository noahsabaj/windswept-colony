--[[
    Photo Album

    A container that holds up to 50 photographs.
    Only photo items can be stored in this album.
    Features a book-style viewer (two photos per spread).
    Can be renamed multiple times.
]]--

ITEM.name = "Photo Album"
ITEM.description = "A binder for storing and organizing photographs."
ITEM.model = "models/props_lab/binderblue.mdl"
ITEM.category = "Storage"
ITEM.base = "base_container"
ITEM.width = 1
ITEM.height = 1
ITEM.invWidth = 10
ITEM.invHeight = 5

ITEM.inventoryFlag = "isPhotoAlbum"
ITEM.allowedItemType = "photo"
ITEM.allowedItemNotify = "albumOnlyPhotos"
ITEM.viewSuffix = " - Photos"

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

function ITEM:GetAlbumTitle()
    return self:GetData("title", "")
end

function ITEM:HasTitle()
    local title = self:GetAlbumTitle()
    return title and title ~= ""
end

function ITEM:GetName()
    if self:HasTitle() then
        return self:GetAlbumTitle()
    end
    return self.name
end

function ITEM:GetPhotos()
    local inv = self:GetInventory()
    if not inv then return {} end

    local photos = inv:GetItemsByUniqueID("photo", false)

    table.sort(photos, function(a, b)
        return (a:GetData("timestamp") or 0) < (b:GetData("timestamp") or 0)
    end)

    return photos
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Browse album in book-style viewer
ITEM.functions.Browse = {
    name = "Browse",
    tip = "Flip through the photographs in this album.",
    icon = "icon16/book_open.png",
    OnRun = function(item)
        return false
    end,
    OnClick = function(item)
        net.Start("ixPhotoAlbumView")
            net.WriteUInt(item:GetID(), 32)
        net.SendToServer()

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("id") ~= nil
    end
}

-- Override View with custom name
ITEM.functions.View = {
    name = "Manage Photos",
    tip = "Add or remove photographs from the album.",
    icon = "icon16/folder.png",
    OnClick = ix.constants.OpenContainerPanel,
    OnCanRun = ix.constants.CanOpenContainerPanel
}

-- Rename album (can rename multiple times)
ITEM.functions.Rename = {
    name = "Rename Album",
    tip = "Change the name of this album.",
    icon = "icon16/pencil.png",
    OnRun = function(item, data)
        return false
    end,
    OnClick = function(item)
        local currentTitle = item:GetAlbumTitle()

        Derma_StringRequest(
            "Rename Album",
            "Enter a name for this album (max 64 characters):",
            currentTitle,
            function(text)
                if text then
                    net.Start("ixPhotoAlbumRename")
                        net.WriteUInt(item:GetID(), 32)
                        net.WriteString(string.sub(text, 1, 64))
                    net.SendToServer()
                end
            end,
            function() end,
            "Confirm",
            "Cancel"
        )
        return false
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity)
    end
}

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOverExtra(w, h)
        local photos = self:GetPhotos()
        local count = #photos

        if count > 0 then
            local text = tostring(count)
            surface.SetFont("ixSmallFont")
            local textW, textH = surface.GetTextSize(text)

            surface.SetDrawColor(50, 100, 150, 200)
            surface.DrawRect(w - textW - 8, 2, textW + 6, textH + 2)

            surface.SetTextColor(255, 255, 255)
            surface.SetTextPos(w - textW - 5, 3)
            surface.DrawText(text)
        end
    end

    function ITEM:PopulateTooltip(tooltip)
        local photos = self:GetPhotos()

        local photoRow = tooltip:AddRow("photos")
        photoRow:SetText(string.format("Photos: %d / 50", #photos))

        if #photos >= 45 then
            photoRow:SetBackgroundColor(Color(150, 100, 50))
        elseif #photos > 0 then
            photoRow:SetBackgroundColor(Color(50, 100, 100))
        else
            photoRow:SetBackgroundColor(Color(100, 100, 100))
        end

        photoRow:SizeToContents()
    end
end

-- ============================================================================
-- SERVER: Networking
-- ============================================================================

if SERVER then
    net.Receive("ixPhotoAlbumRename", function(len, client)
        local itemID = net.ReadUInt(32)
        local title = net.ReadString()

        local item = ix.photo.VerifyOwnership(client, itemID, "photo_album")
        if not item then return end

        title = string.sub(title, 1, 64)
        item:SetData("title", title)

        client:NotifyLocalized("albumRenamed", title)
    end)

    net.Receive("ixPhotoAlbumView", function(len, client)
        local itemID = net.ReadUInt(32)

        local item = ix.photo.VerifyOwnership(client, itemID, "photo_album")
        if not item then return end

        local photos = item:GetPhotos()
        local title = item:GetName()

        net.Start("ixPhotoAlbumViewData")
            net.WriteString(title)
            net.WriteUInt(#photos, 8)
            for _, photo in ipairs(photos) do
                net.WriteString(photo:GetData("photoID", ""))
                net.WriteString(photo:GetData("title", ""))
            end
        net.Send(client)
    end)
end

-- ============================================================================
-- CLIENT: Album Viewer (inherits ixPhotoViewerBase)
-- ============================================================================

if CLIENT then
    ix.albumPhotoCache = ix.albumPhotoCache or {}
    ix.albumPhotoLoading = ix.albumPhotoLoading or {}

    local PANEL = {}

    function PANEL:Init()
        self.BaseClass.Init(self)

        self.albumTitle = "Photo Album"
        self.photoMetadata = {}
        self.currentIndex = 1
        self.totalPhotos = 0
    end

    function PANEL:SetAlbumMetadata(title, metadata)
        self.albumTitle = title or "Photo Album"
        self.photoMetadata = metadata or {}
        self.totalPhotos = #self.photoMetadata
        self.currentIndex = 1

        self:RequestCurrentPhoto()
    end

    function PANEL:RequestCurrentPhoto()
        local metadata = self.photoMetadata[self.currentIndex]
        if metadata and metadata.photoID and metadata.photoID ~= "" then
            self:RequestPhoto(metadata.photoID)
        end
    end

    function PANEL:RequestPhoto(photoID)
        if ix.albumPhotoCache[photoID] then return end
        if ix.albumPhotoLoading[photoID] then return end

        ix.albumPhotoLoading[photoID] = true

        net.Start("ixPhotoRequest")
            net.WriteString(photoID)
        net.SendToServer()
    end

    function PANEL:GoToPhoto(index)
        if index < 1 or index > self.totalPhotos then return end

        self.currentIndex = index
        self:RequestCurrentPhoto()
    end

    function PANEL:GetPhotoMat()
        local metadata = self.photoMetadata[self.currentIndex]
        if not metadata or not metadata.photoID or metadata.photoID == "" then
            return nil
        end

        local cached = ix.albumPhotoCache[metadata.photoID]
        if cached and cached ~= false and not cached:IsError() then
            return cached
        end

        return nil
    end

    function PANEL:GetPhotoTitle()
        local metadata = self.photoMetadata[self.currentIndex]
        if metadata then
            local title = metadata.title or ""
            if title == "" then title = "Untitled" end
            return title
        end
        return ""
    end

    function PANEL:IsPhotoLoading()
        local metadata = self.photoMetadata[self.currentIndex]
        if metadata and metadata.photoID then
            return ix.albumPhotoLoading[metadata.photoID] == true
        end
        return false
    end

    function PANEL:GetEmptyText()
        if self.totalPhotos == 0 then
            return "Album Empty"
        end
        return "No Image"
    end

    function PANEL:GetCloseText()
        return "Arrow keys to navigate | WASD or LMB to close"
    end

    function PANEL:DrawExtraContent(w, h, imgSize, imgX, imgY)
        draw.SimpleText(self.albumTitle, "ixMediumFont", w / 2, 30, ix.constants.COLOR_UI_NEUTRAL, TEXT_ALIGN_CENTER)

        local arrowY = h / 2
        local arrowColor = Color(255, 255, 255, 150)
        local arrowDisabledColor = Color(100, 100, 100, 80)

        local leftColor = self.currentIndex > 1 and arrowColor or arrowDisabledColor
        draw.SimpleText("\xE2\x97\x84", "ixMediumFont", imgX - 60, arrowY, leftColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local rightColor = self.currentIndex < self.totalPhotos and arrowColor or arrowDisabledColor
        draw.SimpleText("\xE2\x96\xBA", "ixMediumFont", imgX + imgSize + 60, arrowY, rightColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if self.totalPhotos > 0 then
            draw.SimpleText(string.format("Photo %d of %d", self.currentIndex, self.totalPhotos), "ixSmallFont", w / 2, imgY + imgSize + 60, Color(150, 150, 150), TEXT_ALIGN_CENTER)
        end
    end

    function PANEL:OnExtraKeyPress(key)
        if key == KEY_LEFT then
            self:GoToPhoto(self.currentIndex - 1)
            return true
        elseif key == KEY_RIGHT then
            self:GoToPhoto(self.currentIndex + 1)
            return true
        end
        return false
    end

    function PANEL:OnCleanup()
        for photoID, _ in pairs(ix.albumPhotoCache) do
            ix.photo.CleanupTempFile("ixphoto_album_" .. photoID .. ".jpg")
        end

        ix.albumPhotoCache = {}
        ix.albumPhotoLoading = {}
        ix.gui.photoAlbumViewer = nil
    end

    vgui.Register("ixPhotoAlbumViewer", PANEL, "ixPhotoViewerBase")

    -- Receive album metadata from server
    net.Receive("ixPhotoAlbumViewData", function()
        local title = net.ReadString()
        local photoCount = net.ReadUInt(8)

        local metadata = {}
        for i = 1, photoCount do
            local photoID = net.ReadString()
            local photoTitle = net.ReadString()
            table.insert(metadata, {
                photoID = photoID,
                title = photoTitle
            })
        end

        if IsValid(ix.gui.photoAlbumViewer) then
            ix.gui.photoAlbumViewer:Remove()
        end

        ix.gui.photoAlbumViewer = vgui.Create("ixPhotoAlbumViewer")
        ix.gui.photoAlbumViewer:SetAlbumMetadata(title, metadata)
    end)

    -- Hook into existing ixPhotoData to update album cache
    hook.Add("ixPhotoDataReceived", "ixPhotoAlbumCache", function(photoID, imageData)
        ix.albumPhotoLoading[photoID] = nil

        if imageData and imageData ~= "" then
            local mat, tempPath = ix.photo.LoadMaterial(imageData, "album_" .. photoID)
            if mat then
                ix.albumPhotoCache[photoID] = mat
            else
                ix.albumPhotoCache[photoID] = false
            end
        else
            ix.albumPhotoCache[photoID] = false
        end
    end)
end

-- ============================================================================
-- ENTITY USE (View from ground)
-- ============================================================================

if SERVER then
    hook.Add("PlayerUse", "ixPhotoAlbumGroundView", function(client, entity)
        if not IsValid(entity) then return end

        local item = entity.ixItem
        if not item then return end
        if item.uniqueID ~= "photo_album" then return end

        local photos = item:GetPhotos()
        local title = item:GetName()

        net.Start("ixPhotoAlbumViewFromGround")
            net.WriteString(title)
            net.WriteUInt(#photos, 8)
            for _, photo in ipairs(photos) do
                net.WriteString(photo:GetData("photoID", ""))
                net.WriteString(photo:GetData("title", ""))
            end
        net.Send(client)
    end)
end

if CLIENT then
    net.Receive("ixPhotoAlbumViewFromGround", function()
        local title = net.ReadString()
        local photoCount = net.ReadUInt(8)

        local metadata = {}
        for i = 1, photoCount do
            local photoID = net.ReadString()
            local photoTitle = net.ReadString()
            table.insert(metadata, {
                photoID = photoID,
                title = photoTitle
            })
        end

        if IsValid(ix.gui.photoAlbumViewer) then
            ix.gui.photoAlbumViewer:Remove()
        end

        ix.gui.photoAlbumViewer = vgui.Create("ixPhotoAlbumViewer")
        ix.gui.photoAlbumViewer:SetAlbumMetadata(title, metadata)
    end)
end
