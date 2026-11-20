--[[
	Remotes for both places. The server creates them; clients wait for them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- both places
	"Notify", -- server -> client: a toast or status (kind, data)
	"Profile", -- server -> client: your save data changed (snapshot)
	-- the Game place
	"Crank", -- client -> server: one pump of your side's tread
	"TowLine", -- client -> server: reel an off-rig player back (target)
	"PushOff", -- client -> server: shove a player off the deck (target)
	"Shove", -- server -> client: launch your own character (velocity)
	"Mine", -- client -> server: hit a glowstone vein at a stop (vein model)
	"Delve", -- client -> server: "cast" or "reel" the Delver's Hook
	"Eat", -- client -> server: eat a find
	-- Topside Camp
	"PartyPrompt", -- server -> client: you stepped into an empty bay (bay name)
	"PartyCreate", -- client -> server: make the party (size, friendsOnly)
	"PartyCancel", -- client -> server: closed the Create Party panel
	"QuickPlay", -- client -> server: the big PLAY button
	"Claim", -- client -> server: "journal" or "badges"
	"BuyClass", -- client -> server: (class id, "deepstones" | "robux")
	"EquipClass", -- client -> server: (class id)
	"FreeRevive", -- client -> server: claim the free Revive Flare
}
local FUNCTIONS = {
	"BoardFetch", -- client -> server: (board, "Global" | "Friends") -> rows, you
	"GetProfile", -- client -> server: -> snapshot
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Net = {}
for _, name in EVENTS do
	Net[name] = folder:WaitForChild(name) :: RemoteEvent
end
for _, name in FUNCTIONS do
	Net[name] = folder:WaitForChild(name) :: RemoteFunction
end
return Net
