# Windswept

## Project Overview

A Garry's Mod SeriousRP gamemode set in 2200 on Zephyrus, a hostile mining planet. Players work in Redrock City, a carbon mining colony owned by Eagle Extraction Conglomerate (EEC). The Carbon Miners Union (CMU-RC) controls mine access. Currency: CEG Dollars ($50).

**Map:** Windswept | **Framework:** Helix (Nutscript fork)

## Architecture

```
windswept/
├── schema/                  # Core gamemode code
│   ├── sh_schema.lua        # Main shared entry point (includes libs here!)
│   ├── cl_schema.lua        # Client entry point
│   ├── sv_schema.lua        # Server entry point
│   ├── sv_netstrings.lua    # Centralized network string registry
│   ├── sh_constants.lua     # Centralized constants (ix.constants)
│   ├── sh_hooks.lua         # Shared hooks
│   ├── cl_hooks.lua         # Client hooks
│   ├── sv_hooks.lua         # Server hooks
│   ├── factions/            # Faction definitions
│   ├── classes/             # Class definitions
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
│   ├── libs/                # Custom libraries (MUST be included in sh_schema.lua)
│   │   ├── sh_birthdata.lua # Birth date/age system
│   │   ├── sh_physical.lua  # Physical appearance system
│   │   ├── sh_doors.lua     # Door system library
│   │   ├── sh_wallet.lua    # Wallet/currency library
│   │   └── thirdparty/      # Third-party libs
│   │       └── sh_netstream2.lua
│   ├── languages/           # Localization
│   └── meta/                # Metatable extensions
├── plugins/                 # Modular features
│   ├── permadeath/          # Knockout/death/revival system
│   ├── factions/            # Faction management, elections, classes
│   └── prisoner/            # Arrest/detention system
├── entities/
│   ├── entities/            # Custom entities
│   └── weapons/             # Custom weapons (SWEPs)
└── gamemode/                # Helix gamemode loader
```

## Reference Codebases

- D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\gamemodes\helix is **OUR framework** - not a dependency. We forked it and own it completely. Edit it directly whenever needed. The original Helix is unmaintained on GitHub anyway. Don't create workarounds or overrides when you can just fix it in Helix itself.

- D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\gamemodes\helix-hl2rp is a fully implemented Half-Life 2 RP gamemode using the Helix framework. Great implementation reference. MIT License.

## Lore Details

- The year is 2200. The Confederation of Earthly Governments (CEG) licenses uninhabited planets to mining corporations. Zephyrus is one such planet - hostile, dangerous, but rich in known Carbon reserves just underneath the surface of the planet.

- EEC: Eagle Extraction Conglomerate (the owners of the mine in this colony, Redrock City)

- The reason this colony exists is due to the massive reserves of pure carbon underneath the surface. The EEC operates a massive mine-colony here, exporting high-grade carbon from this colony to be used by humanity elsewhere (the solar system, other colonized locations). Like how Cuba was a massive sugar colony for Europe and America, Redrock City is a massive carbon mining colony for the human market. The EEC owns all the mines and has an agreement with the Miners Union that, officially, only union members are allowed access to the mines, meaning only union members (members of the CMU-RC, Carbon Miners Union-Redrock City) are allowed to extract the carbon, reaping the benefit for them and the union.

- Redrock City is where the gameplay takes place. It is a mining-colony right underneath the surface of Zephyrus. 

### Primary Roles (No term limits)
| Role | Appointment Type | Term Length | Description |
|------|------------------|-------------|-------------|
| Mayor | Elected | 3 weeks (21 days) | The Mayor of Redrock City is elected by the citizens of Redrock City every three weeks. The Mayor is the Chief Executive of the Redrock City Administration. |
| Commissioner | Elected | 3 weeks (21 days) | The Commissioner of the Redrock City Security Department is the Chief Executive of the city security arm, responsible for policing the city. Elected every 3 weeks by the citizens of Redrock City. |
| Miners Union President | Elected | 3 weeks (21 days) | The President is elected by all members of the miners union every 3 weeks and is responsible for representing the miners and the miners union, and is its Chief Executive of the CMU-RC. |

### Secondary Roles
| Role | Description |
|------|-------------|
| Deputy Mayor | The Deputy Mayor of Redrock City is appointed by the Mayor. |
| Deputy Commissioner | The Deputy Commissioner of the Redrock City Security Department is appointed by the Commissioner. |
| Chief Medical Officer | The Chief Medical Officer is in charge of the Redrock City Medical Department, overseeing the operations at Redrock City General Hospital and all medical-related affairs on Redrock City. The CMO is directly appointed by the Mayor, and can be recalled at any time. |
| Warden | The Warden is in charge of the Redrock City Corrections Department, overseeing operations at Skarn Prison. The Warden is directly appointed by the Commissioner.
| Fire Chief | The Fire Chief is in charge of the Redrock City Fire Brigade, and is appointed by the Mayor. |

## Design Principles

- Fog of War principle. Because this is SeriousRP, nothing is free. Here's an example that will tell you a lot. The defibrillator has a 45-95% chance of successfully reviving someone that has been knocked and is actively dying. The player DOES NOT KNOW of the 45-95% chance at all, the player only knows (from experience, from seeing others, from being told, from intuition) that it has decent odds but can fail just as easily. The backend knows its between 45-95% chance (we call it probability^2, it's not guaranteed that the defib will pass or fail, AND the chance itself is also not guaranteed, it can be anywhere from a 45% odds of succeeding to a 95% odds of succeeding, but never 100%). Nothing is 100% certain, ever. This is another principle of good SeriousRP.

- Always be Helix-idiomatic. Before implementing any feature, check if Helix already provides it or has an established pattern for it. Read the framework source code in helix/gamemode/core/ to understand how things are done. For example, when we created custom character creation panels, we initially added our own labels and height logic, but Helix already auto-creates labels above OnDisplay panels and uses font-based height sizing (see ixTextEntry and ixNumSlider in cl_generic.lua). Following existing patterns avoids bugs and keeps code consistent.

- All characters are created **factionless** by default (no faction assignment). Personal IDs are given to ALL new characters via the `OnCharacterCreated` hook in `sv_schema.lua`. Players join factions (Medical, Security, Corrections, Miners Union, etc.) through in-game faction transfers (`/PlyTransfer`) after their character exists. Factionless characters appear in the "Unaffiliated" section of the scoreboard and use `TEAM_UNASSIGNED` (0) in Source Engine. Citizenship is an RP concept tracked by players, not a faction.

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

- **Network String Registry** (`schema/sv_netstrings.lua`): All schema and entity network strings are centralized here. This file is included by sv_schema.lua and registers 60 strings for:
  - Currency system (ixMoneyDestroy, ixMoneyGive, ixCurrencySplit, etc.)
  - Photo system (ixPhotoRename, ixPhotoRequest, ixPhotoAlbumView, etc.)
  - Door system (ixDoorsSync, ixDoorInstall, etc.)
  - Lock system (ixLockInstall, ixLockpickStart, ixKeyringLock, etc.)
  - Equipment (ixFlashlightSetLight, ixLanternSetLight, ixCameraRequestPhoto, etc.)
  - Locksmith machine (ixLocksmithOpen, ixLocksmithProgramLock, etc.)

  Plugin strings remain in their plugins: permadeath (10), factions (13), prisoner (10).

- **Door & Lock System**: Physical lock and key system replacing Helix's door ownership. Key points:
  - **Brush-based doors are ignored**: Doors with models starting with `*` (func_door, func_door_rotating) are skipped by the entire system - detection, tools, battering ram, everything. Only `prop_door_rotating` doors are managed.
  - **Double door linking**: After spawning, doors are linked via `ixPartner` based on `targetname`/`slavename` keyvalues. This enables Helix's `GetDoorPartner()` to work for lock sync and breach sync.
  - **Lock sync for double doors**: `InstallLock()`, `RemoveLock()`, `LockDoor()`, `UnlockDoor()`, and `DamageLock()` all sync to partner doors automatically. Install a lock on one door, both doors get it.
  - **Breach = permanent destruction**: `ix.doors.BreachDoor()` permanently destroys the door with debris gibs and particle effects. The door is gone - frame is empty until a new door is installed. No restore, no respawn.
  - **Battering ram hit counter persists**: When a door is hit, the hit counter (`ixBatteringRamRequired`, `ixBatteringRamHits`) persists until the door is **repaired** or **destroyed**. No time-based reset. Saved to persistence file.
  - **Repair resets damage**: `ix.doors.RepairDoor()` resets health AND clears the battering ram hit counter.

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

- **Missing library include**: Helix does NOT auto-include files in `schema/libs/`. Add `ix.util.Include("libs/your_file.lua")` to sh_schema.lua for every lib file. Missing includes cause silent nil returns.

- **Hook data flow in character creation**: In hooks like `AdjustCreationPayload`, Helix's OnAdjust functions run BEFORE your hook and populate `newPayload` with processed values. Use `newPayload.model` (the path) not `payload.model` (the index).

- **Weapon equip data key is "equip" not "equipped"**: The base_weapons item uses `item:GetData("equip")` and `item:SetData("equip", true/nil)`. Do NOT use `"equipped"` - that's a different key used by some custom items (like Personal ID). Using the wrong key causes `CanTransfer` to block operations with "You cannot move a weapon that is currently equipped!"

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

- **CharacterLoaded vs PlayerLoadedCharacter execution order**: These hooks run in a specific order during character loading:
  1. `character:Setup()` → calls `CharacterLoaded` hook
  2. `client:Spawn()`
  3. `GM:PlayerLoadedCharacter()` → creates Helix salary timer here
  4. `PlayerLoadedCharacter` hook (hook.Add listeners)

  **Critical for timer overrides**: If you need to remove/replace Helix's salary timer (`ixSalary..steamID64`), you MUST use `PlayerLoadedCharacter` hook, NOT `CharacterLoaded`. The timer doesn't exist yet when `CharacterLoaded` runs, so `timer.Remove()` does nothing, and both timers run = double salary.
  ```lua
  -- WRONG: CharacterLoaded runs BEFORE Helix creates its timer
  hook.Add("CharacterLoaded", "myHook", function(character)
      timer.Remove("ixSalary" .. character:GetPlayer():SteamID64())  -- Does nothing!
  end)

  -- CORRECT: PlayerLoadedCharacter runs AFTER Helix's GM function
  hook.Add("PlayerLoadedCharacter", "myHook", function(client, character, lastChar)
      timer.Remove("ixSalary" .. client:SteamID64())  -- Timer exists, removal works
  end)
  ```

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

- **Worldmodel not visible in third person**: Workshop prop models used as SWEP world models lack proper bone attachments - the model won't render on the player's hand automatically. Fix: Override `DrawWorldModel()` on CLIENT to manually position using `owner:LookupBone("ValveBiped.Bip01_R_Hand")` and `GetBoneMatrix()`, then offset with `ang:Forward()/Right()/Up()` and rotate with `RotateAroundAxis()`. Offset values require trial and error to position correctly in the grip. See `entities/weapons/ix_personalid.lua` or `plugins/prisoner/entities/weapons/ix_gavel.lua` for working examples.

- **Entity/weapon naming conflict**: Don't name a scripted entity the same as a weapon class. If weapon `ix_lantern` exists, an entity named `ix_lantern` will have broken NetworkVars (SetupDataTables doesn't register methods properly). Use distinct names like `ix_lantern` (weapon) and `ix_lantern_dropped` (entity).

- **SWEP.Drop = false is intentional**: All custom SWEPs use `SWEP.Drop = false` to prevent GMod's native weapon drop (which creates raw weapon entities). Instead, the permadeath system handles drops via `item:Transfer()` in `CreateKnockout()`, which properly creates Helix item entities that preserve all item data. When a player is knocked while holding an item, only the actively held weapon drops - other equipped items stay in inventory. Protected weapons (ix_hands, ix_handsup) never drop.

- **Equip data key inconsistency**: Helix's `base_weapons` uses `"equip"` while custom items (flashlight, binoculars, camera, etc.) use `"equipped"`. When writing code that handles both (like knockout drops), clear BOTH keys: `item:SetData("equip", nil)` and `item:SetData("equipped", nil)`.

- **TFA/addon weapon models have broken collision for item pickup**: Workshop weapon models (TFA, M9K, CW, etc.) are designed as weapon attachments, not physics props. Their collision meshes are often razor-thin (1-2 units) because collision doesn't matter when attached to a player's hand. When used as Helix items dropped on the ground, eye traces can't hit them → no tooltip, no pickup. Fix is in `ix_item.lua`: detect thin collision bounds (<4 units in any dimension), replace with OBB-based fallback box physics, and use `COLLISION_GROUP_WEAPON` to prevent trapping players.

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

- **Double door synchronization**: Double doors use `targetname`/`slavename` to sync. The master door's `slavename` references the slave door's `targetname`. Without capturing BOTH keyvalues when replacing map doors, double doors will open/close independently and may open in opposite directions.

- **ixPartner vs targetname/slavename**: Source Engine uses `targetname`/`slavename` keyvalues for engine-level door sync (open/close together). Helix uses `door.ixPartner` (a Lua property) for Lua-level partner lookup (`GetDoorPartner()`). These are SEPARATE systems. Setting keyvalues does NOT set `ixPartner`. If you spawn doors with keyvalues but don't set `ixPartner`, Helix functions like `BlastDoor()` won't find partners. Our `ix.doors.LinkPartners()` builds `ixPartner` links after spawning by matching `slavename` to `targetname`.

- **Door handles are NOT separate entities**: They're part of the door model, controlled by the `hardware` keyvalue and model bodygroups. The model has a "handle" bone that can be queried via `LookupBone("handle")`.

- **Brush-based doors vs prop-based doors**: Source maps have two door types. `prop_door_rotating` uses model files (`models/props/door01.mdl`). `func_door`/`func_door_rotating` use brush geometry with models like `*90`, `*57` - these are BSP brush references. You CANNOT spawn a prop entity with a brush model (`ent:SetModel("*90")` fails with "CBreakableProp::Spawn - GetModelPtr returned NULL!"). When detecting map doors with `ent:IsDoor()`, check if the model starts with `*` and skip those - they can't be replaced with prop entities.

- **MapIO infinite loop warnings**: Firing events (`door:Fire("unlock")`) on map entities can trigger I/O chains. If the map has circular I/O connections, Source emits "Breaking out of potential MapIO infinite loop!" warnings. This is map design, not a code bug - Source is protecting itself.

- **Door lock/unlock sounds**: Use `doors/door_latch3.wav` for locking (heavier click) and `doors/door_latch1.wav` for unlocking (lighter click).

### GMod Networking

- **64KB net message limit**: `net.WriteData()` and `net.WriteString()` cap at ~64KB. Reduce data at source (smaller images, lower quality) rather than chunking.

- **Global variable race conditions**: `ix.someData = value` gets overwritten when multiple players trigger simultaneously. Use tables keyed by unique ID: `ix.someData[requestID] = value`.

### Rendering

- **render.Capture() requires render context**: Cannot call from Think(), timers, or net receivers. Must use `hook.Add("PostRender", ...)`.

- **Frame timing for HUD-free captures**: Hiding HUD takes effect NEXT frame. Skip one frame before capturing: set flag, return early first PostRender call, capture on second.

- **light_dynamic networks to clients**: Server-created dynamic lights DO illuminate client scenes. Brief delay (~50ms) ensures entity networks before dependent actions.

### Lua Basics

- **Functions cannot be indexed**: `myFunc.value = x` errors. Use separate local variables for persistent state.

### Item Functions

- **Dead OnRun with custom net handlers**: If OnClick sends a net message to a custom handler, OnRun never executes. Simplify OnRun to `return false`.

- **PlayerUse hooks are SERVER-only useful**: Client callback does nothing. Wrap entire `hook.Add("PlayerUse", ...)` in `if SERVER then`.

- **Helix itemPickupTime**: To pick up an item (when you hold E while looking at it), Helix uses `ix.config.Get ("itemPickupTime", 0.5)` - default 0.5 seconds.

### Workshop Addons

- **.gma filename ≠ workshop ID**: The .gma file inside `workshop/content/4000/<id>/` may have a different name (e.g., `new_camera.gma` not `2898276668.gma`). Always `ls` the folder first to find the actual filename before extracting.

- **Legacy workshop format (_legacy.bin)**: Some older workshop addons use `_legacy.bin` files instead of `.gma`. The gmad.exe tool cannot extract these. Fix: Use GMPublisher (https://github.com/WilliamVenner/gmpublisher) - open the legacy.bin file and extract from there.

### Code Organization

- **Plugins vs schema folders**: Plugins are for **cohesive gameplay systems** (prisoner, permadeath) where related code lives together. General items and weapons that aren't part of a specific system go in `schema/items/` and `entities/weapons/`, not in their own plugin. Don't create a plugin just to hold one item.

- **Item folder structure**: Items are organized into domain-based subdirectories under `schema/items/`:
  - `base/` - Base classes that other items inherit from
  - `clothing/` - Clothing outfits (casual, work, uniforms)
  - `currency/` - Money items (cash, coins, wallet)
  - `documents/` - ID cards, photos, albums
  - `doors/` - Installable door items
  - `equipment/` - Tools and devices (flashlight, camera, etc.)
  - `locks/` - Lock system items (keys, locks, lockpick, toolkit)
  - `materials/` - Crafting materials
  - `misc/` - Miscellaneous items
  - `weapons/` - Ammo and weapon items

  Helix auto-loads items recursively from all subdirectories, so no code changes are needed when moving files.

  **IMPORTANT - Base file naming**: When you create a new item folder (e.g., `consumables/`), you MUST also create a matching base file named `sh_<foldername>.lua` (e.g., `sh_consumables.lua`) in `items/base/`. Helix automatically adds `base_` prefix when loading from the base folder, so `sh_consumables.lua` becomes `base_consumables`. See the "Helix auto-assigns ITEM.base" gotcha above.

- **Network string centralization**: All schema and entity network strings are registered in `schema/sv_netstrings.lua`. Plugin network strings (permadeath, factions, prisoner) remain in their respective plugins for modularity.
  - **Never add `util.AddNetworkString()` to entity or item files** - add them to sv_netstrings.lua instead
  - **Naming convention**: Use `ixCamelCase` (e.g., `ixFlashlightSetLight`), NOT underscores (`ix_flashlight_SetLight`)
  - Third-party libs (netstream2) keep their own strings
  - GMod has a 4096 network string limit - centralizing prevents duplicates and makes auditing easy

- **Base class pattern for items**: When multiple items share significant logic, extract a base class to `schema/items/base/`:
  - `sh_battery_device.lua` → `base_battery_device` - For battery-powered equipment (flashlight, lantern, camera, defibrillator). Items must explicitly set `ITEM.base = "base_battery_device"` to use this.
  - `sh_currency.lua` → `base_currency` - For stackable currency (cash, coins). Auto-assigned to items in `currency/` folder.
  - `sh_doors.lua` → `base_doors` - For installable door items. Auto-assigned to items in `doors/` folder.
  - `sh_clothing.lua` → `base_clothing` - For clothing items. Auto-assigned to items in `clothing/` folder.
  - Stub bases (`sh_equipment.lua`, `sh_locks.lua`, etc.) - Minimal bases for folders that don't need special shared logic.

  Child items become pure configuration (~15-30 lines) instead of duplicating hundreds of lines of logic.

### Derma/UI Development

- **NEVER hardcode pixel sizes**: Treat hardcoded pixel values like magic numbers in web dev - they don't scale across resolutions and lead to "pixel whack-a-mole" debugging. ALL UI should be dynamically/responsively sized based on content.

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

- **HUD text line spacing**: When drawing multiple lines of HUD text (status indicators, action hints, etc.), use `y + 30` for consistent vertical spacing between lines. Progress bars should be placed at the next `+ 30` increment after all text to avoid overlap:
```lua
-- Standard HUD text + progress bar spacing pattern
draw.SimpleTextOutlined("[STATUS]", "ixMediumFont", pos.x, pos.y, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
draw.SimpleTextOutlined("E: Action", "ixSmallFont", pos.x, pos.y + 30, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
draw.SimpleTextOutlined("Hold LMB: Other", "ixSmallFont", pos.x, pos.y + 60, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
-- Progress bar at pos.y + 90 (next increment after last text line)
local barY = pos.y + 90

-- Or with yOffset for conditional lines:
local yOffset = 30
if showExtra then
    draw.SimpleTextOutlined("Extra", "ixSmallFont", pos.x, pos.y + yOffset, color, ...)
    yOffset = yOffset + 30
end
draw.SimpleTextOutlined("Next Line", "ixSmallFont", pos.x, pos.y + yOffset, color, ...)
-- Progress bar after all text
local barY = pos.y + yOffset + 30
```

- **Button width from text**: Measure the longest button label, add padding:
```lua
surface.SetFont("ixSmallFont")
local maxTextW = math.max(surface.GetTextSize("Cancel"), surface.GetTextSize("Confirm"))
local buttonWidth = maxTextW + ScreenScale(10) * 2
```

- **Helix auto-includes `schema/derma/`**: Files in this folder are automatically loaded by the framework (via `ix.util.IncludeDir` in sh_plugin.lua). No manual includes needed.

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

- **Use developer.valvesoftware.com docs**: Use whenever you need help with anything like for example when we were implementing custom doors entity we read through https://developer.valvesoftware.com/wiki/Prop_door_rotating and it really helped us solve the problems with all the doors on the map