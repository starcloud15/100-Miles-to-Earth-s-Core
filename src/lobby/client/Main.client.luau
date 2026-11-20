--[[
	The Topside Camp client, M0: the title, and a pointer to the launch bay.
	The full lobby (PLAY, Continue, Journal, Badges, classes) comes in M1.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui"))

local gui = Ui.new("ScreenGui", { Name = "Camp", ResetOnSpawn = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
Ui.text({ Parent = gui, Text = "100 Miles to Earth's Core", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(620, 60), Stroke = 4 })
Ui.text({ Parent = gui, Text = "Step onto the glowing launch bay to start a descent", TextColor3 = Ui.ORANGE, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(620, 32) })
