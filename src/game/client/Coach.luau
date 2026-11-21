--[[
	First-run coaching (GDD 6's first three minutes): one short tip at the moment
	it's needed, each shown once, and only to players in their first few runs
	("Games" < 3, set by the server from their save). A dark card on the left with
	the tool's icon and the tip, sliding in and out, never covering the action.

	  * the rig leaves      -> crank to go faster; crank on one side to turn
	  * ~25 s of riding     -> cast the Delver's Hook into the rock for food
	  * Hunger under 65%    -> hold a find and click to eat
	  * the first stop      -> mine the glowing veins; glowstone repairs the rig
	  * the first night     -> stay in the Beacon's light, feed it glowstone
	  * the first fall off  -> slide back after the rig
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared.Ui)

local Coach = {}

local player = Players.LocalPlayer
local shown: { [string]: boolean } = {}
local queue: { { key: string, icon: string, text: string } } = {}
local busy = false
local card: Frame
local iconHolder: Frame
local label: TextLabel

local function veteran(): boolean
	return (player:GetAttribute("Games") or 0) >= 3
end

local function nextTip()
	if busy or #queue == 0 then
		return
	end
	busy = true
	local tip = table.remove(queue, 1)
	iconHolder:ClearAllChildren()
	Ui.icon(tip.icon, { Parent = iconHolder, Size = UDim2.fromScale(1, 1) })
	label.Text = tip.text
	card.Position = UDim2.new(0, -460, 0.72, 0)
	card.Visible = true
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 16, 0.72, 0) }):Play()
	task.delay(6.5, function()
		TweenService:Create(card, TweenInfo.new(0.3), { Position = UDim2.new(0, -460, 0.72, 0) }):Play()
		task.wait(0.35)
		card.Visible = false
		busy = false
		task.wait(0.6)
		nextTip()
	end)
end

function Coach.tip(key: string, icon: string, text: string)
	if shown[key] or veteran() then
		return
	end
	shown[key] = true
	table.insert(queue, { key = key, icon = icon, text = text })
	nextTip()
end

function Coach.init(state: Instance)
	local gui = Ui.new("ScreenGui", { Name = "Coach", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, Parent = player:WaitForChild("PlayerGui") })
	card = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(16, 18, 20), BackgroundTransparency = 0.12, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -460, 0.72, 0), Size = UDim2.fromOffset(430, 92), Visible = false, Parent = gui }, { Ui.corner(UDim.new(0, 14)), Ui.stroke(3, Color3.fromRGB(255, 214, 80), true) })
	iconHolder = Ui.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(68, 68), Parent = card })
	label = Ui.text({ Parent = card, Text = "", Position = UDim2.fromOffset(92, 10), Size = UDim2.new(1, -104, 1, -20), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Stroke = 2 })
	Ui.fit(gui)

	local rideStart = nil
	local seenStop = false
	game:GetService("RunService").Heartbeat:Connect(function()
		local phase = state:GetAttribute("Phase")
		if phase == "Moving" then
			if not rideStart then
				rideStart = os.clock()
				Coach.tip("crank", "Crank", "Hold the Crank Pump (1) and click to drill faster! Crank on the LEFT side to turn right.")
			elseif os.clock() - rideStart > 25 then
				Coach.tip("delve", "DelversHook", "Hungry? Hold the Delver's Hook (3), click to cast into the rock, and click again at the \"!\" to reel up food.")
			end
		elseif phase == "Stop" or phase == "Night" then
			if not seenStop then
				seenStop = true
				Coach.tip("mine", "Pickaxe", "Mine the glowing veins with your Pickaxe (2). Glowstone repairs the rig and feeds the Beacon.")
			end
			if phase == "Night" then
				Coach.tip("night", "Beacon", "Stay inside the Beacon's light! Press E at the fire to feed it glowstone and speed up the night.")
			end
		end
		if (player:GetAttribute("Hunger") or 100) < 65 then
			Coach.tip("eat", "Hunger", "Your Hunger is dropping! Hold a find from your hotbar and click to eat it.")
		end
		if player:GetAttribute("OffRig") then
			Coach.tip("slide", "Warning", "You fell off! Run after the rig: you slide down the slope faster than it drills.")
		end
	end)
end

return Coach
