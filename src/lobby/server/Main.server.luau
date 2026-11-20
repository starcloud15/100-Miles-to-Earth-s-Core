--[[
	The Topside Camp (lobby), M0: one launch bay. Step onto the pad to join
	its party (up to 4 by default, 5 max). A 20 s countdown starts with the
	first player and drops to 5 s when the bay is full; then the party
	teleports into its own reserved server of the Game place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local CAPACITY = Config.PARTY_DEFAULT
local FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)

local bays = workspace:FindFirstChild("LaunchBays")
if bays then
	bays:Destroy()
end
bays = Instance.new("Folder")
bays.Name = "LaunchBays"
bays.Parent = workspace

local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
local origin = spawn and spawn.Position * Vector3.new(1, 0, 1) or Vector3.zero

local pad = Instance.new("Part")
pad.Name = "LaunchBay"
pad.Anchored = true
pad.Size = Vector3.new(24, 1, 24)
pad.CFrame = CFrame.new(origin + Vector3.new(0, 0.6, -50))
pad.Material = Enum.Material.Neon
pad.Color = Color3.fromRGB(255, 170, 40)
pad.Parent = bays
local rim = Instance.new("Part")
rim.Name = "Rim"
rim.Anchored = true
rim.CanCollide = false
rim.Size = Vector3.new(26, 0.8, 26)
rim.CFrame = pad.CFrame * CFrame.new(0, -0.2, 0)
rim.Color = Color3.fromRGB(40, 30, 24)
rim.Parent = bays

local board = Instance.new("BillboardGui")
board.Size = UDim2.fromOffset(360, 150)
board.StudsOffset = Vector3.new(0, 10, 0)
board.AlwaysOnTop = true
board.Parent = pad
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.FontFace = FONT
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = board
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Parent = label

local function inBay(p: Player): boolean
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local rel = pad.CFrame:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= 12 and math.abs(rel.Z) <= 12 and rel.Y > -2 and rel.Y < 10
end

local function launch(party: { Player })
	if RunService:IsStudio() then
		label.Text = "LAUNCH!\n(teleports only work in a live server: playtest the Game place in Studio)"
		task.wait(5)
		return
	end
	label.Text = "LAUNCHING..."
	local data = { seed = math.random(1, 2 ^ 30), size = #party }
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(Config.GAME_PLACE_ID)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = code
			options:SetTeleportData(data)
			TeleportService:TeleportAsync(Config.GAME_PLACE_ID, party, options)
		end)
		if ok then
			return
		end
		warn("Launch failed (attempt " .. attempt .. "): " .. tostring(err))
		task.wait(2)
	end
	label.Text = "Launch failed, try again"
	task.wait(3)
end

local countdown: number? = nil
while true do
	local party = {}
	for _, p in Players:GetPlayers() do
		if #party < CAPACITY and inBay(p) then
			table.insert(party, p)
		end
	end
	if #party == 0 then
		countdown = nil
		label.Text = "LAUNCH BAY\n0/" .. CAPACITY .. "\nstep on to descend!"
	else
		if not countdown then
			countdown = Config.BAY_COUNTDOWN
		end
		if #party >= CAPACITY then
			countdown = math.min(countdown :: number, Config.BAY_COUNTDOWN_FULL)
		end
		label.Text = "LAUNCH BAY\n" .. #party .. "/" .. CAPACITY .. "\ndescending in " .. math.ceil(countdown :: number)
		if (countdown :: number) <= 0 then
			launch(party)
			countdown = nil
		end
	end
	task.wait(1)
	if countdown then
		countdown -= 1
	end
end
