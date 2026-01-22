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

- For the battery system, "up" stands for "units of power", so a 100up battery has 100 units of power. A flashlight can hold 1 battery, and consumes about ~0.167up per second when on (~10 minutes per full battery). This should give you a relatively good idea how that system works. Batteries are universal, so all devices that take batteries (defibrillator, flashlight, camera, etc. use the same batteries and units of power measuring system).

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

- Missing library include problem: Helix does NOT auto-include files in schema/libs/ - they must be explicitly added to sh_schema.lua via ix.util.Include(). If a library file exists but isn't included, its functions will be undefined and calls will silently return nil. Fix: Always add ix.util.Include("libs/your_file.lua") to sh_schema.lua for every lib file you create. Example: sh_physical.lua existed but wasn't included, so ix.physical.IsFemaleModel() returned nil, causing all sex checks to default to "M".

- Helix hook data flow: In character creation hooks like AdjustCreationPayload, Helix's built-in OnAdjust functions run BEFORE your hook and populate newPayload with processed values. Don't re-derive values that Helix already computed - use them from newPayload instead. Example: payload.model contains the model INDEX (e.g., 10), but Helix's model OnAdjust already converts this to the actual path and stores it in newPayload.model (e.g., "models/player/group01/female_04.mdl"). We were manually looking up models[payload.model] when newPayload.model already had the correct path.

- Lua functions cannot be indexed: In Lua, local functions are not tables, so you cannot store properties on them like `myFunc.someValue = x`. This causes "attempt to index upvalue (a function value)" errors. Fix: Use a separate local variable declared outside the function to store persistent state. Example: Instead of `local function GetThing(ent) if GetThing.lastEnt ~= ent then GetThing.lastEnt = ent end end`, use `local lastEnt = nil; local function GetThing(ent) if lastEnt ~= ent then lastEnt = ent end end`.

- SWEP:CreateMove() doesn't exist: This is NOT a valid SWEP method in GMod. The function will never be called. For scroll wheel or input command handling, use `hook.Add("CreateMove", "YourHookName", function(cmd) ... end)` as a global hook instead. Check for your weapon with `LocalPlayer():GetActiveWeapon()` inside the hook. Example: In ix_camera.lua, we initially wrote `function SWEP:CreateMove(cmd) local wheel = cmd:GetMouseWheel() ... end` expecting it to handle scroll wheel zoom. Debug showed CreateMove was never called. Fix: Changed to `hook.Add("CreateMove", "ixCameraZoom", function(cmd) local weapon = LocalPlayer():GetActiveWeapon() if IsValid(weapon) and weapon:GetClass() == "ix_camera" then ... end end)`.

- Helix doesn't call PrimaryAttack/SecondaryAttack on CLIENT: Helix's weapon system only calls these functions on SERVER, not CLIENT. This means `if CLIENT then` blocks inside PrimaryAttack will never execute, and net.SendToServer() calls won't fire. Fix: For client-side actions (like sending net messages to request server validation), detect input in Think() using `input.IsMouseDown(MOUSE_LEFT)` or `input.IsMouseDown(MOUSE_RIGHT)` instead. Track previous state with `self.wasLMBDown` to detect rising edges. Example: In ix_camera.lua, we had `function SWEP:PrimaryAttack() if CLIENT then net.Start("ixCameraRequestPhoto") net.SendToServer() end end`. Debug showed `CLIENT: false SERVER: true` - only server ran it. Fix: Moved LMB detection to Think() with `if self:GetAiming() then local lmbDown = input.IsMouseDown(MOUSE_LEFT) if lmbDown and not self.wasLMBDown then net.Start("ixCameraRequestPhoto") net.SendToServer() end self.wasLMBDown = lmbDown end`.

- SWEP:Think() runs on both CLIENT and SERVER: If you check player input like `owner:KeyDown(IN_ATTACK2)` without a realm guard, the server will also run this check - but server has no input context, so KeyDown() returns false. This causes rapid state flickering between client (true) and server (false). Fix: Wrap all input-checking logic in `if CLIENT then ... end` blocks. Example: In ix_camera.lua, we had `function SWEP:Think() local shouldAim = owner:KeyDown(IN_ATTACK2) if shouldAim ~= self:GetAiming() then self:SetAiming(shouldAim) end end`. Debug showed rapid flickering: `aiming changing from false to true CLIENT: true` then `aiming changing from true to false CLIENT: false` - the server was resetting it every frame. Fix: Wrapped the entire input block in `if CLIENT then ... end`.

- Helix HOOKS_CACHE runs before regular hooks: Helix overrides `hook.Call` with custom execution order: (1) HOOKS_CACHE plugin hooks, (2) Schema hooks, (3) Regular hook.Add hooks. If you need your hook to run BEFORE a Helix plugin (like blocking wepselect's scroll wheel handling), inject directly into HOOKS_CACHE instead of using hook.Add. Example: In ix_camera.lua, we needed to block wepselect from consuming scroll wheel while camera was scoped. Using `hook.Add("PlayerBindPress", ...)` didn't work because wepselect's HOOKS_CACHE hook ran first and returned true, consuming the input. Fix: Inject directly into HOOKS_CACHE with `HOOKS_CACHE["PlayerBindPress"][cameraInputPlugin] = function(self, client, bind, pressed) ... return true end`. See ix_camera.lua lines 235-265 for the full implementation.

- GMod net message 64KB limit: `net.WriteData()` and `net.WriteString()` have a ~64KB limit per message. Exceeds cause "net.WriteData: Invalid length X!" error. Fix: For large data like images, reduce size at source (e.g., cap image dimensions, lower JPEG quality) rather than trying to chunk. Example: Camera initially captured full-res screenshots (~500KB base64). Fix: Capped capture to 512x512 with quality 60, producing ~20-35KB which fits comfortably.

- Helix inventory sync overflow: Storing large data (>10KB) directly in item data via `item:SetData()` causes "Trying to send an overflowed net message" when Helix syncs inventory to clients. This happens because Helix sends ALL item data during inventory sync. Fix: Use file-based storage - save large data to `data/` folder with `file.Write()` and store only a small ID reference in the item. Example: Camera photos stored ~25KB base64 in item data, crashing inventory sync. Fix: Save image to `data/ix_photos/<id>.txt`, store only `photoID = "1234567890_54321"` in item, fetch file on demand when viewing.

- render.Capture() requires render context: `render.Capture()` cannot be called from Think(), timers, or net receivers - it must run during an active render pass. Fix: Use `hook.Add("PostRender", "YourHook", function() ... end)` to capture. Example: Camera tried `timer.Simple(0.1, function() render.Capture(...) end)` which returned nil. Fix: Schedule capture in PostRender hook.

- Frame timing for HUD-free captures: When hiding HUD elements before `render.Capture()`, the current frame has ALREADY drawn the HUD. The hide flag only takes effect next frame. Fix: Skip one frame before capturing. Example: Set `self.hidingHUD = true` and `self.captureNextFrame = true`, then in PostRender: `if self.captureNextFrame then self.captureNextFrame = false return end` to skip the first frame, then capture on the second.

- Global variable race conditions in multiplayer: Using global variables like `ix.someRequestData = value` causes race conditions when multiple players trigger the same flow simultaneously - later requests overwrite earlier ones before they complete. Fix: Use a table keyed by unique request ID (e.g., item ID, timestamp). Example: `ix.photoRequestTitle = title` was overwritten when two players viewed photos. Fix: `ix.photoRequestTitles[photoID] = title` with cleanup after use.

- Dead OnRun when using custom net handlers: If `OnClick` sends a net message to a custom handler instead of letting Helix's item action flow continue, `OnRun` is never called. The custom net handler does the actual work. Fix: Either remove `OnRun` or simplify it to `return false`. Example: Photo rename had both `OnRun` (setting title) and `OnClick` (sending net message to custom handler that sets title). OnRun was dead code since the net handler did the work.

- PlayerUse hooks should be SERVER-only: `hook.Add("PlayerUse", ...)` registered in shared scope runs on both client and server. The client callback does nothing useful (server handles the interaction). Fix: Wrap entire hook registration in `if SERVER then`. Example: Photo ground viewing registered hook in shared scope with `if SERVER then` inside callback - wasteful. Fix: Move entire `hook.Add()` call inside `if SERVER then`.

- ITEM.isBag = true causes View auto-open: When an item has `isBag = true`, Helix automatically calls the "View" function when inventory opens (if player has "openBags" option enabled). This causes unwanted behavior if "View" does something special like opening a custom viewer. Fix: Rename custom viewer functions to something other than "View" (e.g., "Browse"). Keep "View" for the standard bag inventory panel. Example: Photo album had "View" opening book-style viewer, which auto-triggered on inventory open. Fix: Renamed to "Browse", added standard "View" for inventory management.

- Correct hook name is CanTransferItem: The hook for restricting item transfers is `CanTransferItem`, NOT `CanItemBeTransfered` (common misspelling). Using wrong name silently fails - hook never fires. Example: Photo album restriction used wrong hook name, allowing non-photos to be added. Fix: `hook.Add("CanTransferItem", "ixPhotoAlbumRestriction", function(item, curInv, inventory) ... end)`.

- light_dynamic entities network to clients: Server-created `ents.Create("light_dynamic")` entities DO replicate to clients and illuminate the client's rendered scene. No need for client-side effects for lighting. A brief delay (~50ms) after spawning ensures the entity networks before dependent actions (like photo capture) occur.
