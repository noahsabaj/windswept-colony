- CEG: Confederation of Earthly Governments.

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

- 