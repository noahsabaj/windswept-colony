--[[
    Windswept Colony RP - English Language
]]--

LANGUAGE = {
    -- General
    schemaName = "Windswept Colony RP",
    
    -- Factions
    civilianDesc = "The laborers and colonists of Zephyrus.",
    securityDesc = "Colonial Security forces.",
    administrationDesc = "The colonial government.",
    conglomerateDesc = "Corporate representatives of the Conglomerate.",
    
    -- Custom strings
    windWarning = "WARNING: Surface windstorm approaching!",
    electionAnnouncement = "Elections will be held in %d days.",

    -- Radio strings
    radioAlreadyOn = "You already have a radio turned on.",
    radioNotOn = "Your radio is not turned on.",
    radioRequired = "You need a radio to do that.",
    invalidFrequency = "Invalid frequency format. Use ###.# (e.g., 100.0)",
    radioHandsUp = "You can't transmit with your hands up.",
    radioNoBattery = "No battery inserted.",
    radioBatteryDepleted = "Radio battery depleted.",
    radioBatteryLoaded = "Battery loaded (%dup).",
    radioBatteryEjected = "Battery ejected.",
    radioAutoLoaded = "Auto-loaded battery (%dup).",
    radioSlotFull = "The radio already has a battery loaded.",
    radioRequiresFull = "This radio requires a fully charged battery.",
    radioVolumeSet = "Volume set to %d%%.",
    radioTransmitting = "Transmitting...",
    radioCannotTransmit = "Cannot transmit right now.",

    -- Stationary Radio
    stationaryRadioInUse = "Console is in use.",
    stationaryRadioTooFar = "You moved too far from the console.",
    stationaryRadioNoTx = "No transmit channels enabled.",

    -- Battery
    batteryFull = "Battery is fully charged.",

    -- Flashlight
    flashlightBatteryLoaded = "Battery loaded (%dup).",
    flashlightBatteryEjected = "Battery ejected.",
    flashlightNoBattery = "No battery inserted.",
    flashlightBatteryDead = "Battery depleted.",
    flashlightEquipped = "Unequip the flashlight first.",
    flashlightAutoLoaded = "Auto-loaded battery (%dup).",
    flashlightNoCharge = "Battery has no charge.",
    flashlightSlotFull = "The flashlight already has a battery loaded.",

    -- Defibrillator
    defibNoBattery = "No battery inserted.",
    defibBatteryUsed = "Battery consumed. %d remaining.",
    defibAutoLoaded = "Auto-loaded battery.",
    defibRequiresFull = "Defibrillator requires fully charged batteries.",
    defibCharging = "Charging defibrillator...",
    defibCharged = "Defibrillator ready!",
    defibDischarged = "Defibrillator discharged.",
    defibStillCharging = "Still charging...",
    defibNotReady = "Charge the defibrillator first (right-click).",
    defibMissed = "Shock missed - battery consumed.",
    defibShockedAlive = "You shocked %s - they are now unconscious!",
    defibCantShockSelf = "You cannot shock yourself.",

    -- Camera
    cameraNoBattery = "No battery inserted.",
    cameraNoCharge = "Not enough battery charge.",
    cameraNoFilm = "No film loaded.",
    cameraBatteryLoaded = "Battery loaded (%dup).",
    cameraBatteryEjected = "Battery ejected.",
    cameraSlotFull = "The camera already has a battery loaded.",
    cameraFilmLoaded = "Film loaded (%d shots).",
    cameraFilmSlotFull = "The camera already has film loaded.",
    cameraFilmEmpty = "Film pack exhausted.",
    cameraPhotoTaken = "Photo captured!",
    cameraInventoryFull = "Inventory full - photo dropped.",
    cameraFlashOn = "Flash enabled.",
    cameraFlashOff = "Flash disabled.",
    cameraEquipped = "Unequip the camera first.",
    cameraAutoLoaded = "Auto-loaded battery (%dup).",
    cameraStorageFull = "Photo storage is full - cannot take more photos right now.",
    cameraTooManyPhotos = "You are carrying too many photographs.",

    -- Photo
    photoRenamed = "Photo named: %s",
    photoAlreadyNamed = "This photo has already been named.",
    photoDestroyed = "Photo destroyed.",
    photoDestroyConfirm = "Destroy this photo? This cannot be undone.",

    -- Photo Album
    albumRenamed = "Album renamed: %s",
    albumOnlyPhotos = "Only photos can be stored in albums.",

    -- Options
    optBatteryAutoEject = "Auto-eject depleted batteries",
    optdBatteryAutoEject = "Automatically eject batteries when fully depleted.",
    optBatteryAutoLoad = "Auto-load batteries",
    optdBatteryAutoLoad = "Automatically load batteries from inventory when slot is empty.",
    optBatteryFilterEmpty = "Filter empty batteries",
    optdBatteryFilterEmpty = "Hide depleted (0up) batteries from Load Battery dropdown.",
    inventory = "Inventory",

    -- Physical Description
    physAge = "AGE",
    physHeight = "HEIGHT",
    physWeight = "WEIGHT",
    physSkinTone = "SKIN TONE",
    physHairColor = "HAIR COLOR",
    physHairType = "HAIR TYPE",
    physHairLength = "HAIR LENGTH",
    physEyeColor = "EYE COLOR",
    physFacialHair = "FACIAL HAIR",
    physBuild = "BUILD",

    -- Physical Description Validation
    invalidAge = "Age must be between 18 and 128.",
    invalidHeight = "Height must be between 147cm and 198cm.",
    invalidWeight = "Weight must be between 90lbs and 350lbs.",
    invalidEyeColor = "Please select a valid eye color.",
    invalidFacialHair = "Please select a valid facial hair option.",

    -- Birth Date/Location
    physBirthMonth = "BIRTH DATE",
    physBirthLocation = "BIRTH LOCATION",
    invalidBirthMonth = "Please select a valid birth month.",
    invalidBirthDay = "Invalid day for selected month.",
    invalidBirthLocation = "Please select a valid birth location.",

    -- Ladder
    ladderEquipped = "You must unequip the ladder first.",
    ladderNoRoom = "No room in inventory for the ladder.",

    -- Lantern
    lanternEquipped = "You must unequip the lantern first.",
    lanternNoRoom = "No room in inventory for the lantern.",
    lanternNoBattery = "No battery inserted.",
    lanternNoCharge = "Battery has no charge.",
    lanternBatteryDead = "Battery depleted.",
    lanternBatteryLoaded = "Battery loaded (%dup).",
    lanternBatteryEjected = "Battery ejected.",
    lanternAutoLoaded = "Auto-loaded battery (%dup).",
    lanternSlotFull = "The lantern already has a battery loaded.",
    lanternCantPlace = "Can't place lantern here.",

    -- Binoculars
    binocularsEquipped = "Unequip the binoculars first.",

    -- Description Editing
    descEditDisabled = "Physical descriptions cannot be manually edited.",

    -- Weapons/Ammo
    noAmmoToLoad = "You don't have any ammunition to load.",
    mustHoldWeapon = "You must be holding the weapon to load it.",
    batteringRamEquipped = "Unequip the battering ram first.",

    -- Key System
    keyNoDoor = "No door in front of you.",
    keyNoLock = "This door has no lock.",
    keyDoesntFit = "This key doesn't fit the lock.",
    keyAlreadyLocked = "This door is already locked.",
    keyAlreadyUnlocked = "This door is already unlocked.",
    keyDoorOpen = "Close the door first to lock it.",
    keyLocked = "Door locked.",
    keyUnlocked = "Door unlocked.",
    keyEquipped = "Unequip the key first.",
    keyringOnlyKeys = "Only keys can be stored in a key ring.",
    keyringEquipped = "Unequip the key ring first.",

    -- Lock System
    lockNoDoor = "No door in front of you.",
    lockAlreadyHasLock = "This door already has a lock installed.",
    lockNeedToolkit = "You need a toolkit to install a lock.",
    lockInstalled = "Lock installed.",
    lockEquipped = "Unequip the lock first.",
    lockLookedAway = "Installation cancelled - you looked away.",
    lockTooFar = "Installation cancelled - you moved too far.",

    -- Door System
    doorIsLocked = "This door is locked.",
    doorCantPunch = "This door is too sturdy to punch.",
    doorNoFrame = "No empty door frame in front of you.",
    doorNeedToolkit = "You need a toolkit to install a door.",
    doorInstalled = "Door installed.",
    doorEquipped = "Unequip the door first.",
    doorLookedAway = "Installation cancelled - you looked away.",
    doorTooFar = "Installation cancelled - you moved too far.",
    doorInstallFailed = "Failed to create door entity.",
    doorNoFrameNearby = "No door frame nearby.",
    doorFrameDisabled = "Door frame disabled.",
    doorFrameEnabled = "Door frame enabled.",
    doorAllReset = "All doors reset to default.",

    -- Toolkit System
    toolkitNoDoor = "No door in front of you.",
    toolkitDoorLocked = "Unlock the door first.",
    toolkitRemoveLockFirst = "Remove the lock first.",
    toolkitNoLock = "This door has no lock.",
    toolkitLockLocked = "Unlock the lock first.",
    toolkitDoorRemoved = "Door removed.",
    toolkitLockRemoved = "Lock removed.",
    toolkitInventoryFull = "Inventory full.",
    toolkitEquipped = "Unequip the toolkit first.",
    toolkitLookedAway = "Work cancelled - you looked away.",
    toolkitTooFar = "Work cancelled - you moved too far.",
    toolkitDoorNotDamaged = "This door doesn't need repairs.",
    toolkitLockNotDamaged = "This lock doesn't need repairs.",
    toolkitNeedWood = "You need wood planks to repair this door.",
    toolkitNeedMetal = "You need metal sheets for this repair.",
    toolkitNoMaterial = "Repair material missing.",
    toolkitDoorRepaired = "Door repaired.",
    toolkitLockRepaired = "Lock repaired.",

    -- Lockpick System
    lockpickNoDoor = "No door in front of you.",
    lockpickNoLock = "This door has no lock.",
    lockpickAlreadyUnlocked = "This door is already unlocked.",
    lockpickLockBroken = "This lock is already broken.",
    lockpickSuccess = "Lock picked successfully.",
    lockpickBroke = "Your lockpick snapped!",
    lockpickOutOfAttempts = "Out of attempts - try another lockpick.",
    lockpickLockDestroyed = "The lock broke apart!",
    lockpickEquipped = "Unequip the lockpick first.",
    lockpickLookedAway = "Lockpicking cancelled - you looked away.",
    lockpickTooFar = "Lockpicking cancelled - you moved too far.",

    -- Lockbreaker System
    lockbreakerNoDoor = "No door in front of you.",
    lockbreakerNoLock = "This door has no lock.",
    lockbreakerSuccess = "Lock destroyed.",
    lockbreakerHeard = "You hear metal screeching nearby...",
    lockbreakerEquipped = "Unequip the lockbreaker first.",
    lockbreakerLookedAway = "Breaking cancelled - you looked away.",
    lockbreakerTooFar = "Breaking cancelled - you moved too far.",

    -- Locksmith Station
    locksmithInUse = "Someone is already using this station.",
    locksmithInvalidItem = "Invalid item.",
    locksmithNotYourItem = "That item is not in your inventory.",
    locksmithNeedBlankLock = "You need a blank lock to program.",
    locksmithNeedBlankKey = "You need a blank key to program.",
    locksmithSourceNotProgrammed = "The source item has no keying to copy.",
    locksmithInvalidSource = "Source must be a programmed lock or key.",
    locksmithLockProgrammed = "Lock programmed with keying: %s",
    locksmithKeyProgrammed = "Key programmed with keying: %s",
    locksmithNeedLock = "You need a programmed lock.",
    locksmithNeedKey = "You need a programmed key.",
    locksmithKeyNotProgrammed = "This key has no keying.",
    locksmithAlreadyHasKeying = "This lock already accepts that keying.",
    locksmithMaxKeyings = "This lock already has the maximum (3) keyings.",
    locksmithKeyingAdded = "Keying %s added to lock.",
    locksmithAlreadyNamed = "This item has already been named.",
    locksmithLockRenamed = "Lock renamed to: %s",
    locksmithKeyRenamed = "Key renamed to: %s",

    -- Door Admin Commands
    doorInvalidType = "Invalid door type. Use: wood, metal, or gate.",
    doorNoEmptyFrame = "No empty door frame nearby.",
    doorSpawned = "Door spawned.",
    doorSpawnFailed = "Failed to spawn door.",
    doorItemsGiven = "Door system test items added to inventory.",

    -- Money System
    destroyedCash = "You destroyed %s.",
    destroyedCoins = "You destroyed %s.",
    noTargetInFront = "No one in front of you.",
    targetNotValid = "Target is not valid.",
    targetTooFar = "Target is too far away.",
    targetNotAlive = "Target is not alive.",
    targetKnocked = "Target is unconscious.",
    targetRestrained = "Target is restrained.",
    targetNoInventory = "Target has no inventory.",
    targetInventoryFull = "Target's inventory is full.",
    gaveMoneyTo = "You gave %s to %s.",
    receivedMoneyFrom = "You received %s from %s.",

    -- Wallet System
    movedMoneyInto = "Moved %s into wallet.",
    noMoneyToMove = "No compatible money to move.",
    emptiedWallet = "Emptied %d item(s) from wallet.",
    walletEmptyFailed = "Could not empty %d item(s) - no space available.",
    walletEmpty = "Wallet is empty.",
    walletOnlyCurrency = "Only cash, coins, and ID cards can be stored in wallets.",
    walletCashOnly = "This wallet only accepts cash.",
    walletCoinsOnly = "This wallet only accepts coins.",

    -- Document System
    needWritingTool = "You need a pen or pencil equipped.",
    needEraser = "You need an eraser to erase pencil writing.",
    documentSaved = "Document saved.",
    documentEmpty = "Nothing to save.",
    documentErased = "Paper erased.",
    documentDestroyed = "Paper destroyed.",
    documentRenamed = "Document renamed: %s",
    documentAlreadyNamed = "This document has already been named.",
    documentSaveFailed = "Failed to save document.",
    documentFull = "This document is full.",
    cannotErasePen = "Pen writing cannot be erased.",
    notEnoughInk = "Not enough ink!",
    notEnoughLead = "Not enough lead!",
    paperBlank = "This paper is blank.",
    paperOnly = "Only paper can be stored here.",
    containerRenamed = "Name written.",
    signatureEmpty = "Draw a signature first.",
    signatureSaved = "Signature saved.",
    noSavedSignature = "No saved signature.",
    signatureTooComplex = "Signature too complex.",
    selectPaperFirst = "Select a paper first.",

    -- Pen
    penOutOfInk = "This pen is out of ink.",
    penRefilled = "Pen refilled.",
    penAlreadyFull = "Pen is already full.",

    -- Pencil
    pencilOutOfLead = "This pencil is out of lead.",

    -- Eraser
    eraserWornOut = "This eraser is worn out.",
    eraserNotEnoughDurability = "Eraser doesn't have enough durability.",

    -- Typewriter
    typewriterPlaced = "Typewriter placed.",
    typewriterPickedUp = "Typewriter picked up.",
    typewriterInUse = "Someone is using this typewriter.",
}
