# Asset pipeline: Starport

All of this game's assets go up to Roblox through **Starport**: UI images, icons, sounds, music, animations and 3D models. Starport also publishes the game. It's the desktop app built in the My Pet Restaurant repo (`tools/asset_uploader/`, newest on branch `claude/rojo-setup-roblox-751xur`; the README there is the full manual). It uploads through Open Cloud and writes each new id straight into our Luau files, so nobody imports anything in Studio or copies an id by hand.

**Status:** set up (Nov 20, 2026). `asset-uploader.json` is in the repo root, and the 25 HUD icons wait in `assets/ui/icons/` as **missing**. In Starport: **Get latest → Upload everything missing → Save to GitHub**.

## How it works for us

1. **Every asset goes into `assets/`** (or `art/anims/` for animations), in a folder per kind. The file's name is its slot: `assets/ui/icons/Glowstone.png` becomes `Glowstone`. Nothing is ever uploaded any other way (not through Studio, not by hand).
2. **`asset-uploader.json`** says which group each folder belongs to. Every group writes into one generated module, `src/shared/Assets.lua`, so a new file needs no code slot: drop it in, push, upload.
3. In Starport: **Get latest**, then **Upload everything missing**. It uploads each asset, waits for moderation, and rewrites `Assets.lua`.
4. **Save to GitHub** commits `Assets.lua` and `asset-uploader.lock.json` (each asset's id, file hash and owner), so every computer knows what's already up.
5. **Publish** builds each place with Rojo, merges it into the live place (terrain, lighting and hand-placed parts stay), and publishes it. Both places are live, so each publish asks you to confirm.

The game reads ids only through `src/shared/Art.luau` (`Art.icon("Glowstone")`). It returns nil until the id exists, so the HUD shows a plain lettered tile until then.

## Layout

| Folder | Starport group | Read in game as | What goes there |
|---|---|---|---|
| `assets/ui/icons/` | `icons` (image) | `Art.icon("Glowstone")` | HUD and lobby icons, built by `tools/build_icons.py` |
| `assets/ui/panels/` | `ui` (image) | `Art.get("ui", name)` | Panel frames, buttons, route bar art |
| `assets/textures/` | `textures` (image) | `Art.get("textures", name)` | Cavern decals, zone skyboxes |
| `assets/vfx/` | `vfx` (image) | `Art.get("vfx", name)` | Flipbooks: glowstone smash, Beacon flare, drill sparks |
| `assets/audio/sfx/` (recursive) | `sounds` (audio) | `Art.sound(name)` | Treads, cranks, delving tug and reel, the Hollow |
| `assets/audio/music/` | `music` (audio) | `Art.get("music", name)` | Zone music |
| `art/anims/<Rig>/` (nested) | `animations` | `Art.get("animations", "Rig/Name")` | Cranking, casting and reeling, the Hollow, the Glow Mole |
| `assets/models/rig/`, `route/`, `props/` | `models` | `.rbxm` in `src/shared/Models/...` | Blender `.fbx` models; Starport brings each back as `.rbxm` for Rojo |

### Icons
The icons match the reference's style because most of them come from the owner's icon pack (`C:\Users\beyon\Documents\Icons_12K`). They use the "Totally" set and the Rhos "Outline" set: a thick black outline, flat colours and a soft lower tone. The reference game uses the same pack (its Invite icon is the pack's).

The pack doesn't have three of our subjects (the Delver's Hook, the Crank and the Glow Mole), so they're drawn in the same style as SVG in `art/icons/`. `python tools/build_icons.py` rebuilds every icon into `assets/ui/icons/`, and recolours a few:
- the Badges rosette blue;
- the Turbo fireball orange;
- the Cave Stew orange;
- a glow around Glowstone and the Beacon.

## Two places, one universe

The Topside Camp (the Lobby) and the descent (the Game) are two places in universe 10777965719. Each publish target names its own Rojo project. Both are the real game, so each publish asks you to confirm.

```json
"publish": {
  "targets": [
    {"name": "Lobby", "project": "lobby.project.json", "universeId": "10777965719", "placeId": "76938279277561", "live": true},
    {"name": "Game",  "project": "game.project.json",  "universeId": "10777965719", "placeId": "138151622310222", "live": true}
  ],
  "baseMode": "download"
}
```

**Publish all** sends both places one after another, and stops if one fails.

## Rules that matter

- **Upload as the game's owner: Joyshare Studios** (group 606354866; the owner decided this on Nov 19, 2026). Every asset is uploaded with that group's Starport profile, because sounds and animations only play in games owned by the account or group that uploaded them. An asset from another owner shows as **other owner** and is uploaded again.
- **Every image is moderated.** Try one or two first, check them in Studio, then upload the rest.
- **API key permissions:**
  - Assets Read + Write.
  - Legacy Asset read (for image ids, downloading models and the base place).
  - universe-places write (to publish).
- **Commit `asset-uploader.lock.json`** with the ids. Never edit it by hand.
- `.asset-uploader/` is per computer and is ignored by git.

## Setting it up

1. Open Starport (`E:\Starport.exe`; it updates itself).
2. **Add a project → From GitHub →** `starcloud15/100-Miles-to-Earth-s-Core`, branch `main`.
3. Use the **Joyshare Studios** profile (the one the pet game uses), with its Open Cloud key.
4. The publish targets (Lobby and Game) are already in `asset-uploader.json`.

## Prototyping in Studio (not publishing)

While prototyping, code reaches the open Studio places without Starport:
1. `bash tools/sync/build.sh` builds each place's code with Rojo into Studio's content folder.
2. `tools/sync/apply.luau`, run in Studio through the MCP, swaps it in.

Starport stays the only way assets go up and the way the game is published.
