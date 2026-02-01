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
-- CURRENCY SYSTEM (schema/sv_schema.lua handlers)
-- =============================================================================
util.AddNetworkString("ixMoneyDestroy")
util.AddNetworkString("ixMoneyGive")
util.AddNetworkString("ixWalletGive")
util.AddNetworkString("ixCurrencySplit")
util.AddNetworkString("ixCurrencySplitConfirm")
util.AddNetworkString("ixBagDrop")  -- Wallet/bag drop functionality

-- =============================================================================
-- PHOTO SYSTEM (schema/items/documents/)
-- =============================================================================
util.AddNetworkString("ixPhotoRename")
util.AddNetworkString("ixPhotoDestroy")
util.AddNetworkString("ixPhotoRequest")
util.AddNetworkString("ixPhotoData")
util.AddNetworkString("ixPhotoViewFromGround")
util.AddNetworkString("ixPhotoAlbumView")
util.AddNetworkString("ixPhotoAlbumViewData")
util.AddNetworkString("ixPhotoAlbumRename")
util.AddNetworkString("ixPhotoAlbumViewFromGround")

-- =============================================================================
-- PERSONAL ID (schema/items/documents/)
-- =============================================================================
util.AddNetworkString("ixShowPersonalID")

-- =============================================================================
-- DOOR SYSTEM (schema/libs/sh_doors.lua)
-- =============================================================================
util.AddNetworkString("ixDoorsFrameUpdate")
util.AddNetworkString("ixDoorsSync")

-- =============================================================================
-- DOOR INSTALLATION (entities/weapons/ix_door.lua)
-- =============================================================================
util.AddNetworkString("ixDoorInstall")
util.AddNetworkString("ixDoorCancel")

-- =============================================================================
-- LOCK SYSTEM (entities/weapons/ix_lock.lua)
-- =============================================================================
util.AddNetworkString("ixLockInstall")
util.AddNetworkString("ixLockProgress")
util.AddNetworkString("ixLockCancel")

-- =============================================================================
-- LOCKPICKING (entities/weapons/ix_lockpick.lua)
-- =============================================================================
util.AddNetworkString("ixLockpickStart")
util.AddNetworkString("ixLockpickAttempt")
util.AddNetworkString("ixLockpickResult")
util.AddNetworkString("ixLockpickCancel")
util.AddNetworkString("ixLockpickState")

-- =============================================================================
-- LOCK BREAKING (entities/weapons/ix_lockbreaker.lua)
-- =============================================================================
util.AddNetworkString("ixLockbreakerStart")
util.AddNetworkString("ixLockbreakerCancel")

-- =============================================================================
-- KEY SYSTEM (entities/weapons/ix_key.lua)
-- =============================================================================
util.AddNetworkString("ixKeyStartLock")
util.AddNetworkString("ixKeyStartUnlock")
util.AddNetworkString("ixKeyCancel")

-- =============================================================================
-- KEYRING (entities/weapons/ix_keyring.lua)
-- =============================================================================
util.AddNetworkString("ixKeyringLock")
util.AddNetworkString("ixKeyringUnlock")
util.AddNetworkString("ixKeyringCycle")

-- =============================================================================
-- TOOLKIT (entities/weapons/ix_toolkit.lua)
-- =============================================================================
util.AddNetworkString("ixToolkitStartRemove")
util.AddNetworkString("ixToolkitStartRepair")
util.AddNetworkString("ixToolkitCancel")

-- =============================================================================
-- LOCKSMITH MACHINE (entities/entities/ix_auto_locksmith/)
-- =============================================================================
util.AddNetworkString("ixLocksmithOpen")
util.AddNetworkString("ixLocksmithClose")
util.AddNetworkString("ixLocksmithProgramLock")
util.AddNetworkString("ixLocksmithProgramKey")
util.AddNetworkString("ixLocksmithAddKeying")
util.AddNetworkString("ixLocksmithRename")
util.AddNetworkString("ixLocksmithViewKeyings")
util.AddNetworkString("ixLocksmithResult")

-- =============================================================================
-- PERSONAL ID WEAPON (entities/weapons/ix_personalid.lua)
-- =============================================================================
util.AddNetworkString("ixPersonalIDShowForward")
util.AddNetworkString("ixPersonalIDViewSelf")

-- =============================================================================
-- FLASHLIGHT (entities/weapons/ix_flashlight.lua)
-- =============================================================================
util.AddNetworkString("ixFlashlightSetLight")  -- Renamed from ix_flashlight_SetLight for consistency

-- =============================================================================
-- LANTERN (entities/weapons/ix_lantern.lua)
-- =============================================================================
util.AddNetworkString("ixLanternSetLight")
util.AddNetworkString("ixLanternPlace")

-- =============================================================================
-- CAMERA (entities/weapons/ix_camera.lua)
-- =============================================================================
util.AddNetworkString("ixCameraRequestPhoto")
util.AddNetworkString("ixCameraApprovePhoto")
util.AddNetworkString("ixCameraPhotoData")
util.AddNetworkString("ixCameraSetAiming")
util.AddNetworkString("ixCameraSetZoom")
util.AddNetworkString("ixCameraToggleFlash")
util.AddNetworkString("ixCameraFlashToggled")
util.AddNetworkString("ixCameraFlashEffect")
