--[[
	The stylized textures as MaterialVariants (owner: "also stylized textures").

	Writes build/MaterialService.rbxm: MaterialService with one MaterialVariant
	per base material we restyle (ColorMap = the uploaded texture, from
	src/shared/Assets.lua) and the base-material overrides set, so every part,
	mesh and terrain voxel of that material uses the hand-painted tile. Both
	places' Rojo projects build MaterialService from it.

	Game scripts can't create MaterialVariants (that needs plugin rights), so
	this runs before every build: Starport's Publish "prebuild", and
	tools/sync/build.sh.

	    lune run tools/materials/build
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance

local Assets = require("../../src/shared/Assets")
local textures = Assets.textures or {}
-- (MaterialVariants only render uploaded images, not Studio's local files, so
-- until Starport has uploaded the textures this writes an empty MaterialService
-- and the default materials stay)

-- texture -> { base materials it replaces, studs per tile } (keep in step with
-- tools/build_textures.py)
local VARIANTS = {
	{ "Planks", { "Wood", "WoodPlanks" }, 8 },
	{ "Rock", { "Slate", "Rock", "Basalt" }, 10 },
	{ "Strata", { "Sandstone", "Limestone" }, 16 },
	{ "Metal", { "Metal" }, 6 },
	{ "Cloth", { "Fabric" }, 4 },
	{ "Grass", { "Grass", "LeafyGrass" }, 10 },
	{ "Sand", { "Sand", "Ground" }, 10 },
	{ "Ice", { "Ice", "Glacier" }, 12 },
}

local service = Instance.new("MaterialService")
local made = 0
for _, def in VARIANTS do
	local tex, bases, studs = def[1], def[2], def[3]
	local id = textures[tex]
	if id then
		for _, base in bases do
			local v = Instance.new("MaterialVariant")
			v.Name = "Stylized" .. tex .. "_" .. base
			v.BaseMaterial = roblox.Enum.Material[base]
			v.ColorMap = id
			v.StudsPerTile = studs
			v.Parent = service
			-- the override: this base material now looks like the variant everywhere
			service[base .. "Name"] = v.Name
			made += 1
		end
	end
end

fs.writeDir("build")
local out = "build/MaterialService.rbxm"
fs.writeFile(out, roblox.serializeModel({ service }))
print(("wrote %s (%d variants)"):format(out, made))
