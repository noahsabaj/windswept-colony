- CEG: Confederation of Earthly Governments.
- EEC: Eagle Extraction Conglomerate (the owners of the mine in this colony, Redrock City)

- The reason this colony exists is due to the massive reserves of pure carbon underneath the surface. The EEC operates a massive mine-colony here, exporting high-grade carbon from this colony to be used by humanity elsewhere (the solar system, other colonized locations). Like how Cuba was a massive sugar colony for Europe and America, Redrock City and Zephyrus (the planet we are on) is a massive coal mining colony for the human market.

- Currency: CEG Dollar ($ Dollar, $ CEG Dollar).

- D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\gamemodes\helix is the path for the framework that we are using to build this, it's locally cloned so we can edit it however we want. If you ever need to read the source code of the framework, just go to that path and all the source code is there for you to read and adjust however we want. It is MIT License.

- D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod\gamemodes\helix-hl2rp is the path for a fully implemented half life 2 RP gamemode in garrys mod using the helix framework. We can reverse engineer it however we want, it is a great imnplementation example and you can read its source code. It is MIT License.

- Windswept is the name of the map that we will use.

- This is a Garrys Mod SeriousRP gamemode for multiplayer.

- Helix is the name of the framework, it's a fork of Nutscript.

- How Workshop Addons Work (For Future Reference)
  ┌──────┬───────────────────────────────────────────────────────────────────────────────┐
  │ Step │                                  What to Do                                   │
  ├──────┼───────────────────────────────────────────────────────────────────────────────┤
  │ 1    │ Subscribe to addon on Workshop                                                │
  ├──────┼───────────────────────────────────────────────────────────────────────────────┤
  │ 2    │ Find the .gma file in steamapps/workshop/content/4000/<workshop_id>/          │
  ├──────┼───────────────────────────────────────────────────────────────────────────────┤
  │ 3    │ Extract with: gmad.exe extract -file "path/to/addon.gma" -out "output/folder" │
  ├──────┼───────────────────────────────────────────────────────────────────────────────┤
  │ 4    │ Browse extracted files to find model/material paths                           │
  ├──────┼───────────────────────────────────────────────────────────────────────────────┤
  │ 5    │ Add resource.AddWorkshop("<id>") to server code                               │
  ├──────┼───────────────────────────────────────────────────────────────────────────────┤
  │ 6    │ Use the paths in your Lua code                                                │
  └──────┴───────────────────────────────────────────────────────────────────────────────┘
  The Workshop ID is the number in the URL: steamcommunity.com/sharedfiles/filedetails/?id=3582530445

  (Example run: Bash("D:/SteamLibrary/steamapps/common/GarrysMod/bin/gmad.exe" extract -file
      "D:/SteamLibrary/steamapps/workshop/content/4000/3582530445/gmpublisher.gma" -out
      "D:/SteamLibrary/steamapps/workshop/content/4000/3582530445/extracted"))

- For the battery system, "up" stands for "units of power", so a 100up battery has 100 units of power. A flashlight can hold 1 battery, and consumes about ~0.167up per second when on (~10 minutes per full battery). This should give you a relatively good idea how that system works. Batteries are universal, so all devices that take batteries (defibrillator, flashlight, camera, etc. use the same batteries and units of power measuring system).

- Fog of War principle. Because this is SeriousRP, nothing is free. Here's an example that will tell you a lot. The defibrillator has a 45-95% chance of successfully reviving someone that has been knocked and is actively dying. The player DOES NOT KNOW of the 45-95% chance at all, the player only knows (from experience, from seeing others, from being told, from intuition) that it has decent odds but can fail just as easily. The backend knows its between 45-95% chance (we call it probability^2, it's not guaranteed that the defib will pass or fail, AND the chance itself is also not guaranteed, it can be anywhere from a 45% odds of succeeding to a 95% odds of succeeding, but never 100%).

- Nothing is 100% certain, ever. This is another principle of good SeriousRP.

- Always be Helix-idiomatic. Before implementing any feature, check if Helix already provides it or has an established pattern for it. Read the framework source code in helix/gamemode/core/ to understand how things are done. For example, when we created custom character creation panels, we initially added our own labels and height logic, but Helix already auto-creates labels above OnDisplay panels and uses font-based height sizing (see ixTextEntry and ixNumSlider in cl_generic.lua). Following existing patterns avoids bugs and keeps code consistent.

- All characters are created as Civilians (the default faction). Personal IDs are given only during Civilian character creation because every character starts there. Players join other factions (Medical, Security, Corrections, etc.) through in-game faction transfers after their character exists - no one is created directly into a non-Civilian faction.