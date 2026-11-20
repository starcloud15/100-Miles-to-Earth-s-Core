-- Run in Studio (edit mode) through the MCP after tools/sync/build.sh.
-- Replaces the Rojo-managed folders with the freshly built ones.
local PLACE = "game" -- or "lobby"
local root = game:GetObjects("rbxasset://mcpsync/" .. PLACE .. ".sync.rbxm")[1]
local targets = {
	Shared = game:GetService("ReplicatedStorage"),
	Server = game:GetService("ServerScriptService"),
	Client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}
for name, parent in targets do
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	root[name].Parent = parent
end
root:Destroy()
return "synced " .. PLACE
