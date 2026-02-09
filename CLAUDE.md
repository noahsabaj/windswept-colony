# Windswept

## Project Overview

A Garry's Mod SeriousRP gamemode set in 2200 on Zephyrus, a hostile mining planet. Players work in Redrock City, a carbon mining colony owned by Eagle Extraction Conglomerate (EEC). The Carbon Miners Union (CMU-RC) controls mine access. Currency: CEG Dollars ($50).

**Map:** Windswept | **Framework:** Helix (Nutscript fork) (We have our own fork of Helix)

## Architecture

```
windswept/
├── schema/                  # Core gamemode code
│   ├── sh_schema.lua        # Main shared entry point
│   ├── cl_schema.lua        # Client entry point
│   ├── sv_schema.lua        # Server entry point
│   ├── sv_netstrings.lua    # Centralized network string registry
│   ├── cl_hooks.lua         # Client hooks
│   ├── sv_hooks.lua         # Server hooks
│   ├── items/               # Item definitions (domain-organized)
│   │   ├── base/            # Base classes (sh_base_*.lua files)
│   │   ├── clothing/        # Clothing outfits (casual, work, uniforms)
│   │   ├── currency/        # Cash, coins, wallet
│   │   ├── documents/       # Personal ID, photos, photo album
│   │   ├── doors/           # Door items (wood, metal, gate)
│   │   ├── equipment/       # Battery, flashlight, lantern, camera, etc.
│   │   ├── locks/           # Keys, locks, keyring, lockpick, toolkit
│   │   ├── materials/       # Crafting materials (metal sheets, wood planks)
│   │   ├── misc/            # Human remains, ladder, rations
│   │   └── weapons/         # Ammo, melee weapons, battering ram
│   ├── attributes/          # Character attributes
│   ├── derma/               # Custom UI panels
│   ├── libs/                # Custom libraries (auto-included by Helix before derma)
│   │   ├── sh_constants.lua # Centralized constants (ix.constants) - loads first alphabetically
│   │   ├── sh_birthdata.lua # Birth date/age system
│   │   ├── sh_physical.lua  # Physical appearance system
│   │   ├── sh_doors.lua     # Door system library
│   │   ├── sh_wallet.lua    # Wallet/currency library
│   │   ├── sh_radio.lua     # Radio utilities (frequency validation, etc.)
│   │   ├── sh_documents.lua # Document system library (file-based storage)
│   │   └── thirdparty/      # Third-party libs
│   │       └── sh_netstream2.lua
│   ├── languages/           # Localization
│   └── meta/                # Metatable extensions
├── plugins/                 # Modular features
│   ├── permadeath/          # Knockout/death/revival system
│   └── prisoner/            # Restraint system (zipties, gag, drag, leash)
├── entities/
│   ├── entities/            # Custom entities
│   └── weapons/             # Custom weapons (SWEPs)
└── gamemode/                # Helix gamemode loader

# NOTE: Custom addons are in garrysmod/addons/, NOT in the gamemode folder
garrysmod/addons/
└── windswept_fire/          # Performance-optimized fire system (forked from vFire)
```

## Reference Codebases

- D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\gamemodes\helix is **OUR framework** - not a dependency. We forked it and own it completely. Edit it directly whenever needed. The original Helix is unmaintained on GitHub anyway. Don't create workarounds or overrides when you can just fix it in Helix itself.

- D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\gamemodes\helix-hl2rp is a fully implemented Half-Life 2 RP gamemode using the Helix framework. Great implementation reference. MIT License.

## Lore Details

- The year is 2200. The Confederation of Earthly Governments (CEG) licenses uninhabited planets to mining corporations. Zephyrus is one such planet - hostile, dangerous, but rich in known Carbon reserves just underneath the surface of the planet.

- EEC: Eagle Extraction Conglomerate (the owners of the mine in this colony, Redrock City)

- The reason this colony exists is due to the massive reserves of pure carbon underneath the surface. The EEC operates a massive mine-colony here, exporting high-grade carbon from this colony to be used by humanity elsewhere (the solar system, other colonized locations). Like how Cuba was a massive sugar colony for Europe and America, Redrock City is a massive carbon mining colony for the human market. The EEC owns all the mines and has an agreement with the Miners Union that, officially, only union members are allowed access to the mines, meaning only union members (members of the CMU-RC, Carbon Miners Union-Redrock City) are allowed to extract the carbon, reaping the benefit for them and the union.

- Redrock City is where the gameplay takes place. It is a mining-colony right underneath the surface of Zephyrus.

## Design Principles

- **Fog of War**: Players never see exact numbers. Example: defibrillator has 45-95% success chance (probability² - even the chance itself varies), but players only know "decent odds, can fail." Nothing is 100% certain.

- Always be Helix-idiomatic. Before implementing any feature, check if Helix already provides it or has an established pattern for it. Read the framework source code in helix/gamemode/core/ to understand how things are done. For example, when we created custom character creation panels, we initially added our own labels and height logic, but Helix already auto-creates labels above OnDisplay panels and uses font-based height sizing (see ixTextEntry and ixNumSlider in cl_generic.lua). Following existing patterns avoids bugs and keeps code consistent.

- **Emergent organizations**: There are NO preset factions, classes, or organizational structures. All characters are permanently **factionless** (`TEAM_UNASSIGNED` / 0) and players must form their own organizations through roleplay. Personal IDs are given to ALL new characters via the `OnCharacterCreated` hook in `sv_schema.lua`. There is no salary system - players must earn money through emergent economic activity. This design enables fully emergent political and economic structures.

- **UI is colorblind (anti-metagaming)**: All game UI systems use uniform gray `Color(200, 200, 200)` for ALL players regardless of faction. Scoreboard headers, tooltips, character info panels, menu buttons - everything is the same color. There are NO faction colors anywhere in the code. If factions want "colors" that's purely an in-character roleplay thing ("We wear red armbands"), not something the game systems know about.

## Game Systems

- Currency: CEG Dollar, written as "$50" or "50 dollars". The dollar is the standard currency used throughout CEG-controlled space.

- For the battery system, "up" stands for "units of power", so a 100up battery has 100 units of power. Device drain rates vary: flashlight ~0.083up/sec (20 min per battery), lantern ~0.167up/sec (10 min per battery). Batteries are universal across all devices (defibrillator, flashlight, camera, lantern, etc.).

- **Centralized Constants** (`schema/sh_constants.lua`): Magic numbers and repeated values are defined in `ix.constants`:
  - `COLOR_UI_NEUTRAL` - Standard gray Color(200, 200, 200) for anti-metagaming UI
  - `RANGE_INTERACTION` - Standard player interaction range (100*100 for DistToSqr)
  - `RANGE_INTERACTION_CLOSE` - Close range for prisoner operations (96*96)
  - `DRAIN_FLASHLIGHT`, `DRAIN_LANTERN` - Battery drain rates
  - `BATTERY_FULL_CHARGE` - 100up
  - Helper functions: `ix.constants.WithinRange()`, `ix.constants.CanInteract()`

- **Network String Registry** (`schema/sv_netstrings.lua`): All schema and entity network strings are centralized here. This file is included by sv_schema.lua and registers 70+ strings for:
  - Currency system (ixMoneyDestroy, ixMoneyGive, ixCurrencySplit, etc.)
  - Photo system (ixPhotoRename, ixPhotoRequest, ixPhotoAlbumView, etc.)
  - Door system (ixDoorsSync, ixDoorInstall, etc.)
  - Lock system (ixLockInstall, ixLockpickStart, ixKeyringLock, etc.)
  - Equipment (ixFlashlightSetLight, ixLanternSetLight, ixCameraRequestPhoto, etc.)
  - Locksmith machine (ixLocksmithOpen, ixLocksmithProgramLock, etc.)
  - Document system (ixDocumentWrite, ixDocumentRead, ixDocumentData, ixDocumentErase, ixTypewriterOpen, etc.)

  Plugin strings remain in their plugins: permadeath (10), prisoner/restraint (4).

- **Fire System** (`garrysmod/addons/windswept_fire/`): Performance-optimized fire system forked from vFire. Used for cremation in the permadeath system. Key points:
  - **Location**: Must be in `garrysmod/addons/`, NOT in the gamemode folder. GMod auto-loads addons from this location.
  - **Attribution**: Particle effects (.pcf) and scorch textures (.vtf) are from vFire by Vioxtar/Cumberly (Workshop ID: 1525218777). Lua code is a complete rewrite.
  - **API**: `ws_fire.Create(pos, opts)`, `ws_fire.CreateOnEntity(ent, opts)`, `ws_fire.Extinguish(ent)`, `ws_fire.IsOnFire(ent)`
  - **Compatibility**: Maintains `.fires` table on entities and `.life`/`.feed` properties for permadeath integration.
  - **Performance**: Cluster-level rendering (1 particle system per cluster vs per-fire), spatial hashing for O(1) neighbor lookups, batched Think processing.
  - **GMod native fire sync**: `CreateOnEntity()` also calls `ent:Ignite()` so `ent:IsOnFire()` returns true and context menus show "extinguish". The `Entity:Extinguish()` metatable is overridden to also remove our fires.
  - **entityflame override**: Kills GMod's ugly native fire sprite so only our vFire particles render.
  - **World vs entity fires**: Entity fires (with parent) decay slowly and get sustained by cremation. World fires (no parent, e.g. ceiling/walls) decay 4-5x faster and have a 60-second maximum lifetime.
  - **Cremation integration**: The permadeath plugin's `ix_knocked` entity uses `ws_fire.CreateOnEntity()` to ignite bodies and `SustainFire()` to keep them burning until cremation completes (240 seconds).

- **Door & Lock System**: Physical lock and key system replacing Helix's door ownership. Key points:
  - **Brush-based doors are ignored**: Doors with models starting with `*` (func_door, func_door_rotating) are skipped by the entire system - detection, tools, battering ram, everything. Only `prop_door_rotating` doors are managed.
  - **Double door linking**: After spawning, doors are linked via `ixPartner` based on `targetname`/`slavename` keyvalues. This enables Helix's `GetDoorPartner()` to work for lock sync and breach sync.
  - **Lock sync for double doors**: `InstallLock()`, `RemoveLock()`, `LockDoor()`, `UnlockDoor()`, and `DamageLock()` all sync to partner doors automatically. Install a lock on one door, both doors get it.
  - **Breach = permanent destruction**: `ix.doors.BreachDoor()` permanently destroys the door with debris gibs and particle effects. The door is gone - frame is empty until a new door is installed. No restore, no respawn.
  - **Battering ram hit counter persists**: When a door is hit, the hit counter (`ixBatteringRamRequired`, `ixBatteringRamHits`) persists until the door is **repaired** or **destroyed**. No time-based reset. Saved to persistence file.
  - **Repair resets damage**: `ix.doors.RepairDoor()` resets health AND clears the battering ram hit counter.

- **Radio System** (`schema/items/equipment/sh_handheld_radio.lua`): Battery-powered radio with text and voice transmission.
  - **Model**: `models/radio/w_radio.mdl` (Workshop ID: 635535045)
  - **Battery drain**: Idle 0.033up/sec (~50 min), Active 0.056up/sec (~30 min). Active = transmitting or receiving.
  - **Text radio**: `/r <message>` or `/radio <message>`. Drains battery based on message length (15 chars/sec speaking rate).
  - **Voice radio**: Hold H to transmit voice over frequency. All players on same frequency hear you regardless of distance.
  - **Volume control**: 0-100%, affects how loud you hear incoming transmissions and eavesdrop range around you.
  - **Eavesdrop**: Players near someone with a receiving radio can hear transmissions. Range = `400 * receiverVolume * transmitterAmplitude`.
  - **Incapacitated states**: Can't transmit if knocked/gagged/restrained/dead, but radio still receives.
  - **One radio at a time**: Only one radio can be active per character.

- **Stationary Radio** (`entities/entities/ix_stationary_radio/`, `schema/items/equipment/sh_stationary_radio.lua`): Multi-channel dispatch console.
  - **Model**: `models/props_lab/citizenradio.mdl` (built-in HL2 model)
  - **4 channels**: Each channel has independent frequency (100.0-999.9), TX toggle, RX toggle, and volume (0-100).
  - **Wired power**: No battery required. Always powered when placed.
  - **Drop to place**: Drop item (standard Helix), position with hands, press E to open config UI.
  - **Hold E to pickup**: Uses standard `itemPickupTime` config. Channel settings persist on item.
  - **Single user**: Only one player can use the UI at a time. Others get "Console in use" message.
  - **Text transmission**: Message broadcasts to ALL TX-enabled frequencies simultaneously.
  - **Voice MIC mode**: Toggle MIC on to broadcast all sound reaching the entity's position. Acts as a "virtual ear" at its world position.
  - **Eavesdrop from stationary**: Players near a stationary radio can hear incoming transmissions on RX channels.
  - **Shared library**: `schema/libs/sh_radio.lua` provides `ix.radio.ValidateFrequency()`, `ix.radio.FormatFrequency()`, `ix.radio.GetDefaultChannels()`.

- **Voice System** (`schema/sv_hooks.lua`, `schema/cl_hooks.lua`): Custom voice with amplitude-based distance and anti-metagaming.
  - **Voice HUD removed**: No player names shown when speaking (CHudVoiceStatus hidden). Anti-metagaming.
  - **Amplitude-based distance**: Voice range scales with how loud you speak. Whisper ~100u, normal ~300u, yelling ~800u.
  - **Uses `Player:VoiceVolume()`**: Returns 0-1 amplitude, updated every 0.1 seconds while speaking.

- **Restraint System** (`plugins/prisoner/`): Physical restraint mechanics for emergent justice/conflict.
  - **Ziptie**: Consumable item. Equip and use on player to restrain them (5 sec hold). Anyone can use.
  - **Untie**: Press E on restrained player to release (5 sec, returns ziptie to untier).
  - **Gag**: Press R on restrained player to toggle blindness + speech block.
  - **Drag**: Hold LMB with lowered hands near restrained player to drag them. Can't sprint while dragging.
  - **Leash**: Hold RMB on restrained player near a surface to anchor them to it. Leashed players can't move.
  - **Unleash**: Press E on leashed player to release anchor (still restrained).
  - **Gavel**: RP prop that makes slam noise on LMB. Anyone can use.

- **Document System** (`schema/libs/sh_documents.lua`, `schema/items/documents/`): Paper and writing tools for creating physical documents.
  - **File-based storage**: Document content stored in `data/ix_documents/` as JSON files (like photo system). Items only store reference IDs to prevent inventory sync overflow.
  - **Writing tools**:
    - **Pen** (`sh_pen.lua`, `ix_pen`): Ink-based (1000 chars). Permanent writing, can sign. Refillable with ink cartridge.
    - **Pencil** (`sh_pencil.lua`, `ix_pencil`): Lead-based (500 chars). Writing can be erased by anyone with an eraser.
    - **Pencil with Eraser** (`sh_pencil_eraser.lua`): Same as pencil but can also erase.
    - **Eraser** (`sh_eraser.lua`, `ix_eraser`): Standalone eraser (500 durability). Erases pencil content only.
  - **Paper** (`sh_paper.lua`): Blank sheets that can be written on. Stores: paperID, documentType, author, title, wordCount, hasSignature, signatureAuthor, timestamp.
  - **Typewriter** (`sh_typewriter.lua`, `ix_typewriter`): Placeable entity for typed documents. Drop to place, E to use, Hold E to pick up. Typed content is monospace, no signatures.
  - **Document containers** (paper-only bags):
    - **Small Envelope** (5x1): 5 papers
    - **Large Envelope** (10x5): 50 papers
    - **Document Folder** (25x10): 250 papers
  - **Writing rules**:
    - Append-only: Cannot modify existing content, only add below it
    - Pen = permanent (handwritten), Pencil = erasable
    - Signatures: Mouse-drawn strokes, pen only, stored as normalized coordinates
    - Title: Can be set once per document
  - **UI panels** (`schema/derma/`):
    - `cl_document_editor.lua`: Write/append content, add signature
    - `cl_document_viewer.lua`: Read documents with signature display
    - `cl_signature_pad.lua`: Mouse-drawn signature canvas
    - `cl_typewriter.lua`: Typewriter typing interface

## Item Base Classes

### base_battery_device (`schema/items/base/sh_battery_device.lua`)

For battery-powered equipment. Provides battery management, equip/unequip, UI rendering.

**Configuration options:**
```lua
ITEM.maxBatteries = 1          -- Battery slots (1-4)
ITEM.weaponClass = "ix_flashlight"  -- SWEP class to give on equip
ITEM.playerItemKey = "ixFlashlightItem"  -- Key to store item ref on player
ITEM.equipSound = "items/flashlight1.wav"
ITEM.notifyPrefix = "flashlight"  -- For localized notifications
ITEM.requireFullBattery = false   -- Defib requires 100up batteries
ITEM.hasLightToggle = false       -- Show "Toggle Light" in menu
```

**Example child item (flashlight):**
```lua
ITEM.name = "Flashlight"
ITEM.model = "models/shaky/weapons/flashlight/w_flashlight.mdl"
ITEM.base = "base_battery_device"
ITEM.width = 1
ITEM.height = 2

ITEM.maxBatteries = 1
ITEM.weaponClass = "ix_flashlight"
ITEM.playerItemKey = "ixFlashlightItem"
ITEM.hasLightToggle = true
```

**Provided functions:** `GetBatteries()`, `SetBatteries()`, `GetBatteryCount()`, `HasBattery()`, `HasUsableCharge()`, `GetFirstBatteryCharge()`, `FindBestBatteryInInventory()`, `AutoEjectDepleted()`, `AutoLoadFromInventory()`, `PaintOver()`, `PopulateTooltip()`

**Provided item functions:** LoadBattery, EjectBattery, Equip, Unequip, ToggleLight (if enabled)

### base_currency (`schema/items/base/sh_currency.lua`)

For stackable currency items. Provides split, merge, give, and optional destroy.

**Configuration options:**
```lua
ITEM.currencyValue = 100  -- Cents per unit (100 for dollars, 1 for cents)
ITEM.unitName = "dollar"
ITEM.unitNamePlural = "dollars"
ITEM.unitSymbol = "$"
ITEM.symbolPrefix = true  -- true = "$50", false = "50¢"
ITEM.canDestroy = false   -- Whether destroy option appears
```

**Example child item (cash):**
```lua
ITEM.name = "Cash"
ITEM.model = "models/props/cs_assault/Dollar.mdl"
ITEM.base = "base_currency"

ITEM.currencyValue = 100
ITEM.unitName = "dollar"
ITEM.unitNamePlural = "dollars"
ITEM.unitSymbol = "$"
ITEM.symbolPrefix = true
ITEM.canDestroy = true
```

**Provided functions:** `GetQuantity()`, `FormatAmount()`, `GetName()`, `GetDescription()`, `CanTransfer()`

**Provided item functions:** Split, MergeAll, MergeWith, Give, Destroy (if canDestroy=true)

### base_equippable (`schema/items/base/sh_equippable.lua`)

For items that equip as SWEPs. Provides Equip/Unequip functions, transfer blocking, persistence.

**Configuration options:**
```lua
ITEM.equipWeaponClass = "ix_binoculars"  -- SWEP class to give (REQUIRED)
ITEM.equipPlayerKey = "ixBinocularsItem" -- Key on player to store item ref (REQUIRED)
ITEM.equipNotifyKey = "binocularsEquipped" -- Localization key for notifications (REQUIRED)
ITEM.equipSound = "items/ammo_pickup.wav"  -- Sound on equip (default)
ITEM.equipSoundVolume = 0.5   -- Equip sound volume
ITEM.unequipSoundVolume = 0.3 -- Unequip sound volume
ITEM.equipTip = "Equip this item."  -- Tooltip for equip button
ITEM.unequipTip = "Put this item away."  -- Tooltip for unequip button
```

**Example child item (binoculars):**
```lua
ITEM.name = "Binoculars"
ITEM.model = Model("models/weapons/w_binocularsbp.mdl")
ITEM.base = "base_equippable"

ITEM.equipWeaponClass = "ix_binoculars"
ITEM.equipPlayerKey = "ixBinocularsItem"
ITEM.equipNotifyKey = "binocularsEquipped"
ITEM.equipTip = "Hold the binoculars in your hands."
```

**Optional override method:**
```lua
-- Return false to prevent equipping (e.g., item not programmed)
function ITEM:CanEquip()
    return self:IsProgrammed()
end
```

**Provided:** Equip/Unequip functions, PaintOver (equipped indicator), postHooks.drop, OnTransferred, CanTransfer, OnLoadout

**Items using this base:** binoculars, battering_ram, ladder, lockbreaker, personal_id, lockpick, toolkit, key, lock

## Workflows

### How Workshop Addons Work

| Step | What to Do |
|------|------------|
| 1 | Subscribe to addon on Workshop |
| 2 | Find the .gma file in `steamapps/workshop/content/4000/<workshop_id>/` |
| 3 | Extract with: `gmad.exe extract -file "path/to/addon.gma" -out "output/folder"` |
| 4 | Browse extracted files to find model/material paths |
| 5 | Add `resource.AddWorkshop("<id>")` to server code |
| 6 | Use the paths in your Lua code |

The Workshop ID is the number in the URL: `steamcommunity.com/sharedfiles/filedetails/?id=3582530445`

**Example:**
```bash
"D:/SteamLibrary/steamapps/common/GarrysMod/bin/gmad.exe" extract \
  -file "D:/SteamLibrary/steamapps/workshop/content/4000/3582530445/gmpublisher.gma" \
  -out "D:/SteamLibrary/steamapps/workshop/content/4000/3582530445/extracted"
```

## Gotchas (Lessons Learned)

### Helix Framework

- **Schema load order**: Helix loads schema folders in this order: `libs/` → `derma/` → `sh_schema.lua` (see `sh_plugin.lua:41-55`). Files in `libs/` are auto-included alphabetically. This means libs are available to derma files, but `sh_schema.lua` code is NOT. The manual `ix.util.Include()` calls in `sh_schema.lua` for libs are redundant (harmless but unnecessary). If a derma file needs something at file scope, it must come from `libs/`, not `sh_schema.lua`.

- **Hook data flow in character creation**: In hooks like `AdjustCreationPayload`, Helix's OnAdjust functions run BEFORE your hook and populate `newPayload` with processed values. Use `newPayload.model` (the path) not `payload.model` (the index).

- **Equip data key is standardized to "equipped"**: All equippable items (weapons, outfits, custom equipment) use `item:GetData("equipped")` and `item:SetData("equipped", true/nil)`. This was standardized across both Helix base classes and custom items for consistency.

- **HOOKS_CACHE execution order**: Helix hook execution order: (1) HOOKS_CACHE plugin hooks, (2) Schema hooks, (3) Regular hook.Add hooks. To run before a Helix plugin, inject into HOOKS_CACHE directly. See ix_camera.lua lines 225-269.

- **ITEM.isBag requires View function**: When `ITEM.isBag = true`, Helix auto-calls `item.functions.View.OnClick(item)` on inventory open. You MUST define `ITEM.functions.View` with an `OnClick` handler, or you'll get "attempt to index field 'View' (a nil value)". See `sh_wallet.lua` or `sh_photo_album.lua` for the standard pattern that creates an `ixInventory` panel.

- **ix.config.Add requires explicit type for arrays**: The config system auto-detects strings, numbers, booleans, colors, and vectors, but NOT plain arrays/tables. If you add a config with an array value like `ix.config.Add("myList", {"a", "b", "c"}, ...)`, it will fail with "attempted to add config with invalid type". Fix: explicitly specify `type = ix.type.array` in the data parameter:
  ```lua
  ix.config.Add("myList", {"a", "b", "c"}, "Description", nil, {
      category = "myCategory",
      type = ix.type.array  -- Required for arrays!
  })
  ```
  **WARNING**: `ix.type.array` is for **dropdown selections** (single choice from options), not static lists. It requires a `populate` function to provide dropdown options. If your config is a static list not meant to be edited via dropdown (like a list of models), add `hidden = function() return true end` to prevent the settings UI from trying to render it as a broken dropdown:
  ```lua
  ix.config.Add("modelList", {"model1.mdl", "model2.mdl"}, "Description", nil, {
      category = "myCategory",
      type = ix.type.array,
      hidden = function() return true end  -- Prevents DComboBox nil error
  })
  ```

- **CanTransferItem hook name**: The hook is `CanTransferItem`, NOT `CanItemBeTransfered`. Wrong name = silent failure.

- **Inventory sync overflow**: Storing >10KB in item data via `item:SetData()` causes "Trying to send an overflowed net message" during inventory sync. Fix: File-based storage in `data/` folder, store only ID reference in item.

- **item:GetInventory() doesn't exist**: Helix items don't have a direct `GetInventory()` method. To get an item's inventory, go through the owner: `client:GetCharacter():GetInventory()`.

- **WeaponEquip hook fires during Give()**: When calling `client:Give("weapon_class")`, the `WeaponEquip` hook fires immediately during that call, not after. If you're tracking equipped items with variables like `client.ixItem = item`, set them BEFORE `Give()`, not after, or the hook won't see them.

- **PLUGIN global not available in net.Receive handlers**: The `PLUGIN` variable is only defined during plugin file load. In `net.Receive()` callbacks (which execute later), `PLUGIN` is nil. Fix: Store a local reference at load time:
  ```lua
  -- At top of sv_plugin.lua, after network strings
  local myPlugin = PLUGIN

  net.Receive("ixMyMessage", function(len, client)
      myPlugin:DoSomething()  -- Use the stored reference, not PLUGIN
  end)
  ```

- **ix.log.AddType is SERVER-only**: The logging system only exists on the server. If you call `ix.log.AddType()` on the client (e.g., in a shared plugin hook like `InitializedPlugins`), you'll get "attempt to call field 'AddType' (a nil value)". Fix: Wrap in `if SERVER then` or add `if not SERVER then return end` at the start of the function.

- **Helix auto-assigns `ITEM.base` based on folder name**: When loading items from subdirectories of `schema/items/`, Helix automatically sets `ITEM.base = "base_" + folder_name`. For example:
  - Items in `currency/` → `ITEM.base = "base_currency"`
  - Items in `equipment/` → `ITEM.base = "base_equipment"`
  - Items in `locks/` → `ITEM.base = "base_locks"`

  **This means every item subfolder MUST have a matching base file in `items/base/`:**

  | Folder | Required Base File | UniqueID (auto-generated) |
  |--------|-------------------|---------------------------|
  | `currency/` | `sh_currency.lua` | `base_currency` |
  | `clothing/` | `sh_clothing.lua` | `base_clothing` |
  | `documents/` | `sh_documents.lua` | `base_documents` |
  | `doors/` | `sh_doors.lua` | `base_doors` |
  | `equipment/` | `sh_equipment.lua` | `base_equipment` |
  | `locks/` | `sh_locks.lua` | `base_locks` |
  | `materials/` | `sh_materials.lua` | `base_materials` |
  | `misc/` | `sh_misc.lua` | `base_misc` |
  | `weapons/` | Helix built-in | `base_weapons` |

  **IMPORTANT**: Base files should NOT have `base_` in their filename! Helix automatically adds `base_` prefix when loading from the `base/` folder. So `sh_currency.lua` becomes `base_currency`.

  **To override auto-assignment**, explicitly set `ITEM.base` in your item file:
  ```lua
  -- This item is in equipment/ folder, but uses battery_device base instead
  ITEM.base = "base_battery_device"  -- Overrides auto-assigned "base_equipment"
  ```

  **Common errors**:
  - `[Helix] Item 'myitem' has a non-existent base! (base_foldername)` - You created a new item folder without a matching `sh_foldername.lua` in `items/base/`.
  - `[Helix] Item 'base_base_something' has a non-existent base!` - You named your base file `sh_base_something.lua` but it should be `sh_something.lua`. Helix adds the `base_` prefix automatically.

### SWEP/Weapon Development

- **Item-only vs Item+SWEP**: If using an existing weapon class (TFA, HL2, CSS), the item just needs `ITEM.base = "base_weapons"` and `ITEM.class = "tfa_ins2_wpn_38revolver"` - no custom SWEP file needed. Only create a custom SWEP (`entities/weapons/ix_*.lua`) when you need custom behavior (battery drain, special actions, etc.). Examples: Model 10 revolver uses TFA's class directly (item only); flashlight/camera need custom battery logic (item + SWEP).

- **SWEP:CreateMove() doesn't exist**: Not a valid SWEP method. Use `hook.Add("CreateMove", ...)` globally and check `LocalPlayer():GetActiveWeapon()` inside.

- **PrimaryAttack/SecondaryAttack are SERVER-only in Helix (CRITICAL)**: Helix only calls these on SERVER, not CLIENT. This is the most common SWEP bug in this codebase. Any code inside `if CLIENT then` blocks within these functions will NEVER execute.

  **The Problem:**
  ```lua
  -- THIS DOES NOT WORK - client code inside PrimaryAttack never runs
  function SWEP:PrimaryAttack()
      if CLIENT then
          net.Start("ixMyAction")  -- Never executes!
          net.SendToServer()
      end
  end
  ```

  **The Solution:** Detect input in Think() using `input.IsMouseDown()` with edge detection:
  ```lua
  function SWEP:Initialize()
      self:SetHoldType(self.HoldType)
      self.wasLMBDown = false
      self.wasRMBDown = false
  end

  function SWEP:Think()
      if CLIENT then
          -- Block input when UI is open
          if vgui.CursorVisible() then
              self.wasLMBDown = false
              self.wasRMBDown = false
              return
          end

          local lmbDown = input.IsMouseDown(MOUSE_LEFT)
          local rmbDown = input.IsMouseDown(MOUSE_RIGHT)

          -- Edge detection: only trigger on press, not hold
          if lmbDown and not self.wasLMBDown then
              net.Start("ixMyAction")
              net.SendToServer()
          end

          self.wasLMBDown = lmbDown
          self.wasRMBDown = rmbDown
      end
  end
  ```

  **Key components:**
  - `self.wasLMBDown`/`self.wasRMBDown` - Track previous frame's state for edge detection
  - `vgui.CursorVisible()` - Prevent weapon input when inventory/menus are open
  - `input.IsMouseDown(MOUSE_LEFT/MOUSE_RIGHT)` - Direct input polling
  - Edge detection pattern: `if down and not wasDown then` - Triggers once per click, not continuously

  **For NetworkVars:** Add safety checks since Think() runs before SetupDataTables completes:
  ```lua
  function SWEP:IsPerformingAction()
      if not self.GetLocking then return false end  -- Safety check
      return self:GetLocking() or self:GetUnlocking()
  end
  ```

- **SWEP:Think() runs on both realms**: Server has no input context, so `owner:KeyDown()` returns false server-side, causing state flicker. Wrap all input logic in `if CLIENT then`.

- **c_model vs v_model for UseHands**: GMod's `SWEP.UseHands = true` requires a c_model (weapon only, no arms). v_models have arms baked in and won't work with dynamic hands. Use `models/weapons/xxx/c_weapon.mdl` not `v_weapon.mdl`.

- **SWEP properties don't network to client**: Setting `weapon.ixItem = item` on SERVER doesn't make it available on CLIENT. The client's SWEP copy has no knowledge of server-set properties. Fix: Client must find the data another way - look up equipped item from inventory, use networked vars, or send via net message.

- **Worldmodel not visible in third person**: Workshop prop models lack bone attachments. Fix: Override `DrawWorldModel()` on CLIENT, manually position via `LookupBone("ValveBiped.Bip01_R_Hand")` + `GetBoneMatrix()`, offset with `ang:Forward()/Right()/Up()`. See `ix_personalid.lua` or `ix_gavel.lua` for examples.

- **Entity/weapon naming conflict**: Don't name a scripted entity the same as a weapon class. If weapon `ix_lantern` exists, an entity named `ix_lantern` will have broken NetworkVars (SetupDataTables doesn't register methods properly). Use distinct names like `ix_lantern` (weapon) and `ix_lantern_dropped` (entity).

- **SWEP.Drop = false is intentional**: Prevents GMod's native drop (raw weapon entities). Permadeath handles drops via `item:Transfer()` in `CreateKnockout()`, preserving item data. Only active weapon drops on knockout; other equipped items stay. Protected weapons (ix_hands, ix_handsup) never drop.

- **TFA/addon weapon models have broken collision for item pickup**: Workshop weapon models have razor-thin collision meshes (designed as attachments, not physics props). Eye traces can't hit dropped items → no pickup. Fix in `ix_item.lua`: detect thin bounds (<4 units), use OBB-based fallback physics with `COLLISION_GROUP_WEAPON`.

### Source Engine Entities

- **Replacing map entities requires full data capture**: When spawning entities to replace map-placed ones (like our door system), you must capture and restore ALL visual properties: `GetSkin()`, `GetColor()`, `GetMaterial()`, `GetSubMaterial()`, `GetBodyGroups()`. Missing any of these causes visual differences (wrong door color, missing parts, etc.).

- **Entity keyvalues via GetKeyValues()**: Map entities have keyvalues set by the mapper. Use `ent:GetKeyValues()` to get them all as a table, then `ent:SetKeyValue(key, value)` to apply to spawned entities. Critical for doors, buttons, etc.

- **SetKeyValue() BEFORE Spawn()**: Some keyvalues (like `hardware` for door handles) must be set before calling `Spawn()` or they won't take effect. Set model, position, angles, and keyvalues first, THEN call `Spawn()` and `Activate()`.

- **prop_door_rotating keyvalues** (from [Valve Developer Wiki](https://developer.valvesoftware.com/wiki/Prop_door_rotating)):
  - `hardware`: Door handle type (0=none, 1=lever, 2=push bar, 3=keypad) - **critical for handles to appear**
  - `targetname`: Door's name for I/O references and double door linking
  - `slavename`: Name of door(s) that open/close together - **critical for double doors**
  - `opendir`: Force open direction (0=both, 1=forward only, 2=backward only)
  - `skin`: Model skin variant (same model, different textures)
  - `spawnflags`: Behavior flags (starts locked, silent, etc.)
  - `distance`, `speed`, `returndelay`: Door movement settings
  - `soundopenoverride`, `soundcloseoverride`, etc.: Custom sounds

- **Double door synchronization**: Master's `slavename` references slave's `targetname`. Must capture BOTH keyvalues when replacing map doors or doors operate independently.

- **ixPartner vs targetname/slavename**: Source uses keyvalues for engine-level sync; Helix uses `door.ixPartner` for Lua-level lookup (`GetDoorPartner()`). SEPARATE systems - setting keyvalues doesn't set `ixPartner`. Our `ix.doors.LinkPartners()` builds `ixPartner` links by matching `slavename` to `targetname`.

- **Door handles are NOT separate entities**: They're part of the door model, controlled by the `hardware` keyvalue and model bodygroups. The model has a "handle" bone that can be queried via `LookupBone("handle")`.

- **Brush-based doors vs prop-based doors**: `prop_door_rotating` uses model files. `func_door`/`func_door_rotating` use brush geometry (models like `*90`, `*57` = BSP refs). Cannot spawn props with brush models (`ent:SetModel("*90")` fails). When using `ent:IsDoor()`, skip models starting with `*`.

- **MapIO infinite loop warnings**: Firing events (`door:Fire("unlock")`) can trigger I/O chains. Circular map I/O causes "Breaking out of potential MapIO infinite loop!" - map design issue, Source self-protects.

- **Door lock/unlock sounds**: Use `doors/door_latch3.wav` for locking (heavier click) and `doors/door_latch1.wav` for unlocking (lighter click).

### GMod Networking

- **64KB net message limit**: `net.WriteData()` and `net.WriteString()` cap at ~64KB. Reduce data at source (smaller images, lower quality) rather than chunking.

- **Global variable race conditions**: `ix.someData = value` gets overwritten when multiple players trigger simultaneously. Use tables keyed by unique ID: `ix.someData[requestID] = value`.

### Rendering

- **render.Capture() requires render context**: Cannot call from Think(), timers, or net receivers. Must use `hook.Add("PostRender", ...)`.

- **Frame timing for HUD-free captures**: Hiding HUD takes effect NEXT frame. Skip one frame before capturing: set flag, return early first PostRender call, capture on second.

- **light_dynamic networks to clients**: Server-created dynamic lights DO illuminate client scenes. Brief delay (~50ms) ensures entity networks before dependent actions.

### Fire System (windswept_fire)

- **Particle registration is CLIENT-only**: `game.AddParticles()`, `PrecacheParticleSystem()`, and `game.AddDecal()` only work on CLIENT. Calling them on SERVER causes errors that break addon loading. Always wrap in `if CLIENT then`.

- **Particle names are case-sensitive**: vFire particles use exact capitalization like `vFire_Flames_Medium` (capital M). Using lowercase (`medium`) silently fails - particles won't render.

- **CreateParticleSystem requires 4 parameters**: GMod's `CreateParticleSystem(ent, name, attachType, attachIndex)` needs all 4 args. Missing the 4th parameter causes particles to not render.

- **GMod native fire state must be synced**: GMod's context menu checks `ent:IsOnFire()` for ignite/extinguish options. Our fire system must call `ent:Ignite()` when creating fire and override `Entity:Extinguish()` to remove our fires. Without this, context menu shows "ignite" even when body is burning.

- **World fires need faster decay**: Entity fires (bodies, props) get sustained by the cremation system, but world fires (ceilings, walls) have no fuel source. World fires must decay 4-5x faster AND have a maximum lifetime (60 seconds) or they burn forever.

- **Cluster batch processing must cap to fire count**: When processing fires in batches, `batchSize = math.min(convar, count)` prevents the loop from processing the same fire multiple times per tick when fire count < batch size.

- **RenderGroup for particles**: Entities rendering particles need `ENT.RenderGroup = RENDERGROUP_TRANSLUCENT` or particles may not render correctly.

### Lua Basics

- **Functions cannot be indexed**: `myFunc.value = x` errors. Use separate local variables for persistent state.

### Item Functions

- **Dead OnRun with custom net handlers**: If OnClick sends a net message to a custom handler, OnRun never executes. Simplify OnRun to `return false`.

- **PlayerUse hooks are SERVER-only useful**: Client callback does nothing. Wrap entire `hook.Add("PlayerUse", ...)` in `if SERVER then`.

- **Helix itemPickupTime**: To pick up an item (when you hold E while looking at it), Helix uses `ix.config.Get ("itemPickupTime", 0.5)` - default 0.5 seconds.

### Workshop Addons

- **.gma filename ≠ workshop ID**: The .gma file inside `workshop/content/4000/<id>/` may have a different name (e.g., `new_camera.gma` not `2898276668.gma`). Always `ls` the folder first to find the actual filename before extracting.

- **Legacy workshop format (_legacy.bin)**: gmad.exe can't extract these. Use GMPublisher (https://github.com/WilliamVenner/gmpublisher) instead.

### Code Organization

- **Custom addons go in `garrysmod/addons/`**: GMod only auto-loads from this path, NOT gamemode folders. `windswept_fire` must be at `garrysmod/addons/windswept_fire/`.

- **Autorun files load alphabetically**: GMod loads `lua/autorun/*.lua` files in alphabetical order. If `api.lua` depends on `init.lua` creating a global table, but "a" comes before "i", you get nil errors. Fix: prefix files with numbers to control order: `00_init.lua`, `01_assets.lua`, `02_api.lua`.

- **Plugins vs schema folders**: Plugins are for **cohesive gameplay systems** (prisoner, permadeath) where related code lives together. General items and weapons that aren't part of a specific system go in `schema/items/` and `entities/weapons/`, not in their own plugin. Don't create a plugin just to hold one item.

- **Item folder structure**: Items organized in domain subdirectories under `schema/items/` (see Architecture tree). Helix auto-loads recursively. **Base file naming**: New folder (e.g., `consumables/`) requires matching `sh_<foldername>.lua` in `items/base/`. Helix adds `base_` prefix automatically. See "Helix auto-assigns ITEM.base" gotcha.

- **Network string centralization**: All schema/entity strings in `sv_netstrings.lua`. Plugin strings stay in plugins. Third-party libs (netstream2) keep their own strings. Never add `util.AddNetworkString()` to entity/item files. Naming: `ixCamelCase` not underscores. GMod has 4096 string limit - centralizing prevents duplicates.

- **Base class pattern for items**: Extract shared logic to `schema/items/base/`:
  - `sh_battery_device.lua` → `base_battery_device` - Battery equipment. Must explicitly set `ITEM.base`.
  - `sh_currency.lua`, `sh_doors.lua`, `sh_clothing.lua` - Auto-assigned by folder name.
  - Stub bases (`sh_equipment.lua`, `sh_locks.lua`, etc.) - Minimal bases for folders without special logic.
  Child items become pure config (~15-30 lines).

### Derma/UI Development

- **NEVER hardcode pixel sizes**: They don't scale across resolutions. ALL UI should be dynamically sized based on content.

- **Dynamic box sizing pattern (PREFERRED)**: Measure content first, then size container to fit:
```lua
function SWEP:DrawHUD()
    local padding = ScreenScale(5)
    local lineSpacing = ScreenScale(2)

    -- 1. Measure all text FIRST
    surface.SetFont("ixSmallFont")
    local line1W, line1H = surface.GetTextSize(text1)
    local line2W, line2H = surface.GetTextSize(text2)

    -- 2. Calculate box size FROM content
    local boxW = math.max(line1W, line2W) + (padding * 2)
    local boxH = line1H + lineSpacing + line2H + (padding * 2)

    -- 3. Position and draw
    local x = (ScrW() - boxW) / 2
    local y = ScrH() * 0.7

    surface.SetDrawColor(30, 30, 30, 200)
    surface.DrawRect(x, y, boxW, boxH)

    -- 4. Draw text at calculated positions
    local textY = y + padding
    draw.SimpleText(text1, "ixSmallFont", ScrW() / 2, textY, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    textY = textY + line1H + lineSpacing
    draw.SimpleText(text2, "ixSmallFont", ScrW() / 2, textY, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end
```

- **ScreenScale() for padding/margins**: `ScreenScale(n)` scales a value based on screen resolution (1080p baseline). Use for all spacing:
```lua
local padding = ScreenScale(5)
local lineSpacing = ScreenScale(2)
```

- **Helix font reference**: `ixBigFont` = 36px, `ixMediumFont` = 25px, `ixSmallFont` = scales with `ScreenScale(6)` minimum 17px. Always use these for consistency.

- **HUD text line spacing**: Use `y + 30` increments for vertical spacing. Progress bars go at next increment after last text:
```lua
draw.SimpleTextOutlined("[STATUS]", "ixMediumFont", pos.x, pos.y, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
draw.SimpleTextOutlined("E: Action", "ixSmallFont", pos.x, pos.y + 30, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
draw.SimpleTextOutlined("Hold LMB: Other", "ixSmallFont", pos.x, pos.y + 60, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
local barY = pos.y + 90  -- Progress bar after all text

-- For conditional lines, use yOffset pattern:
local yOffset = 30
if showExtra then
    draw.SimpleTextOutlined("Extra", "ixSmallFont", pos.x, pos.y + yOffset, color, ...)
    yOffset = yOffset + 30
end
local barY = pos.y + yOffset  -- Progress bar after all conditional text
```

- **Button width from text**: Measure the longest button label, add padding:
```lua
surface.SetFont("ixSmallFont")
local maxTextW = math.max(surface.GetTextSize("Cancel"), surface.GetTextSize("Confirm"))
local buttonWidth = maxTextW + ScreenScale(10) * 2
```

- **Helix auto-includes `schema/derma/`**: Files in this folder are automatically loaded by the framework (via `ix.util.IncludeDir` in sh_plugin.lua). No manual includes needed.

## Third-Party Addon Configuration

### TFA Base (Workshop ID: 2840031720)

**Inspection Menu Disabled**: The TFA weapon inspection menu (opens when pressing C while holding a TFA weapon) is disabled via `sv_tfa_cmenu 0` in `sv_schema.lua`.

**Why disabled:**
- Shows exact weapon stats (accuracy, damage, fire rate) - violates fog of war principle
- Displays ammo type selector allowing players to swap between ammo types they don't physically have - violates scarcity principle (nothing appears from nowhere, conservation of matter)
- Shows damage drop-off graphs - too much metagame information

**Result:** Pressing C while holding a TFA weapon now opens the normal GMod context menu instead of the TFA inspection panel.

**ConVar reference** (from `tfa/modules/tfa_commands.lua`):
- `sv_tfa_cmenu` - Enable/disable inspection menu (default: 1, we set to 0)
- `sv_tfa_cmenu_key` - Override inspection key (-1 = use default C key)

**Extracted addon location:** `D:/SteamLibrary/steamapps/workshop/content/4000/2840031720/extracted/`

## Persistence & Save Files

Custom systems that persist data across server restarts save JSON files to `garrysmod/data/helix/<system>/<mapname>.json`. To reset a system to its default/bootstrap state, delete its save file:

| System | Save File Location |
|--------|-------------------|
| Doors | `data/helix/doors/gm_windswept.json` |

**Full path example:** `D:/SteamLibrary/steamapps/common/GarrysMod/garrysmod/data/helix/doors/gm_windswept.json`

When a save file is missing, systems typically run a bootstrap function to initialize default state (e.g., `ix.doors.BootstrapDefaultDoors()` spawns all map doors on first run).

**When to delete save files:**
- After major refactors that change data structure
- To test fresh bootstrap behavior
- When saved state becomes corrupted or inconsistent

## Quick Notes from the Human Developer

- **Use ripgrep (rg) instead of grep (grep)**. Ripgrep is way faster than grep, and you know that.

- **How I give items to myself when in game playing**: If we make a new item, to test it in game, I'll write into the text chat bar: /chargiveitem playername item quantity.

- **Use developer.valvesoftware.com docs**: Invaluable for Source Engine features (e.g., Prop_door_rotating wiki helped with door system).