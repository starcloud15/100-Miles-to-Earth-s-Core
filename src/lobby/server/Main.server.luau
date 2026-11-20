--[[
	Topside Camp, the lobby (GDD section 14): party bays with Create Party,
	the PLAY button, leaderboards, the Free Revive board, the Classes hut,
	and claims for the Journal and badges. The party teleports into its own
	reserved server of the Game place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared.Data)
require(Shared.Net) -- create the remotes before clients look for them

local Camp = require(script.Parent.Camp)
local Bays = require(script.Parent.Bays)
local Boards = require(script.Parent.Boards)
local Rewards = require(script.Parent.Rewards)

local old = workspace:FindFirstChild("LaunchBays")
if old then
	old:Destroy() -- the M0 single bay
end

local camp = Camp.build()
Data.start()
Rewards.init()
Boards.init()
Bays.init(camp.bays)

-- the player list's Miles column: lifetime miles down, like the reference
Data.Changed:Connect(function(player, p)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
		local miles = Instance.new("NumberValue")
		miles.Name = "Miles"
		miles.Parent = stats
	end
	stats.Miles.Value = math.floor(p.totalMiles * 10 + 0.5) / 10
end)
for _, p in Players:GetPlayers() do
	local prof = Data.get(p)
	if prof then
		task.spawn(function()
			Data.update(p, function() end)
		end)
	end
end
