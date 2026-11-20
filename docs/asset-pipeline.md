# Asset pipeline: Starport

All of this game's assets go up to Roblox through **Starport**: UI images, icons, sounds, music, animations and 3D models. Starport also publishes the game. It's the desktop app built in the My Pet Restaurant repo (`tools/asset_uploader/`, newest on branch `claude/rojo-setup-roblox-751xur`; the README there is the full manual). It uploads through Open Cloud and writes each new id straight into our Luau files, so nobody imports anything in Studio or copies an id by hand.

**Status:** proposal. Nothing below exists in this repo yet. It's set up as part of M0 (GDD section 19).

## How it works for us

1. **Art goes into `assets/`** under a folder per kind. The file's name is its slot: `assets/ui/icons/Glowstone.png` becomes `Glowstone`.
2. **`asset-uploader.json`** at the repo root says, for each folder, which Luau file the ids go into.
3. In Starport: **Upload missing**. It uploads each asset, waits for moderation, and writes the id into the Luau file.
4. **Save to GitHub** commits the ids and `asset-uploader.lock.json`, which records every asset's id, file hash and owner. Any computer then knows what's already up, so nothing goes up twice.
5. **Publish** builds each place with Rojo, merges it into the live place (terrain, lighting and hand-placed parts stay), and publishes it to Test. Live always asks you to confirm first.

The code never hardcodes an id. It reads them from the generated content modules, and shows a plain fallback until an id arrives.

## Proposed layout

| Folder | Type | Ids go into | Notes |
|---|---|---|---|
| `assets/ui/icons/` | image | `src/shared/Content/UIIcons.lua` (`table`) | The 21 glossy icons, exported from `docs/ui/icons/*.svg` as 512 px PNGs |
| `assets/ui/panels/` | image | `src/shared/Content/UIArt.lua` (`table`) | Panel frames, buttons, the route bar, the speedometer ring, the Glow Mole portrait |
| `assets/textures/` | image | `src/shared/Content/Textures.lua` (`table`) | Glowstone glow, cavern decals, zone skyboxes |
| `assets/vfx/` | image | `src/shared/Content/VFXTextures.lua` (`table`) | Flipbooks: glowstone smash, Beacon flare, drill sparks |
| `assets/audio/` (recursive) | audio | `src/shared/Content/Sounds.lua` and `Music.lua` (`table`) | Treads, cranks, delving tug and reel, the Hollow, zone music |
| `art/anims_rbxm/<Rig>/` (nested) | animation | `src/shared/Content/Animations.lua` (`string`, block `{folder}`) | Cranking, casting and reeling, the Hollow, the Glow Mole |
| `assets/models/rig/` | model | `.rbxm` in `src/shared/Models/Rig/` | Rig hull, treads, drill bit, builds (Wide deck, Lantern posts…) |
| `assets/models/route/` | model | `.rbxm` in `src/shared/Models/Route/` | The modular route pieces, per zone |
| `assets/models/props/` | model | `.rbxm` in `src/shared/Models/Props/` | Beacon, Cookpot, Waystation, glowstone veins, tools |

Models are made in Blender as `.fbx`. Starport uploads them, then downloads each one back as `.rbxm` for Rojo to build into the place.

## Two places, one universe

The Topside Camp (lobby) and the descent run are two places (GDD section 14). Starport handles this directly: each publish target names its own Rojo project.

```json
"publish": {
  "targets": [
    {"name": "Camp (Test)",    "project": "places/camp.project.json",    "universeId": "…", "placeId": "…", "live": false},
    {"name": "Descent (Test)", "project": "places/descent.project.json", "universeId": "…", "placeId": "…", "live": false},
    {"name": "Camp",           "project": "places/camp.project.json",    "universeId": "…", "placeId": "…", "live": true},
    {"name": "Descent",        "project": "places/descent.project.json", "universeId": "…", "placeId": "…", "live": true}
  ],
  "baseMode": "download"
}
```

**Publish all** sends both test places one after another, and stops if one fails.

## Rules that matter

- **Upload as the game's owner: Joyshare Studios** (group 606354866, owner's decision Nov 19, 2026). The universe is created under this group, and every asset is uploaded with its Starport profile. Sounds and animations only play in games owned by the account or group that uploaded them. An asset from another owner shows as **other owner** and is uploaded again.
- **Every image is moderated.** Try one or two first, check them in Studio, then upload the rest.
- **API key permissions:** Assets Read + Write; Legacy Asset read (for image ids, downloading models and the base place); universe-places write (to publish).
- **Commit `asset-uploader.lock.json`** with the ids. Never edit it by hand.
- `.asset-uploader/` is per computer and is ignored by git.

## Setting it up (in M0)

1. Open Starport (`E:\Starport.exe`; it updates itself).
2. **Add a project → From GitHub →** `starcloud15/100-Miles-to-Earth-s-Core`, branch `main`.
3. Use the **Joyshare Studios** profile (the one the pet game uses), with its Open Cloud key.
4. Create the universe under Joyshare Studios and add the two places, then fill in their ids under **Publish → Settings**.

Open question for the owner: should the Starport ids live in `src/shared/Content/` (our OneWayToSpace-style layout, as above), or should we use the pet game's `src/ReplicatedStorage/...` layout?
