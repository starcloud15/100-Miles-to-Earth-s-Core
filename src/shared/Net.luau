--[[
	The Game place's remotes. The server creates them; clients wait for them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Crank", -- client -> server: one pump of your side's tread
	"TowLine", -- client -> server: reel an off-rig player back (target)
	"PushOff", -- client -> server: shove a player off the deck (target)
	"Notify", -- server -> client: a toast or status (kind, data)
	"Shove", -- server -> client: launch your own character (velocity)
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Net = {}
for _, name in NAMES do
	Net[name] = folder:WaitForChild(name) :: RemoteEvent
end
return Net
