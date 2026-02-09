--[[
    Camera SWEP

    Controls:
    - RMB (Hold): Enter viewfinder mode
    - LMB: Take photo (only while aiming)
    - Middle Mouse: Toggle flash ON/OFF
    - Scroll Wheel: Zoom in/out

    Requirements per photo:
    - Battery: 2up
    - Film: 1 shot
]]--

AddCSLuaFile()

SWEP.PrintName = "Camera"
SWEP.Author = "Windswept"
SWEP.Purpose = "Capture photographs."
SWEP.Instructions = "RMB: Aim | LMB: Photo | Middle Mouse: Flash | Scroll: Zoom"

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModelFOV = 50
SWEP.ViewModel = Model("models/weapons/infra/c_camera.mdl")
SWEP.WorldModel = Model("models/weapons/infra/w_camera.mdl")
SWEP.UseHands = true
SWEP.HoldType = "camera"

-- INFRA Camera models: https://steamcommunity.com/sharedfiles/filedetails/?id=3410154200
if SERVER then
    resource.AddWorkshop("3410154200")
end

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

-- Configuration
SWEP.MinFOV = 10      -- Maximum zoom (lowest FOV)
SWEP.MaxFOV = 90      -- Minimum zoom (highest FOV)
SWEP.DefaultFOV = 70
SWEP.ZoomSpeed = 5

SWEP.BatteryDrainPerPhoto = 2
SWEP.FlashDuration = 0.25

-- ============================================================================
-- DATA TABLES
-- ============================================================================

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Aiming")
    self:NetworkVar("Bool", 1, "FlashEnabled")
    self:NetworkVar("Float", 0, "CurrentFOV")

    self:SetAiming(false)
    self:SetFlashEnabled(false)
    self:SetCurrentFOV(self.DefaultFOV)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    self:SetAiming(false)
    self:SetCurrentFOV(self.DefaultFOV)
    return true
end

function SWEP:Holster()
    self:SetAiming(false)
    return true
end

-- ============================================================================
-- PRIMARY ATTACK - Take Photo
-- ============================================================================

function SWEP:PrimaryAttack()
    -- Photo capture is handled in Think() using input.IsMouseDown(MOUSE_LEFT)
    -- because Helix's weapon system doesn't call PrimaryAttack on CLIENT
    -- This stub prevents default weapon behavior
    if self:GetAiming() then
        self:SetNextPrimaryFire(CurTime() + 1)
    end
end

-- ============================================================================
-- SECONDARY ATTACK - Toggle Aiming
-- ============================================================================

function SWEP:SecondaryAttack()
    -- Handled in Think for hold behavior
end

-- ============================================================================
-- RELOAD - Not used (flash toggle is middle mouse)
-- ============================================================================

function SWEP:Reload()
    -- Intentionally empty - flash toggle moved to middle mouse
end

-- ============================================================================
-- THINK - Handle Aiming and Zoom
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- CRITICAL: Only handle input-based logic on CLIENT
    -- Server doesn't have input context (KeyDown returns false), which causes state flicker
    if CLIENT then
        -- Weapon must be raised to use camera features
        local isRaised = owner:IsWepRaised()

        -- Handle aiming (RMB hold) - only when weapon is raised
        local shouldAim = isRaised and owner:KeyDown(IN_ATTACK2)

        if shouldAim ~= self:GetAiming() then
            self:SetAiming(shouldAim)
            net.Start("ixCameraSetAiming")
                net.WriteBool(shouldAim)
            net.SendToServer()
        end

        -- Handle photo capture (LMB) - only when aiming
        -- NOTE: We handle this in Think() instead of PrimaryAttack because Helix's
        -- weapon system doesn't call PrimaryAttack on CLIENT (only SERVER)
        if self:GetAiming() then
            local lmbDown = input.IsMouseDown(MOUSE_LEFT)

            if lmbDown and not self.wasLMBDown then
                -- LMB just pressed while aiming
                if not self.nextPhotoTime or self.nextPhotoTime <= CurTime() then
                    self.nextPhotoTime = CurTime() + 1
                    net.Start("ixCameraRequestPhoto")
                    net.SendToServer()
                end
            end

            self.wasLMBDown = lmbDown
        else
            self.wasLMBDown = false
        end

        -- Handle flash toggle (middle mouse) - only when weapon is raised
        if isRaised then
            local middleMouseDown = input.IsMouseDown(MOUSE_MIDDLE)

            if middleMouseDown and not self.wasMiddleMouseDown then
                -- Middle mouse just pressed
                if not self.nextFlashToggle or self.nextFlashToggle <= CurTime() then
                    self.nextFlashToggle = CurTime() + 0.3
                    net.Start("ixCameraToggleFlash")
                    net.SendToServer()
                end
            end

            self.wasMiddleMouseDown = middleMouseDown
        else
            self.wasMiddleMouseDown = false
        end

        -- Suppress weapon select UI while aiming
        if self:GetAiming() then
            local wepselect = ix.plugin.Get("wepselect")
            if wepselect then
                wepselect.alpha = 0
                wepselect.alphaDelta = 0

                local weapons = owner:GetWeapons()
                for i, w in ipairs(weapons) do
                    if w == self then
                        wepselect.index = i
                        wepselect.deltaIndex = i
                        break
                    end
                end
            end
        end
    end
end

-- Handle zoom through global CreateMove hook (SWEP:CreateMove doesn't exist in GMod)
if CLIENT then
    hook.Add("CreateMove", "ixCameraZoom", function(cmd)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_camera" then return end

        local wheel = cmd:GetMouseWheel()
        if wheel == 0 then return end
        if not weapon:GetAiming() then return end

        local newFOV = weapon:GetCurrentFOV() - (wheel * weapon.ZoomSpeed)
        newFOV = math.Clamp(newFOV, weapon.MinFOV, weapon.MaxFOV)

        -- Update locally for smooth response
        weapon:SetCurrentFOV(newFOV)

        -- Sync to server
        net.Start("ixCameraSetZoom")
            net.WriteFloat(newFOV)
        net.SendToServer()
    end)
end

-- Block weapon select from consuming scroll wheel while aiming
-- Must inject into HOOKS_CACHE to run BEFORE Helix's wepselect plugin
if CLIENT then
    local function SetupCameraScrollBlock()
        -- Create a fake plugin entry to insert into HOOKS_CACHE
        local cameraInputPlugin = {
            uniqueID = "ix_camera_input",
            name = "Camera Input Handler"
        }

        -- Ensure the hook cache exists
        HOOKS_CACHE["PlayerBindPress"] = HOOKS_CACHE["PlayerBindPress"] or {}

        -- Check if already added
        for plugin, _ in pairs(HOOKS_CACHE["PlayerBindPress"]) do
            if plugin.uniqueID == "ix_camera_input" then
                return
            end
        end

        -- Insert our hook into the plugin-level cache
        HOOKS_CACHE["PlayerBindPress"][cameraInputPlugin] = function(self, client, bind, pressed)
            local weapon = client:GetActiveWeapon()
            if not IsValid(weapon) or weapon:GetClass() ~= "ix_camera" then return end
            if not weapon:GetAiming() then return end

            bind = bind:lower()

            -- Block scroll wheel binds while aiming
            if bind:find("invprev") or bind:find("invnext") then
                return true  -- Consume input, prevent weapon select
            end
        end
    end

    -- Try to set up immediately if HOOKS_CACHE exists (player joined late)
    if HOOKS_CACHE then
        SetupCameraScrollBlock()
    end

    -- Also set up on InitializedPlugins for fresh server start
    hook.Add("InitializedPlugins", "ixCameraSetupScrollBlock", function()
        SetupCameraScrollBlock()
    end)
end

-- ============================================================================
-- FOV OVERRIDE
-- ============================================================================

function SWEP:TranslateFOV(fov)
    if self:GetAiming() then
        return self:GetCurrentFOV()
    end
    return fov
end

-- ============================================================================
-- CLIENT: HUD
-- ============================================================================

if CLIENT then
    -- Helper function to find the camera item from player's inventory
    -- Cached to avoid inventory scan every frame
    function SWEP:GetCameraItem()
        -- Check cache validity (refresh every 0.5s or if item became invalid)
        local now = CurTime()
        if self._cameraItemCache and self._cameraItemCacheTime and (now - self._cameraItemCacheTime) < 0.5 then
            return self._cameraItemCache
        end

        local owner = self:GetOwner()
        if not IsValid(owner) then
            self._cameraItemCache = nil
            self._cameraItemCacheTime = now
            return nil
        end

        local character = owner:GetCharacter()
        if not character then
            self._cameraItemCache = nil
            self._cameraItemCacheTime = now
            return nil
        end

        local inventory = character:GetInventory()
        if not inventory then
            self._cameraItemCache = nil
            self._cameraItemCacheTime = now
            return nil
        end

        -- Use GetItemsByUniqueID for faster filtering
        local cameras = inventory:GetItemsByUniqueID("camera", true)
        for _, item in ipairs(cameras) do
            if item:GetData("equipped") then
                self._cameraItemCache = item
                self._cameraItemCacheTime = now
                return item
            end
        end

        self._cameraItemCache = nil
        self._cameraItemCacheTime = now
        return nil
    end

    function SWEP:DrawHUD()
        if not self:GetAiming() then return end
        if self.hidingHUD then return end  -- Don't draw HUD during photo capture

        local scrW, scrH = ScrW(), ScrH()
        local item = self:GetCameraItem()

        -- Calculate square viewfinder that matches EXACTLY what will be captured
        -- This ensures WYSIWYG - what you see is what you get in the photo
        local borderSize = 80
        local maxViewfinderW = scrW - (borderSize * 2)
        local maxViewfinderH = scrH - (borderSize * 2)

        -- Square size matches the capture logic in CapturePhoto()
        local squareSize = math.min(maxViewfinderW, maxViewfinderH)
        local squareX = (scrW - squareSize) / 2
        local squareY = (scrH - squareSize) / 2

        -- Draw black overlay covering everything EXCEPT the square viewfinder
        surface.SetDrawColor(0, 0, 0, 220)
        -- Top strip
        surface.DrawRect(0, 0, scrW, squareY)
        -- Bottom strip
        surface.DrawRect(0, squareY + squareSize, scrW, scrH - (squareY + squareSize))
        -- Left strip
        surface.DrawRect(0, squareY, squareX, squareSize)
        -- Right strip
        surface.DrawRect(squareX + squareSize, squareY, scrW - (squareX + squareSize), squareSize)

        -- Viewfinder frame (white border around square)
        surface.SetDrawColor(255, 255, 255, 150)
        surface.DrawOutlinedRect(squareX, squareY, squareSize, squareSize, 2)

        -- Crosshair (circle + square) - centered
        local cx, cy = scrW / 2, scrH / 2

        -- Outer circle
        surface.DrawCircle(cx, cy, 30, 255, 255, 255, 150)
        -- Inner square
        surface.SetDrawColor(255, 255, 255, 150)
        surface.DrawOutlinedRect(cx - 10, cy - 10, 20, 20, 1)

        -- Corner brackets (scale based on viewfinder size)
        local bracketSize = math.max(20, squareSize * 0.02)
        local bracketOffset = squareSize * 0.15
        surface.SetDrawColor(255, 255, 255, 200)

        -- Top-left
        surface.DrawRect(cx - bracketOffset, cy - bracketOffset, bracketSize, 2)
        surface.DrawRect(cx - bracketOffset, cy - bracketOffset, 2, bracketSize)
        -- Top-right
        surface.DrawRect(cx + bracketOffset - bracketSize, cy - bracketOffset, bracketSize, 2)
        surface.DrawRect(cx + bracketOffset - 2, cy - bracketOffset, 2, bracketSize)
        -- Bottom-left
        surface.DrawRect(cx - bracketOffset, cy + bracketOffset - 2, bracketSize, 2)
        surface.DrawRect(cx - bracketOffset, cy + bracketOffset - bracketSize, 2, bracketSize)
        -- Bottom-right
        surface.DrawRect(cx + bracketOffset - bracketSize, cy + bracketOffset - 2, bracketSize, 2)
        surface.DrawRect(cx + bracketOffset - 2, cy + bracketOffset - bracketSize, 2, bracketSize)

        -- Info bar at bottom of viewfinder (inside the square)
        local infoY = squareY + squareSize - 30

        -- Semi-transparent background for info bar
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(squareX, infoY - 5, squareSize, 40)

        -- Battery indicator (left)
        local batteryCharge = 0
        if item then
            local batteries = item:GetData("batteries", {})
            batteryCharge = batteries[1] or 0
        end

        local batteryColor = batteryCharge >= 20 and Color(100, 255, 100) or Color(255, 100, 100)
        draw.SimpleText(string.format("⚡ %dup", batteryCharge), "ixMediumFont", squareX + 20, infoY, batteryColor, TEXT_ALIGN_LEFT)

        -- Flash + Zoom indicator (center) - combined so entire string is centered
        local flashText = self:GetFlashEnabled() and "FLASH: ON" or "FLASH: OFF"
        local zoomPercent = math.Round(100 - ((self:GetCurrentFOV() - self.MinFOV) / (self.MaxFOV - self.MinFOV)) * 100)
        local centerText = string.format("[%s | Zoom: %d%%]", flashText, zoomPercent)
        local flashColor = self:GetFlashEnabled() and Color(255, 255, 100) or ix.constants.COLOR_UI_NEUTRAL
        draw.SimpleText(centerText, "ixMediumFont", cx, infoY, flashColor, TEXT_ALIGN_CENTER)

        -- Film indicator (right)
        local filmShots = 0
        if item then
            local film = item:GetData("film", nil)
            filmShots = film and film.shots or 0
        end

        local filmColor = filmShots > 0 and Color(100, 200, 255) or Color(255, 100, 100)
        draw.SimpleText(string.format("%d/10", filmShots), "ixMediumFont", squareX + squareSize - 20, infoY, filmColor, TEXT_ALIGN_RIGHT)
    end

    -- Hide default crosshair when aiming
    function SWEP:DoDrawCrosshair(x, y)
        return self:GetAiming()
    end

    -- ========================================================================
    -- CLIENT: Photo Capture
    -- ========================================================================

    net.Receive("ixCameraApprovePhoto", function()
        local weapon = LocalPlayer():GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_camera" then return end

        -- Capture the photo
        weapon:CapturePhoto()
    end)

    function SWEP:CapturePhoto()
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        -- Hide HUD temporarily for clean capture
        self.hidingHUD = true
        self.captureNextFrame = true

        -- CRITICAL: We need to capture on the NEXT frame's PostRender
        -- so that this frame's DrawHUD can check hidingHUD and not draw
        -- Frame N: Set hidingHUD, DrawHUD still draws (too late), schedule hook
        -- Frame N+1: DrawHUD skips due to hidingHUD, PostRender captures clean frame
        hook.Add("PostRender", "ixCameraCapture", function()
            if not IsValid(self) then
                hook.Remove("PostRender", "ixCameraCapture")
                return
            end

            -- Skip first frame (where HUD was already drawn)
            if self.captureNextFrame then
                self.captureNextFrame = false
                return
            end

            -- Remove the hook (one-shot)
            hook.Remove("PostRender", "ixCameraCapture")

            -- Calculate capture area to match the viewfinder
            -- The viewfinder has 80px border on all sides, so inner area is (scrW-160, scrH-160)
            -- We capture a square using the smaller dimension (so it fits in viewfinder)
            local scrW, scrH = ScrW(), ScrH()
            local borderSize = 80  -- Must match DrawHUD border
            local viewfinderW = scrW - (borderSize * 2)
            local viewfinderH = scrH - (borderSize * 2)

            -- Use smaller dimension for square capture (fits entirely in viewfinder)
            -- Cap at 512x512 - photo viewer displays at 512x512 max, larger is wasteful
            -- and would exceed net message limits (~64KB)
            local captureSize = math.min(viewfinderW, viewfinderH, 512)

            -- Center the capture on screen
            local captureX = (scrW - captureSize) / 2
            local captureY = (scrH - captureSize) / 2

            -- Capture the screen (quality 60 keeps file small, ~15-25KB for 512x512)
            local data = render.Capture({
                format = "jpeg",
                quality = 60,
                x = captureX,
                y = captureY,
                w = captureSize,
                h = captureSize
            })

            self.hidingHUD = false

            if data then
                -- Encode to base64 for transmission
                local encoded = util.Base64Encode(data)

                if encoded and #encoded > 0 then
                    -- Size check
                    if #encoded > 60000 then
                        LocalPlayer():NotifyLocalized("cameraImageTooLarge")
                        return
                    end

                    -- Send photo data to server
                    -- Server will store in file and only keep ID in item (prevents inventory sync overflow)
                    net.Start("ixCameraPhotoData")
                        net.WriteUInt(#encoded, 32)
                        net.WriteData(encoded, #encoded)
                    net.SendToServer()

                    -- Play shutter sound
                    surface.PlaySound("buttons/lightswitch2.wav")
                end
            end
        end)
    end

    -- Flash effect received from server
    net.Receive("ixCameraFlashEffect", function()
        local pos = net.ReadVector()

        -- Create screen flash effect for local player if nearby
        local localPlayer = LocalPlayer()
        if localPlayer:GetPos():Distance(pos) < 500 then
            -- Brief white flash on screen
            local flash = vgui.Create("DPanel")
            flash:SetSize(ScrW(), ScrH())
            flash:SetPos(0, 0)
            flash.startTime = RealTime()
            flash.Paint = function(pnl, w, h)
                local alpha = 255 * (1 - (RealTime() - pnl.startTime) / 0.15)
                if alpha <= 0 then
                    pnl:Remove()
                    return
                end
                surface.SetDrawColor(255, 255, 255, alpha)
                surface.DrawRect(0, 0, w, h)
            end
        end
    end)

    -- Flash toggle feedback
    net.Receive("ixCameraFlashToggled", function()
        local enabled = net.ReadBool()
        local weapon = LocalPlayer():GetActiveWeapon()
        if IsValid(weapon) and weapon:GetClass() == "ix_camera" then
            weapon:SetFlashEnabled(enabled)
        end

        if enabled then
            LocalPlayer():NotifyLocalized("cameraFlashOn")
        else
            LocalPlayer():NotifyLocalized("cameraFlashOff")
        end
    end)
end

-- ============================================================================
-- SERVER: Networking
-- ============================================================================

if SERVER then
    -- Network strings registered in schema/sv_netstrings.lua

    -- Forward declaration for ProcessCompletePhoto (defined below)
    local ProcessCompletePhoto

    -- Handle photo request
    net.Receive("ixCameraRequestPhoto", function(len, client)
        local weapon = client:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_camera" then return end
        if not weapon:GetAiming() then return end

        local item = weapon.ixItem
        if not item then
            client:NotifyLocalized("cameraNoBattery")
            return
        end

        -- Check battery
        local batteries = item:GetData("batteries", {})
        if #batteries == 0 then
            client:NotifyLocalized("cameraNoBattery")
            return
        end
        if batteries[1] < weapon.BatteryDrainPerPhoto then
            client:NotifyLocalized("cameraNoCharge")
            return
        end

        -- Check film
        local film = item:GetData("film", nil)
        if not film or film.shots <= 0 then
            client:NotifyLocalized("cameraNoFilm")
            return
        end

        -- Resources OK - check if flash needed
        if weapon:GetFlashEnabled() then
            -- Create flash BEFORE capture so it illuminates the scene
            local light = ents.Create("light_dynamic")
            if IsValid(light) then
                light:SetPos(client:GetShootPos())
                light:SetKeyValue("brightness", "6")  -- Brighter for photo
                light:SetKeyValue("distance", "600")  -- Longer range
                light:SetKeyValue("_light", "255 255 255 255")
                light:Spawn()
                light:Fire("TurnOn", "", 0)
                light:Fire("Kill", "", 0.5)  -- Keep lit briefly
            end

            -- Notify nearby players of flash effect
            local nearby = ents.FindInSphere(client:GetPos(), 500)
            for _, ent in ipairs(nearby) do
                if ent:IsPlayer() then
                    net.Start("ixCameraFlashEffect")
                        net.WriteVector(client:GetPos())
                    net.Send(ent)
                end
            end

            -- Brief delay for light to illuminate scene, then capture
            timer.Simple(0.05, function()
                if IsValid(client) then
                    net.Start("ixCameraApprovePhoto")
                    net.Send(client)
                end
            end)
        else
            -- No flash - capture immediately
            net.Start("ixCameraApprovePhoto")
            net.Send(client)
        end
    end)

    -- Handle photo data from client
    -- With 512x512 cap, data fits in single message (<64KB)
    net.Receive("ixCameraPhotoData", function(len, client)
        local dataLen = net.ReadUInt(32)
        local imageData = net.ReadData(dataLen)

        if not imageData or #imageData == 0 then
            return
        end

        ProcessCompletePhoto(client, imageData)
    end)

    -- Shared function to process complete photo data
    ProcessCompletePhoto = function(client, imageData)
        local weapon = client:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_camera" then return end

        local item = weapon.ixItem
        if not item then return end

        -- Re-verify resources (in case state changed)
        local batteries = item:GetData("batteries", {})
        if #batteries == 0 or batteries[1] < weapon.BatteryDrainPerPhoto then
            return
        end

        local film = item:GetData("film", nil)
        if not film or film.shots <= 0 then
            return
        end

        -- Drain battery
        batteries[1] = batteries[1] - weapon.BatteryDrainPerPhoto
        item:SetData("batteries", batteries)

        -- Check for auto-eject
        if batteries[1] <= 0 then
            item:AutoEjectDepleted(client)
            item:AutoLoadFromInventory(client)
        end

        -- Consume film shot
        film.shots = film.shots - 1
        if film.shots <= 0 then
            item:SetData("film", nil)
            client:NotifyLocalized("cameraFilmEmpty")
        else
            item:SetData("film", film)
        end

        -- Flash was already fired before capture (in ixCameraRequestPhoto)
        -- so the scene is illuminated in the photo

        -- Create photo item
        local character = client:GetCharacter()
        if not character then return end

        local inventory = character:GetInventory()
        if not inventory then return end

        -- Generate unique photo ID and save image to file
        -- This prevents inventory sync overflow (storing ~25KB per photo in item data would crash)
        local photoID = os.time() .. "_" .. math.random(10000, 99999)
        local photoDir = "ix_photos"

        -- Ensure directory exists
        if not file.IsDir(photoDir, "DATA") then
            file.CreateDir(photoDir)
        end

        -- Save image data to file
        -- Note: Uses .txt extension for base64-encoded JPEG data. GMod's file.Write
        -- works with any extension, and .txt ensures no issues with file system filters.
        -- The actual content is base64 text, so .txt is technically accurate.
        file.Write(photoDir .. "/" .. photoID .. ".txt", imageData)

        -- Item only stores the ID reference, not the actual image data
        local photoData = {
            photoID = photoID,  -- Reference to file, NOT the actual image
            timestamp = os.time(),
            photographer = character:GetName(),
            title = "",
            titleSet = false
        }

        -- Try to add to inventory
        local success = inventory:Add("photo", 1, photoData)

        if success then
            client:NotifyLocalized("cameraPhotoTaken")
        else
            -- Drop on ground
            local dropPos = client:GetPos() + Vector(0, 0, 16)
            ix.item.Spawn("photo", dropPos, nil, nil, photoData)
            client:NotifyLocalized("cameraInventoryFull")
        end

        -- Play shutter sound for others
        client:EmitSound("buttons/lightswitch2.wav", 60)
    end

    -- Handle aiming state
    net.Receive("ixCameraSetAiming", function(len, client)
        local weapon = client:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_camera" then return end

        local aiming = net.ReadBool()
        weapon:SetAiming(aiming)
    end)

    -- Handle zoom
    net.Receive("ixCameraSetZoom", function(len, client)
        local weapon = client:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_camera" then return end

        local fov = net.ReadFloat()
        fov = math.Clamp(fov, weapon.MinFOV, weapon.MaxFOV)
        weapon:SetCurrentFOV(fov)
    end)

    -- Handle flash toggle
    net.Receive("ixCameraToggleFlash", function(len, client)
        local weapon = client:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_camera" then return end

        local enabled = not weapon:GetFlashEnabled()
        weapon:SetFlashEnabled(enabled)

        net.Start("ixCameraFlashToggled")
            net.WriteBool(enabled)
        net.Send(client)
    end)
end

-- ============================================================================
-- HOOKS
-- ============================================================================

hook.Add("PlayerDeath", "ixCameraDeath", function(client)
    local weapon = client:GetWeapon("ix_camera")
    if IsValid(weapon) then
        weapon:SetAiming(false)
    end
end)

hook.Add("ixPlayerKnockedOut", "ixCameraKnockout", function(client)
    local weapon = client:GetWeapon("ix_camera")
    if IsValid(weapon) then
        weapon:SetAiming(false)
    end
end)
