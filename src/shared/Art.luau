--[[
	Asset ids, read only from the module Starport writes (Assets.lua). Never
	hardcode an id: drop the file into assets/..., push, then in Starport
	Get latest -> Upload everything missing -> Save to GitHub.

	Art.icon("Glowstone") returns "rbxassetid://..." or nil until it's uploaded,
	so callers show a plain fallback until then.
]]

local ok, Assets = pcall(require, script.Parent:WaitForChild("Assets"))
if not ok or type(Assets) ~= "table" then
	Assets = {}
end

local Art = {}

function Art.get(group: string, name: string): string?
	local g = Assets[group]
	return g and g[name] or nil
end

function Art.icon(name: string): string?
	local id = Art.get("icons", name)
	if not id and game:GetService("RunService"):IsStudio() then
		-- (Studio, before Starport has uploaded it: the local file, which
		-- tools/sync/build.sh copies into Studio's content folder)
		return "rbxasset://mcpsync/icons/" .. name .. ".png"
	end
	return id
end

function Art.sound(name: string): string?
	local id = Art.get("sounds", name)
	if not id and game:GetService("RunService"):IsStudio() then
		return "rbxasset://mcpsync/sfx/" .. name .. ".ogg"
	end
	return id
end

return Art
