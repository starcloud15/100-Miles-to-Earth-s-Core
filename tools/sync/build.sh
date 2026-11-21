#!/usr/bin/env bash
# Builds both places' code into models and copies them into Roblox Studio's
# content folder, where tools/sync/apply.luau (run in Studio through the MCP)
# loads them with game:GetObjects("rbxasset://mcpsync/<place>.sync.rbxm").
# Starport publishes from the Rojo projects; this is only for live prototyping.
set -e
cd "$(dirname "$0")/../.."
export PATH="$HOME/.rokit/bin:$PATH"
mkdir -p build
lune run tools/materials/build >/dev/null
for p in game lobby; do rojo build "tools/sync/$p.sync.project.json" -o "build/$p.sync.rbxm" >/dev/null; done
base="$LOCALAPPDATA"
command -v cygpath >/dev/null && base=$(cygpath "$LOCALAPPDATA")
studio=""
for d in "$base"/Roblox/Versions/*/; do [ -f "$d/RobloxStudioBeta.exe" ] && studio="$d"; done
[ -n "$studio" ] || { echo "Roblox Studio not found"; exit 1; }
mkdir -p "$studio/content/mcpsync"
cp build/*.sync.rbxm "$studio/content/mcpsync/"
# icons not uploaded yet, so Studio can show them (Art.icon falls back to these)
mkdir -p "$studio/content/mcpsync/icons"
cp assets/ui/icons/*.png "$studio/content/mcpsync/icons/"
mkdir -p "$studio/content/mcpsync/sfx"
cp assets/audio/sfx/*.ogg "$studio/content/mcpsync/sfx/" 2>/dev/null || true
mkdir -p "$studio/content/mcpsync/music"
cp assets/audio/music/*.ogg "$studio/content/mcpsync/music/" 2>/dev/null || true
echo "synced to $studio/content/mcpsync"
