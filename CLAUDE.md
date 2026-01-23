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
│   ├── sh_hooks.lua         # Shared hooks
│   ├── cl_hooks.lua         # Client hooks
│   ├── sv_hooks.lua         # Server hooks
│   ├── factions/            # Faction definitions
│   ├── classes/             # Class definitions
│   ├── items/               # Item definitions
│   ├── attributes/          # Character attributes
│   ├── derma/               # Custom UI panels
│   ├── libs/                # Custom libraries (MUST be included in sh_schema.lua)
│   │   ├── sh_birthdata.lua # Birth date/age system
│   │   ├── sh_physical.lua  # Physical appearance system
│   │   └── thirdparty/      # Third-party libs
│   ├── languages/           # Localization
│   └── meta/                # Metatable extensions
├── plugins/                 # Modular features
│   ├── permadeath/          # Knockout/death/revival system
│   └── prisoner/            # Arrest/detention system
├── entities/
│   ├── entities/            # Custom entities
│   └── weapons/             # Custom weapons
└── gamemode/                # Helix gamemode loader
```

## Reference Codebases

- D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\gamemodes\helix is the path for the framework that we are using to build this, it's locally cloned so we can edit it however we want. If you ever need to read the source code of the framework, just go to that path and all the source code is there for you to read and adjust however we want. It is MIT License.

- D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\gamemodes\helix-hl2rp is the path for a fully implemented Half-Life 2 RP gamemode in Garry's Mod using the Helix framework. We can reverse engineer it however we want, it is a great implementation example and you can read its source code. It is MIT License.

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

- All characters are created as Civilians (the default faction). Personal IDs are given (spawned into inventory upon character creation) only during Civilian character creation because every character starts there. Players join other factions (Medical, Security, Corrections, etc.) through in-game faction transfers after their character exists - no one is created directly into a non-Civilian faction.

## Game Systems

- Currency: CEG Dollar, written as "$50" or "50 dollars". The dollar is the standard currency used throughout CEG-controlled space.

- For the battery system, "up" stands for "units of power", so a 100up battery has 100 units of power. Device drain rates vary: flashlight ~0.083up/sec (20 min per battery), lantern ~0.167up/sec (10 min per battery). Batteries are universal across all devices (defibrillator, flashlight, camera, lantern, etc.).

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

- **HOOKS_CACHE execution order**: Helix hook execution order: (1) HOOKS_CACHE plugin hooks, (2) Schema hooks, (3) Regular hook.Add hooks. To run before a Helix plugin, inject into HOOKS_CACHE directly. See ix_camera.lua lines 220-265.

- **ITEM.isBag auto-opens "View"**: When `ITEM.isBag = true`, Helix auto-calls the "View" function on inventory open. Rename custom viewers to something else (e.g., "Browse") and keep "View" for the standard bag panel.

- **CanTransferItem hook name**: The hook is `CanTransferItem`, NOT `CanItemBeTransfered`. Wrong name = silent failure.

- **Inventory sync overflow**: Storing >10KB in item data via `item:SetData()` causes "Trying to send an overflowed net message" during inventory sync. Fix: File-based storage in `data/` folder, store only ID reference in item.

- **item:GetInventory() doesn't exist**: Helix items don't have a direct `GetInventory()` method. To get an item's inventory, go through the owner: `client:GetCharacter():GetInventory()`.

- **WeaponEquip hook fires during Give()**: When calling `client:Give("weapon_class")`, the `WeaponEquip` hook fires immediately during that call, not after. If you're tracking equipped items with variables like `client.ixItem = item`, set them BEFORE `Give()`, not after, or the hook won't see them.

### SWEP/Weapon Development

- **Item-only vs Item+SWEP**: If using an existing weapon class (TFA, HL2, CSS), the item just needs `ITEM.base = "base_weapons"` and `ITEM.class = "tfa_ins2_wpn_38revolver"` - no custom SWEP file needed. Only create a custom SWEP (`entities/weapons/ix_*.lua`) when you need custom behavior (battery drain, special actions, etc.). Examples: Model 10 revolver uses TFA's class directly (item only); flashlight/camera need custom battery logic (item + SWEP).

- **SWEP:CreateMove() doesn't exist**: Not a valid SWEP method. Use `hook.Add("CreateMove", ...)` globally and check `LocalPlayer():GetActiveWeapon()` inside.

- **PrimaryAttack/SecondaryAttack are SERVER-only in Helix**: Helix only calls these on SERVER. For client-side input, detect in Think() using `input.IsMouseDown()` with edge detection (`self.wasLMBDown`).

- **SWEP:Think() runs on both realms**: Server has no input context, so `owner:KeyDown()` returns false server-side, causing state flicker. Wrap all input logic in `if CLIENT then`.

- **c_model vs v_model for UseHands**: GMod's `SWEP.UseHands = true` requires a c_model (weapon only, no arms). v_models have arms baked in and won't work with dynamic hands. Use `models/weapons/xxx/c_weapon.mdl` not `v_weapon.mdl`.

- **SWEP properties don't network to client**: Setting `weapon.ixItem = item` on SERVER doesn't make it available on CLIENT. The client's SWEP copy has no knowledge of server-set properties. Fix: Client must find the data another way - look up equipped item from inventory, use networked vars, or send via net message.

- **Worldmodel not visible in third person**: Workshop prop models used as SWEP world models lack proper bone attachments - the model won't render on the player's hand automatically. Fix: Override `DrawWorldModel()` on CLIENT to manually position using `owner:LookupBone("ValveBiped.Bip01_R_Hand")` and `GetBoneMatrix()`, then offset with `ang:Forward()/Right()/Up()` and rotate with `RotateAroundAxis()`. Offset values require trial and error to position correctly in the grip. See ix_personalid.lua and ix_gavel.lua for working examples.

- **Entity/weapon naming conflict**: Don't name a scripted entity the same as a weapon class. If weapon `ix_lantern` exists, an entity named `ix_lantern` will have broken NetworkVars (SetupDataTables doesn't register methods properly). Use distinct names like `ix_lantern` (weapon) and `ix_lantern_dropped` (entity).

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

### Derma/UI Development

- **NEVER hardcode pixel sizes**: Treat hardcoded pixel values like magic numbers in web dev - they don't scale across resolutions. Always derive sizes from font metrics or use `ScreenScale()`.

- **Font-based sizing pattern**: Measure text to determine element dimensions:
```lua
surface.SetFont("ixBigFont")
local textW, textH = surface.GetTextSize("0")
local digitBoxSize = math.max(textW, textH) + ScreenScale(12)  -- Content + padding
```

- **ScreenScale() for padding/margins**: `ScreenScale(n)` scales a value based on screen resolution (1080p baseline). Use for all spacing:
```lua
self.padding = ScreenScale(8)
self.buttonHeight = textHeight + ScreenScale(10)
```

- **Helix font reference**: `ixBigFont` = 36px, `ixMediumFont` = 25px, `ixSmallFont` = scales with `ScreenScale(6)` minimum 17px. Always use these for consistency.

- **Calculate panel size from content**: Don't set arbitrary panel dimensions. Calculate based on what's inside:
```lua
local contentWidth = (elementSize * count) + (spacing * (count - 1))
local panelWidth = contentWidth + (padding * 2)
self:SetSize(panelWidth, calculatedHeight)
```

- **Button width from text**: Measure the longest button label, add padding:
```lua
surface.SetFont("ixSmallFont")
local maxTextW = math.max(surface.GetTextSize("Cancel"), surface.GetTextSize("Confirm"))
local buttonWidth = maxTextW + ScreenScale(10) * 2
```

- **Helix auto-includes `schema/derma/`**: Files in this folder are automatically loaded by the framework (via `ix.util.IncludeDir` in sh_plugin.lua). No manual includes needed.
