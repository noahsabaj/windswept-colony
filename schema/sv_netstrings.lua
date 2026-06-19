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
-- are now registered in helix/gamemode/core/libs/sh_currency.lua
-- =============================================================================
util.AddNetworkString("wsWalletGive")
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
-- PERSONAL ID (schema/items/documents/)
-- =============================================================================
util.AddNetworkString("wsShowPersonalID")

-- =============================================================================
-- DOOR SYSTEM (schema/libs/sh_doors.lua)
-- =============================================================================
util.AddNetworkString("wsDoorsSync")

-- =============================================================================
-- DOOR INSTALLATION (entities/weapons/ix_door.lua)
-- =============================================================================
util.AddNetworkString("wsDoorInstall")
util.AddNetworkString("wsDoorCancel")

-- =============================================================================
-- LOCK SYSTEM (entities/weapons/ix_lock.lua)
-- =============================================================================
util.AddNetworkString("wsLockInstall")
util.AddNetworkString("wsLockCancel")

-- =============================================================================
-- LOCKPICKING (entities/weapons/ix_lockpick.lua)
-- =============================================================================
util.AddNetworkString("wsLockpickStart")
util.AddNetworkString("wsLockpickAttempt")
util.AddNetworkString("wsLockpickCancel")

-- =============================================================================
-- LOCK BREAKING (entities/weapons/ix_lockbreaker.lua)
-- =============================================================================
util.AddNetworkString("wsLockbreakerStart")
util.AddNetworkString("wsLockbreakerCancel")

-- =============================================================================
-- KEY SYSTEM (entities/weapons/ix_key.lua)
-- =============================================================================
util.AddNetworkString("wsKeyStartLock")
util.AddNetworkString("wsKeyStartUnlock")
util.AddNetworkString("wsKeyCancel")

-- =============================================================================
-- KEYRING (entities/weapons/ix_keyring.lua)
-- =============================================================================
util.AddNetworkString("wsKeyringLock")
util.AddNetworkString("wsKeyringUnlock")
util.AddNetworkString("wsKeyringCycle")

-- =============================================================================
-- TOOLKIT (entities/weapons/ix_toolkit.lua)
-- =============================================================================
util.AddNetworkString("wsToolkitStartRemove")
util.AddNetworkString("wsToolkitStartRepair")
util.AddNetworkString("wsToolkitCancel")

-- =============================================================================
-- LOCKSMITH MACHINE (entities/entities/ix_auto_locksmith/)
-- =============================================================================
util.AddNetworkString("wsLocksmithOpen")
util.AddNetworkString("wsLocksmithClose")
util.AddNetworkString("wsLocksmithProgramLock")
util.AddNetworkString("wsLocksmithProgramKey")
util.AddNetworkString("wsLocksmithAddKeying")
util.AddNetworkString("wsLocksmithRename")
util.AddNetworkString("wsLocksmithViewKeyings")
util.AddNetworkString("wsLocksmithResult")

-- =============================================================================
-- PERSONAL ID WEAPON (entities/weapons/ix_personalid.lua)
-- =============================================================================
util.AddNetworkString("wsPersonalIDShowForward")

-- =============================================================================
-- FLASHLIGHT (entities/weapons/ix_flashlight.lua)
-- =============================================================================
util.AddNetworkString("wsFlashlightSetLight")  -- Renamed from ix_flashlight_SetLight for consistency

-- =============================================================================
-- LANTERN (entities/weapons/ix_lantern.lua)
-- =============================================================================
util.AddNetworkString("wsLanternSetLight")
util.AddNetworkString("wsLanternPlace")

-- =============================================================================
-- CAMERA (entities/weapons/ix_camera.lua)
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
util.AddNetworkString("wsRadioVolumeSet")     -- Client->Server: set volume value
util.AddNetworkString("wsRadioVoiceStart")    -- Client->Server: started transmitting
util.AddNetworkString("wsRadioVoiceStop")     -- Client->Server: stopped transmitting
util.AddNetworkString("wsVoiceAmplitude")     -- Client->Server: voice amplitude update

-- =============================================================================
-- STATIONARY RADIO (entities/entities/ix_stationary_radio/)
-- =============================================================================
util.AddNetworkString("wsStationaryRadioOpen")      -- Server->Client: open UI for entity
util.AddNetworkString("wsStationaryRadioClose")     -- Client->Server: client closed UI
util.AddNetworkString("wsStationaryRadioConfig")    -- Client->Server: channel config change
util.AddNetworkString("wsStationaryRadioTransmit")  -- Client->Server: text message
util.AddNetworkString("wsStationaryRadioMic")       -- Client->Server: mic toggle

-- =============================================================================
-- DOCUMENT SYSTEM (schema/libs/sh_documents.lua, schema/sv_documents.lua)
-- =============================================================================
util.AddNetworkString("wsDocumentWrite")       -- Client->Server: write content to paper
util.AddNetworkString("wsDocumentRead")        -- Client->Server: request document content
util.AddNetworkString("wsDocumentData")        -- Server->Client: send document content
util.AddNetworkString("wsDocumentErase")       -- Client->Server: erase pencil content
util.AddNetworkString("wsDocumentDestroy")     -- Client->Server: destroy paper item
util.AddNetworkString("wsContainerRename")     -- Client->Server: rename envelope/folder
util.AddNetworkString("wsSignatureSave")       -- Client->Server: save signature to character
util.AddNetworkString("wsTypewriterOpen")      -- Server->Client: open typewriter UI
util.AddNetworkString("wsTypewriterWrite")     -- Client->Server: type content on paper
util.AddNetworkString("wsTypewriterClose")     -- Client->Server: close typewriter UI
