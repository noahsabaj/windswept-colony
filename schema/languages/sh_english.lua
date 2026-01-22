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
    invalidSkinTone = "Please select a valid skin tone.",
    invalidHairColor = "Please select a valid hair color.",
    invalidHairType = "Please select a valid hair type.",
    invalidHairLength = "Please select a valid hair length.",
    invalidEyeColor = "Please select a valid eye color.",
    invalidFacialHair = "Please select a valid facial hair option.",

    -- Birth Date/Location
    physBirthMonth = "BIRTH DATE",
    physBirthLocation = "BIRTH LOCATION",
    invalidBirthMonth = "Please select a valid birth month.",
    invalidBirthDay = "Invalid day for selected month.",
    invalidBirthLocation = "Please select a valid birth location.",

    -- Personal ID Card
    idCardShown = "You showed your ID to %s.",
    idCardNotValid = "No valid player in front of you.",
    idCardEquipped = "You must unequip your ID card first.",
    idCardMustRaise = "Raise your ID card first (hold R).",

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

    -- Description Editing
    descEditDisabled = "Physical descriptions cannot be manually edited.",
}
