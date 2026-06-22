--[[
    Centralized Network String Registry

    All schema and entity network strings in one place.
    Plugin network strings remain in their respective plugins for modularity.

    GMod has a 4096 string limit across all addons.
    Centralizing makes it easy to audit and prevent duplicates.

    NOTE: Third-party libs (netstream2) and plugins (permadeath, factions, prisoner)
    register their own strings for modularity.
]]--

-- =============================================================================
-- CURRENCY SYSTEM
-- wsMoneyGive, wsMoneyDestroy, wsCurrencySplit, wsCurrencySplitConfirm
-- are now registered in windswept/gamemode/core/libs/sh_currency.lua
-- =============================================================================
util.AddNetworkString("wsBagDrop")  -- Wallet/bag drop functionality

-- =============================================================================
-- PHOTO SYSTEM (schema/items/documents/)
-- =============================================================================
util.AddNetworkString("wsPhotoRename")
util.AddNetworkString("wsPhotoDestroy")
util.AddNetworkString("wsPhotoRequest")
util.AddNetworkString("wsPhotoData")
util.AddNetworkString("wsPhotoViewFromGround")
util.AddNetworkString("wsPhotoAlbumView")
util.AddNetworkString("wsPhotoAlbumViewData")
util.AddNetworkString("wsPhotoAlbumRename")
util.AddNetworkString("wsPhotoAlbumViewFromGround")

-- =============================================================================
-- DOOR SYSTEM (schema/libs/sh_doors.lua)
-- =============================================================================
util.AddNetworkString("wsDoorsSync")

-- =============================================================================
-- DOOR INSTALLATION (entities/weapons/ws_door.lua)
-- =============================================================================
util.AddNetworkString("wsDoorInstall")
util.AddNetworkString("wsDoorCancel")

-- =============================================================================
-- LOCK SYSTEM (entities/weapons/ws_lock.lua)
-- =============================================================================
util.AddNetworkString("wsLockInstall")
util.AddNetworkString("wsLockCancel")

-- =============================================================================
-- LOCKPICKING (entities/weapons/ws_lockpick.lua)
-- =============================================================================
util.AddNetworkString("wsLockpickStart")
util.AddNetworkString("wsLockpickAttempt")
util.AddNetworkString("wsLockpickCancel")

-- =============================================================================
-- LOCK BREAKING (entities/weapons/ws_lockbreaker.lua)
-- =============================================================================
util.AddNetworkString("wsLockbreakerStart")
util.AddNetworkString("wsLockbreakerCancel")

-- =============================================================================
-- KEY SYSTEM (entities/weapons/ws_key.lua)
-- =============================================================================
util.AddNetworkString("wsKeyStartLock")
util.AddNetworkString("wsKeyStartUnlock")
util.AddNetworkString("wsKeyCancel")

-- =============================================================================
-- KEYRING (entities/weapons/ws_keyring.lua)
-- =============================================================================
util.AddNetworkString("wsKeyringLock")
util.AddNetworkString("wsKeyringUnlock")
util.AddNetworkString("wsKeyringCycle")

-- =============================================================================
-- TOOLKIT (entities/weapons/ws_toolkit.lua)
-- =============================================================================
util.AddNetworkString("wsToolkitStartRemove")
util.AddNetworkString("wsToolkitStartRepair")
util.AddNetworkString("wsToolkitCancel")

-- =============================================================================
-- LOCKSMITH MACHINE (entities/entities/ws_auto_locksmith/)
-- =============================================================================
util.AddNetworkString("wsLocksmithOpen")    -- Server->Client: open UI
util.AddNetworkString("wsLocksmithResult")  -- Server->Client: operation result
-- wsLocksmithClose/ProgramLock/ProgramKey/AddKeying/Rename/ViewKeyings are now registered by
-- ws.action.Register (session shape) in the entity's init.lua, which owns their AddNetworkString.

-- =============================================================================
-- FLASHLIGHT (entities/weapons/ws_flashlight.lua)
-- =============================================================================
util.AddNetworkString("wsFlashlightSetLight")

-- =============================================================================
-- LANTERN (entities/weapons/ws_lantern.lua)
-- =============================================================================
util.AddNetworkString("wsLanternSetLight")
util.AddNetworkString("wsLanternPlace")

-- =============================================================================
-- CAMERA (entities/weapons/ws_camera.lua)
-- =============================================================================
util.AddNetworkString("wsCameraRequestPhoto")
util.AddNetworkString("wsCameraApprovePhoto")
util.AddNetworkString("wsCameraPhotoData")
util.AddNetworkString("wsCameraSetAiming")
util.AddNetworkString("wsCameraSetZoom")
util.AddNetworkString("wsCameraToggleFlash")
util.AddNetworkString("wsCameraFlashToggled")
util.AddNetworkString("wsCameraFlashEffect")

-- =============================================================================
-- RADIO SYSTEM (schema/items/equipment/sh_handheld_radio.lua)
-- =============================================================================
util.AddNetworkString("wsRadioVolume")        -- Server->Client: open volume slider
util.AddNetworkString("wsRadioVoiceStart")    -- Client->Server: started transmitting
util.AddNetworkString("wsRadioVoiceStop")     -- Client->Server: stopped transmitting
util.AddNetworkString("wsVoiceAmplitude")     -- Client->Server: voice amplitude update

-- =============================================================================
-- STATIONARY RADIO (entities/entities/ws_stationary_radio/)
-- =============================================================================
util.AddNetworkString("wsStationaryRadioOpen")      -- Server->Client: open UI for entity
-- wsStationaryRadioClose/Config/Transmit/Mic are now registered by ws.action.Register
-- (session shape) in the entity's init.lua, which owns their AddNetworkString. (session shape)

-- =============================================================================
-- DOCUMENT SYSTEM (schema/libs/sh_documents.lua, schema/sv_documents.lua)
-- =============================================================================
util.AddNetworkString("wsDocumentRead")        -- Client->Server: request document content
util.AddNetworkString("wsDocumentData")        -- Server->Client: send document content
util.AddNetworkString("wsDocumentErase")       -- Client->Server: erase pencil content
util.AddNetworkString("wsDocumentDestroy")     -- Client->Server: destroy paper item
util.AddNetworkString("wsSignatureSave")       -- Client->Server: save signature to character
util.AddNetworkString("wsTypewriterOpen")      -- Server->Client: open typewriter UI
-- wsTypewriterWrite/Close are now registered by ws.action.Register (session shape) in the
-- entity's init.lua, which owns their AddNetworkString. (session shape)
