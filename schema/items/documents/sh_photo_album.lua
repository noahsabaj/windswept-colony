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
ITEM.width = 1
ITEM.height = 1
ITEM.invWidth = 10
ITEM.invHeight = 5  -- 50 slots total
ITEM.isBag = true

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

-- Override GetName to show custom title
function ITEM:GetName()
    if self:HasTitle() then
        return self:GetAlbumTitle()
    end
    return self.name
end

function ITEM:GetPhotos()
    local inv = self:GetInventory()
    if not inv then return {} end

    local photos = {}
    for _, item in pairs(inv:GetItems()) do
        if item.uniqueID == "photo" then
            table.insert(photos, item)
        end
    end

    -- Sort by timestamp
    table.sort(photos, function(a, b)
        return (a:GetData("timestamp") or 0) < (b:GetData("timestamp") or 0)
    end)

    return photos
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

-- Browse album in book-style viewer (NOT named "View" to prevent Helix auto-open for bags)
ITEM.functions.Browse = {
    name = "Browse",
    tip = "Flip through the photographs in this album.",
    icon = "icon16/book_open.png",
    OnRun = function(item)
        return false
    end,
    OnClick = function(item)
        -- Request album photos from server (photos use file-based storage now)
        net.Start("ixPhotoAlbumView")
            net.WriteUInt(item:GetID(), 32)
        net.SendToServer()

        return false
    end,
    OnCanRun = function(item)
        return item:GetData("id") ~= nil
    end
}

-- View function for Helix auto-bag-open (opens standard inventory panel)
-- This is what Helix calls automatically when "openBags" option is enabled
ITEM.functions.View = {
    name = "Manage Photos",
    tip = "Add or remove photographs from the album.",
    icon = "icon16/folder.png",
    OnClick = function(item)
        local index = item:GetData("id", "")

        if index then
            local panel = ix.gui["inv"..index]
            local inventory = ix.item.inventories[index]
            local parent = IsValid(ix.gui.menuInventoryContainer) and ix.gui.menuInventoryContainer or ix.gui.openedStorage

            if IsValid(panel) then
                panel:Remove()
            end

            if inventory and inventory.slots then
                panel = vgui.Create("ixInventory", IsValid(parent) and parent or nil)
                panel:SetInventory(inventory)
                panel:ShowCloseButton(true)
                panel:SetTitle(item:GetName() .. " - Photos")

                if parent ~= ix.gui.menuInventoryContainer then
                    panel:Center()
                    if parent == ix.gui.openedStorage then
                        panel:MakePopup()
                    end
                else
                    panel:MoveToFront()
                end

                ix.gui["inv"..index] = panel
            end
        end

        return false
    end,
    OnCanRun = function(item)
        return not IsValid(item.entity) and item:GetData("id") and not IsValid(ix.gui["inv" .. item:GetData("id", "")])
    end
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

-- Combine (drag items into bag)
ITEM.functions.combine = {
    OnRun = function(item, data)
        local targetItem = ix.item.instances[data[1]]
        if not targetItem then return false end

        -- Only allow photos
        if targetItem.uniqueID ~= "photo" then
            if item.player then
                item.player:NotifyLocalized("albumOnlyPhotos")
            end
            return false
        end

        targetItem:Transfer(item:GetData("id"), nil, nil, item.player)
        return false
    end,
    OnCanRun = function(item, data)
        local index = item:GetData("id", "")
        if index then
            local inventory = ix.item.inventories[index]
            if inventory then
                return true
            end
        end
        return false
    end
}

-- ============================================================================
-- BAG SYSTEM (copied from base with modifications)
-- ============================================================================

function ITEM:OnInstanced(invID, x, y)
    local inventory = ix.item.inventories[invID]

    ix.inventory.New(inventory and inventory.owner or 0, self.uniqueID, function(inv)
        local client = inv:GetOwner()

        inv.vars.isBag = self.uniqueID
        inv.vars.isPhotoAlbum = true  -- Custom flag for photo restriction
        self:SetData("id", inv:GetID())

        if IsValid(client) then
            inv:AddReceiver(client)
        end
    end)
end

function ITEM:GetInventory()
    local index = self:GetData("id")
    if index then
        return ix.item.inventories[index]
    end
end

ITEM.GetInv = ITEM.GetInventory

function ITEM:OnSendData()
    local index = self:GetData("id")

    if index then
        local inventory = ix.item.inventories[index]

        if inventory then
            inventory.vars.isBag = self.uniqueID
            inventory.vars.isPhotoAlbum = true
            inventory:Sync(self.player)
            inventory:AddReceiver(self.player)
        else
            local owner = self.player:GetCharacter():GetID()

            ix.inventory.Restore(self:GetData("id"), self.invWidth, self.invHeight, function(inv)
                inv.vars.isBag = self.uniqueID
                inv.vars.isPhotoAlbum = true
                inv:SetOwner(owner, true)

                if not inv.owner then
                    return
                end

                for client, character in ix.util.GetCharacters() do
                    if character:GetID() == inv.owner then
                        inv:AddReceiver(client)
                        break
                    end
                end
            end)
        end
    else
        ix.inventory.New(self.player:GetCharacter():GetID(), self.uniqueID, function(inv)
            inv.vars.isPhotoAlbum = true
            self:SetData("id", inv:GetID())
        end)
    end
end

function ITEM.postHooks.drop(item, result)
    local index = item:GetData("id")

    local query = mysql:Update("ix_inventories")
        query:Update("character_id", 0)
        query:Where("inventory_id", index)
    query:Execute()

    if SERVER then
        net.Start("ixBagDrop")
            net.WriteUInt(index, 32)
        net.Send(item.player)
    end
end

function ITEM:OnRemoved()
    local index = self:GetData("id")

    if index then
        local query = mysql:Delete("ix_items")
            query:Where("inventory_id", index)
        query:Execute()

        query = mysql:Delete("ix_inventories")
            query:Where("inventory_id", index)
        query:Execute()
    end
end

function ITEM:CanTransfer(oldInventory, newInventory)
    local index = self:GetData("id")

    if newInventory then
        -- Bags can't go into other bags
        if newInventory.vars and newInventory.vars.isBag then
            return false
        end

        local index2 = newInventory:GetID()

        if index == index2 then
            return false
        end

        -- Check for circular references
        local bagInv = self:GetInventory()
        if bagInv then
            for k, _ in bagInv:Iter() do
                if k:GetData("id") == index2 then
                    return false
                end
            end
        end
    end

    return not newInventory or newInventory:GetID() ~= oldInventory:GetID() or newInventory.vars.isBag
end

function ITEM:OnTransferred(curInv, inventory)
    local bagInventory = self:GetInventory()
    if not bagInventory then return end

    if isfunction(curInv.GetOwner) then
        local owner = curInv:GetOwner()
        if IsValid(owner) then
            bagInventory:RemoveReceiver(owner)
        end
    end

    if isfunction(inventory.GetOwner) then
        local owner = inventory:GetOwner()
        if IsValid(owner) then
            bagInventory:AddReceiver(owner)
            bagInventory:SetOwner(owner)
        end
    else
        bagInventory:SetOwner(nil)
    end
end

function ITEM:OnRegistered()
    ix.inventory.Register(self.uniqueID, self.invWidth, self.invHeight, true)
end

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
    function ITEM:PaintOver(item, w, h)
        local panel = ix.gui["inv" .. item:GetData("id", "")]

        if IsValid(panel) and vgui.GetHoveredPanel() == self then
            panel:SetHighlighted(true)
        elseif IsValid(panel) then
            panel:SetHighlighted(false)
        end

        -- Show photo count
        local photos = item:GetPhotos()
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

        local item = ix.item.instances[itemID]
        if not item then return end
        if item.uniqueID ~= "photo_album" then return end

        -- Verify ownership
        local character = client:GetCharacter()
        if not character then return end

        local inventory = character:GetInventory()
        if not inventory then return end

        local found = false
        for _, invItem in pairs(inventory:GetItems()) do
            if invItem:GetID() == itemID then
                found = true
                break
            end
        end

        if not found then return end

        -- Set the title
        title = string.sub(title, 1, 64)
        item:SetData("title", title)

        client:NotifyLocalized("albumRenamed", title)
    end)

    -- Handle album view request - sends ONLY metadata (photoID + title), not image data
    -- This avoids net message overflow. Client requests pages on-demand.
    net.Receive("ixPhotoAlbumView", function(len, client)
        local itemID = net.ReadUInt(32)

        local item = ix.item.instances[itemID]
        if not item then return end
        if item.uniqueID ~= "photo_album" then return end

        -- Verify ownership
        local character = client:GetCharacter()
        if not character then return end

        local inventory = character:GetInventory()
        if not inventory then return end

        local found = false
        for _, invItem in pairs(inventory:GetItems()) do
            if invItem:GetID() == itemID then
                found = true
                break
            end
        end

        if not found then return end

        -- Get photos from album
        local photos = item:GetPhotos()
        local title = item:GetName()

        -- Send ONLY metadata (photoID + title) - NO image data!
        -- Each entry is ~100 bytes max, so 50 photos = ~5KB (safe)
        net.Start("ixPhotoAlbumViewData")
            net.WriteUInt(itemID, 32)  -- Include itemID for page requests
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
-- CLIENT: Album Viewer (Single Photo Per Page)
-- ============================================================================

if CLIENT then
    -- Global cache for album photo materials (keyed by photoID)
    -- This persists across viewer instances to avoid re-fetching
    ix.albumPhotoCache = ix.albumPhotoCache or {}
    ix.albumPhotoLoading = ix.albumPhotoLoading or {}

    local PANEL = {}

    function PANEL:Init()
        self:SetSize(ScrW(), ScrH())
        self:SetPos(0, 0)
        self:MakePopup()
        self:SetKeyboardInputEnabled(true)

        self.closeKeys = {KEY_W, KEY_A, KEY_S, KEY_D}
        self.albumTitle = "Photo Album"
        self.photoMetadata = {}  -- {photoID, title} for each photo
        self.currentIndex = 1
        self.totalPhotos = 0
    end

    -- Set album metadata (no image data yet - just photoIDs and titles)
    function PANEL:SetAlbumMetadata(title, metadata)
        self.albumTitle = title or "Photo Album"
        self.photoMetadata = metadata or {}
        self.totalPhotos = #self.photoMetadata
        self.currentIndex = 1

        -- Request first photo
        self:RequestCurrentPhoto()
    end

    -- Request the current photo
    function PANEL:RequestCurrentPhoto()
        local metadata = self.photoMetadata[self.currentIndex]
        if metadata and metadata.photoID and metadata.photoID ~= "" then
            self:RequestPhoto(metadata.photoID)
        end
    end

    -- Request a single photo by photoID (reuses existing ixPhotoRequest system)
    function PANEL:RequestPhoto(photoID)
        -- Already cached?
        if ix.albumPhotoCache[photoID] then return end
        -- Already loading?
        if ix.albumPhotoLoading[photoID] then return end

        ix.albumPhotoLoading[photoID] = true

        -- Use the existing photo request system from sh_photo.lua
        -- This sends ONE photo per message, guaranteed to fit under 64KB
        net.Start("ixPhotoRequest")
            net.WriteString(photoID)
        net.SendToServer()
    end

    -- Get cached material for a photoID
    function PANEL:GetPhotoMaterial(photoID)
        local cached = ix.albumPhotoCache[photoID]
        if cached and cached ~= false and not cached:IsError() then
            return cached
        end
        return nil
    end

    -- Check if a photo is currently loading
    function PANEL:IsPhotoLoading(photoID)
        return ix.albumPhotoLoading[photoID] == true
    end

    -- Navigate to a photo
    function PANEL:GoToPhoto(index)
        if index < 1 or index > self.totalPhotos then return end

        self.currentIndex = index
        self:RequestCurrentPhoto()
    end

    function PANEL:Paint(w, h)
        -- Dark background (same style as individual photo viewer)
        surface.SetDrawColor(0, 0, 0, 240)
        surface.DrawRect(0, 0, w, h)

        -- Album title at top
        draw.SimpleText(self.albumTitle, "ixMediumFont", w / 2, 30, ix.constants.COLOR_UI_NEUTRAL, TEXT_ALIGN_CENTER)

        -- Image size (same as individual photo viewer: 512x512)
        local imgSize = 512
        local x = (w - imgSize) / 2
        local y = (h - imgSize) / 2 - 40

        -- Get current photo metadata
        local metadata = self.photoMetadata[self.currentIndex]

        if metadata and metadata.photoID and metadata.photoID ~= "" then
            local photoID = metadata.photoID

            -- White border
            surface.SetDrawColor(255, 255, 255)
            surface.DrawOutlinedRect(x - 4, y - 4, imgSize + 8, imgSize + 8, 2)

            -- Draw photo or loading state
            local mat = self:GetPhotoMaterial(photoID)
            if mat then
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255)
                surface.DrawTexturedRect(x, y, imgSize, imgSize)
            else
                -- Loading or no image
                surface.SetDrawColor(40, 40, 40)
                surface.DrawRect(x, y, imgSize, imgSize)

                if self:IsPhotoLoading(photoID) then
                    draw.SimpleText("Loading...", "ixMediumFont", w / 2, h / 2 - 40, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                elseif ix.albumPhotoCache[photoID] == false then
                    draw.SimpleText("No Image", "ixMediumFont", w / 2, h / 2 - 40, Color(100, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText("Loading...", "ixMediumFont", w / 2, h / 2 - 40, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            -- Photo title below image
            local photoTitle = metadata.title or ""
            if photoTitle == "" then photoTitle = "Untitled" end
            draw.SimpleText(photoTitle, "ixMediumFont", w / 2, y + imgSize + 30, Color(255, 255, 255), TEXT_ALIGN_CENTER)
        else
            -- Empty album
            surface.SetDrawColor(255, 255, 255)
            surface.DrawOutlinedRect(x - 4, y - 4, imgSize + 8, imgSize + 8, 2)
            surface.SetDrawColor(40, 40, 40)
            surface.DrawRect(x, y, imgSize, imgSize)
            draw.SimpleText("Album Empty", "ixMediumFont", w / 2, h / 2 - 40, Color(100, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Navigation arrows (drawn on sides)
        local arrowY = h / 2
        local arrowColor = Color(255, 255, 255, 150)
        local arrowDisabledColor = Color(100, 100, 100, 80)

        -- Left arrow
        if self.currentIndex > 1 then
            draw.SimpleText("◄", "ixMediumFont", x - 60, arrowY, arrowColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("◄", "ixMediumFont", x - 60, arrowY, arrowDisabledColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Right arrow
        if self.currentIndex < self.totalPhotos then
            draw.SimpleText("►", "ixMediumFont", x + imgSize + 60, arrowY, arrowColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("►", "ixMediumFont", x + imgSize + 60, arrowY, arrowDisabledColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Photo counter
        if self.totalPhotos > 0 then
            draw.SimpleText(string.format("Photo %d of %d", self.currentIndex, self.totalPhotos), "ixSmallFont", w / 2, y + imgSize + 60, Color(150, 150, 150), TEXT_ALIGN_CENTER)
        end

        -- Instructions at bottom
        draw.SimpleText("← → Arrow keys to navigate | WASD or LMB to close", "ixSmallFont", w / 2, h - 40, Color(100, 100, 100), TEXT_ALIGN_CENTER)
    end

    function PANEL:OnKeyCodePressed(key)
        if key == KEY_LEFT then
            self:GoToPhoto(self.currentIndex - 1)
            return
        elseif key == KEY_RIGHT then
            self:GoToPhoto(self.currentIndex + 1)
            return
        end

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
        ix.gui.photoAlbumViewer = nil
    end

    vgui.Register("ixPhotoAlbumViewer", PANEL, "DPanel")

    -- Receive album METADATA from server (photoIDs + titles only, no images)
    net.Receive("ixPhotoAlbumViewData", function()
        local _ = net.ReadUInt(32)  -- itemID (unused now, kept for backwards compat)
        local title = net.ReadString()
        local photoCount = net.ReadUInt(8)

        -- Read metadata for all photos (small data, no overflow risk)
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
    -- This receives ONE photo at a time (guaranteed under 64KB)
    hook.Add("ixPhotoDataReceived", "ixPhotoAlbumCache", function(photoID, imageData)
        -- Update global album photo cache
        ix.albumPhotoLoading[photoID] = nil

        if imageData and imageData ~= "" then
            local decoded = util.Base64Decode(imageData)
            if decoded then
                local tempPath = "ixphoto_album_" .. photoID .. ".jpg"
                file.Write(tempPath, decoded)
                ix.albumPhotoCache[photoID] = Material("../data/" .. tempPath, "smooth")
            else
                ix.albumPhotoCache[photoID] = false
            end
        else
            ix.albumPhotoCache[photoID] = false
        end
    end)
end

-- ============================================================================
-- PHOTO RESTRICTION HOOK
-- ============================================================================

-- This hook restricts what items can be placed in photo albums
hook.Add("CanTransferItem", "ixPhotoAlbumRestriction", function(item, curInv, inventory)
    -- Check if target inventory is a photo album
    if inventory and inventory.vars and inventory.vars.isPhotoAlbum then
        -- Only allow photo items
        if item.uniqueID ~= "photo" then
            return false
        end
    end
end)

-- ============================================================================
-- ENTITY USE (View from ground)
-- ============================================================================

if SERVER then
    hook.Add("PlayerUse", "ixPhotoAlbumGroundView", function(client, entity)
        if not IsValid(entity) then return end

        local item = entity.ixItem
        if not item then return end
        if item.uniqueID ~= "photo_album" then return end

        -- Send ONLY metadata (no image data) to avoid overflow
        -- Client will request individual photos via ixPhotoRequest
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

        -- Read metadata only
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

        -- Create viewer and request visible photos via ixPhotoRequest
        ix.gui.photoAlbumViewer = vgui.Create("ixPhotoAlbumViewer")
        ix.gui.photoAlbumViewer:SetAlbumMetadata(title, metadata)
    end)
end
