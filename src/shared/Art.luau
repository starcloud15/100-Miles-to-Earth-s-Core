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
	return Art.get("icons", name)
end

function Art.sound(name: string): string?
	return Art.get("sounds", name)
end

return Art
