--[[
	Writes the hand-authored animations in src/shared/Poses.luau to .rbxm files
	in art/anims/Character/, where Starport uploads them (group "animations").

	    lune run tools/anims/build
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Poses = require("../../src/shared/Poses")

fs.writeDir("art/anims/Character")
for _, name in { "Slide" } do
	local kfs = Poses.build(Poses[name], roblox.Instance, roblox.CFrame, roblox.Enum)
	kfs.Name = name
	fs.writeFile("art/anims/Character/" .. name .. ".rbxm", roblox.serializeModel({ kfs }))
	print("wrote art/anims/Character/" .. name .. ".rbxm")
end
