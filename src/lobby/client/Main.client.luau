--[[
	Topside Camp client, laid out like the reference's lobby HUD:
	  * top centre: Journal / Invite / Badges with red counts, and Deepstones;
	  * top right: STATS;
	  * bottom centre: the big green PLAY;
	  * your own bay outlined in yellow; panels from the HUD and the camp's
	    prompts; "+N DEEPSTONES" pop-ups; the Favorite prompt after a run.
]]

local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Content = require(Shared.Content)
local Net = require(Shared.Net)
local Ui = require(Shared.Ui)
local Panels = require(script.Parent:WaitForChild("Panels"))
local BoardView = require(script.Parent:WaitForChild("BoardView"))

local player = Players.LocalPlayer
local gui = Ui.new("ScreenGui", { Name = "Camp", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

local function italic(props)
	local l = Ui.text(props)
	l.FontFace = Ui.ITALIC
	return l
end

-- top centre: Journal / Invite / Badges --------------------------------------
local counts = {}
local top = Ui.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(480, 200), Parent = gui })
for i, item in { { "Journal", "Journal" }, { "Invite", "Invite" }, { "Badges", "Badges" } } do
	local b = Ui.new("TextButton", { Name = item[1], Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset((i - 1) * 160, 0), Size = UDim2.fromOffset(160, 130), Parent = top })
	Ui.icon(item[2], { Parent = b, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(92, 92) })
	italic({ Parent = b, Text = item[1], AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), Size = UDim2.fromOffset(150, 42), Stroke = 4 })
	local badge = Ui.new("Frame", { Name = "Count", BackgroundColor3 = Color3.fromRGB(220, 30, 40), Position = UDim2.new(0.5, 22, 0, -2), Size = UDim2.fromOffset(38, 38), Visible = false, Parent = b }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, Color3.new(0, 0, 0), true) })
	counts[item[1]] = Ui.text({ Parent = badge, Text = "", Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), Stroke = 2 })
	b.Activated:Connect(function()
		if item[1] == "Invite" then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		else
			Panels.open(item[1])
		end
	end)
end
local money = Ui.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(260, 64), Parent = gui })
Ui.icon("Deepstone", { Parent = money, Size = UDim2.fromOffset(64, 64), FallbackColor = Color3.fromRGB(150, 80, 230) })
local moneyText = italic({ Parent = money, Text = "0", TextColor3 = Ui.GOLD, Position = UDim2.fromOffset(70, 2), Size = UDim2.fromOffset(190, 60), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4 })

-- top right: STATS ------------------------------------------------------------
local stats = Ui.new("TextButton", { Text = "", BackgroundColor3 = Color3.fromRGB(20, 20, 22), BackgroundTransparency = 0.3, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 10), Size = UDim2.fromOffset(110, 40), Parent = gui }, { Ui.corner(UDim.new(0.5, 0)) })
Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "STATS", FontFace = Ui.FONT, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, Size = UDim2.new(1, -24, 1, -14), Position = UDim2.fromOffset(12, 7), Parent = stats })
stats.Activated:Connect(function()
	Panels.open("Stats")
end)

-- bottom centre: PLAY ----------------------------------------------------------
local play = Ui.button({ Parent = gui, Text = "PLAY", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(330, 108), TextStroke = 5 })
play.Label.FontFace = Ui.FONT
play.Activated:Connect(function()
	Net.QuickPlay:FireServer()
end)
local arrow = Ui.text({ Parent = gui, Text = "V", TextColor3 = Ui.GOLD, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -140), Size = UDim2.fromOffset(70, 60), Stroke = 4, Visible = false })
TweenService:Create(arrow, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0.5, 0, 1, -160) }):Play()

local toast = Ui.text({ Parent = gui, Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromOffset(760, 42), Visible = false })

Panels.init(gui)

-- profile ----------------------------------------------------------------------
local profile
local function apply(p)
	profile = p
	moneyText.Text = tostring(p.deepstones)
	local journal = Content.pendingJournal(p)
	local _, badgeCount = Content.pendingBadges(p)
	local notes = 0
	for id in p.notes do
		if not p.claimed.notes[id] then
			notes += 1
		end
	end
	for id in p.pages do
		if not p.claimed.pages[id] then
			notes += 1
		end
	end
	counts.Journal.Parent.Visible = journal > 0
	counts.Journal.Text = tostring(notes)
	counts.Badges.Parent.Visible = badgeCount > 0
	counts.Badges.Text = tostring(badgeCount)
	counts.Invite.Parent.Visible = false
	arrow.Visible = p.games == 0
	Panels.setProfile(p)
end
Net.Profile.OnClientEvent:Connect(apply)
task.spawn(function()
	local ok, p = pcall(function()
		return Net.GetProfile:InvokeServer()
	end)
	if ok and p then
		apply(p)
		-- the Favorite prompt: the first time you're back from a run, never on a first join
		local data = TeleportService:GetLocalPlayerTeleportData()
		if type(data) == "table" and data.fromRun and not p.favPrompted then
			task.wait(3)
			pcall(function()
				AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
			end)
			Net.Claim:FireServer("favorite")
		end
	end
end)

-- server messages ----------------------------------------------------------------
Net.PartyPrompt.OnClientEvent:Connect(function()
	Panels.open("CreateParty")
end)
Net.Notify.OnClientEvent:Connect(function(kind, data)
	if kind == "PartyPromptClose" then
		if Panels.isOpen("CreateParty") then
			Panels.close()
		end
	elseif kind == "Deepstones" then
		Ui.pop(gui, "+" .. tostring(data) .. " DEEPSTONES")
	elseif kind == "Toast" then
		toast.Text = tostring(data)
		toast.Visible = true
		task.delay(3, function()
			if toast.Text == tostring(data) then
				toast.Visible = false
			end
		end)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ClassesPrompt" then
		Panels.open("Classes")
	elseif prompt.Name == "FreeRevivePrompt" then
		Panels.open("FreeRevive")
	end
end)

-- your own bay gets a yellow outline, like the reference ----------------------------
task.spawn(function()
	local camp = workspace:WaitForChild("TopsideCamp")
	local me = tostring(player.UserId)
	while true do
		task.wait(0.3)
		for _, bay in camp:GetChildren() do
			if bay.Name:sub(1, 3) == "Bay" then
				local members = bay:GetAttribute("Members") or ""
				local mine = table.find(string.split(members, ","), me) ~= nil
				for _, p in bay:GetChildren() do
					if p.Name == "Edge" then
						if mine then
							p.Color = Color3.fromRGB(255, 220, 30)
						elseif members == "" then
							p.Color = Color3.new(1, 1, 1)
						else
							p.Color = Color3.fromRGB(70, 230, 60)
						end
					end
				end
			end
		end
	end
end)

BoardView.init()
