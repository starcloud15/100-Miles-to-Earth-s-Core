--[[
	Topside Camp's panels, built 1:1 on the reference's (docs/research/
	reference-lobby/*.jpg): Create Party, Free Revive, Classes and a class
	card, the Journal, Badges and Your Stats. Wood boards with nails, dark
	insets, a big white title outside the top-left and a red X.
]]

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local Net = require(Shared.Net)
local Ui = require(Shared.Ui)

local Panels = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local open: Frame? = nil
local profile = nil
local views = {}
local refreshDelveLog: () -> () -- (the Delve Log page, below the Journal)

local function show(root: Frame?)
	if open and open ~= root then
		open.Visible = false
	end
	open = root
	if root then
		root.Visible = true
	end
end

function Panels.close()
	show(nil)
end

local function italic(props)
	local l = Ui.text(props)
	l.FontFace = Ui.ITALIC
	return l
end

local function deepstoneAmount(parent, amount: string, size: number, pos: UDim2, anchor: Vector2?)
	local f = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size * 4, size), Position = pos, AnchorPoint = anchor, Parent = parent })
	Ui.icon("Deepstone", { Parent = f, Size = UDim2.fromOffset(size, size), FallbackColor = Color3.fromRGB(150, 80, 230) })
	italic({ Parent = f, Text = amount, TextColor3 = Ui.GOLD, Position = UDim2.fromOffset(size + 4, 0), Size = UDim2.new(1, -size - 4, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
	return f
end

local function robuxLabel(parent, amount: number)
	local f = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6), Parent = parent })
	Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = f })
	Ui.new("ImageLabel", { BackgroundTransparency = 1, Image = Ui.ROBUX, Size = UDim2.fromOffset(34, 34), Parent = f })
	Ui.text({ Parent = f, Text = tostring(amount), Size = UDim2.fromOffset(90, 40), TextXAlignment = Enum.TextXAlignment.Left })
end

-- Create Party ----------------------------------------------------------------
local function buildCreateParty()
	local root, body, close = Ui.panel(gui, "Create Party", UDim2.fromOffset(440, 330))
	local state = { size = Config.PARTY_DEFAULT, friends = false }
	Ui.text({ Parent = body, Text = "Players", Size = UDim2.fromOffset(150, 34), Position = UDim2.fromOffset(4, 4), TextXAlignment = Enum.TextXAlignment.Left })
	local sizeButtons = {}
	local function paint()
		for n, b in sizeButtons do
			local on = n == state.size
			b.BackgroundColor3 = on and Ui.BUTTON_GREEN or Ui.SLATE
			b.UIStroke.Color = on and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		end
		views.friendsTick.Text = state.friends and "✓" or ""
	end
	for n = 1, Config.PARTY_MAX do
		local b = Ui.button({ Parent = body, Text = tostring(n), Color = Ui.SLATE, Size = UDim2.fromOffset(66, 66), Position = UDim2.fromOffset(8 + (n - 1) * 76, 44) })
		b.Activated:Connect(function()
			state.size = n
			paint()
		end)
		sizeButtons[n] = b
	end
	local tick = Ui.button({ Parent = body, Color = Ui.SLATE, Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(90, 128) })
	views.friendsTick = Ui.text({ Parent = tick, Text = "", TextColor3 = Ui.GREEN, Size = UDim2.fromScale(1, 1) })
	Ui.text({ Parent = body, Text = "Friends Only", Size = UDim2.fromOffset(170, 40), Position = UDim2.fromOffset(150, 133), TextXAlignment = Enum.TextXAlignment.Left })
	tick.Activated:Connect(function()
		state.friends = not state.friends
		paint()
	end)
	local create = Ui.button({ Parent = body, Text = "CREATE", Size = UDim2.fromOffset(220, 66), Position = UDim2.fromOffset(84, 200) })
	create.Activated:Connect(function()
		Net.PartyCreate:FireServer(state.size, state.friends)
		show(nil)
	end)
	close.Activated:Connect(function()
		Net.PartyCancel:FireServer()
		show(nil)
	end)
	paint()
	views.createParty = root
end

-- Free Revive -----------------------------------------------------------------
local function buildFreeRevive()
	local root, body, close = Ui.panel(gui, "Free Revive", UDim2.fromOffset(560, 420))
	close.Activated:Connect(function()
		show(nil)
	end)
	Ui.text({ Parent = body, Text = "Get a free revive in 1 step!", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6) })
	local step = Ui.inset({ Parent = body, Size = UDim2.new(1, -40, 0, 170), Position = UDim2.fromOffset(20, 60) })
	local num = Ui.inset({ Parent = step, Color = Ui.SLATE, Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(18, 18) })
	Ui.text({ Parent = num, Text = "1", Size = UDim2.fromScale(1, 1) })
	Ui.icon("Invite", { Parent = step, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(72, 14) })
	Ui.text({ Parent = step, Text = "Join the group", Size = UDim2.fromOffset(300, 36), Position = UDim2.fromOffset(134, 12), TextXAlignment = Enum.TextXAlignment.Left })
	italic({ Parent = step, Text = "It's free and only takes a tap", TextColor3 = Color3.fromRGB(220, 255, 210), Size = UDim2.fromOffset(320, 28), Position = UDim2.fromOffset(134, 50), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
	local join = Ui.button({ Parent = step, Text = "Join Group", Size = UDim2.fromOffset(300, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98) })
	join.Activated:Connect(function()
		pcall(function()
			GroupService:PromptJoinAsync(Content.GROUP_ID)
		end)
		Panels.refresh()
	end)
	local claim = Ui.button({ Parent = body, Text = "CLAIM", Color = Ui.SLATE, Size = UDim2.fromOffset(220, 70), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 260) })
	claim.Activated:Connect(function()
		Net.FreeRevive:FireServer()
	end)
	views.revive = { root = root, join = join, claim = claim }
end

local function refreshRevive()
	local v = views.revive
	if not v or not profile then
		return
	end
	task.spawn(function()
		local ok, member = pcall(function()
			return player:IsInGroupAsync(Content.GROUP_ID)
		end)
		member = ok and member
		v.join.Label.Text = member and "Joined ✓" or "Join Group"
		v.join.BackgroundColor3 = member and Ui.SLATE or Ui.BUTTON_GREEN
		local claimed = profile.freeRevive
		v.claim.Label.Text = claimed and "CLAIMED" or "CLAIM"
		v.claim.BackgroundColor3 = (member and not claimed) and Ui.BUTTON_GREEN or Ui.SLATE
	end)
end

-- Classes ---------------------------------------------------------------------
local function buildClassCard()
	local root, body, close = Ui.panel(gui, "", UDim2.fromOffset(560, 320))
	close.Activated:Connect(function()
		show(views.classes)
	end)
	local icon = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(4, 0), Parent = body })
	local name = Ui.text({ Parent = body, Text = "", Size = UDim2.fromOffset(360, 56), Position = UDim2.fromOffset(74, 2), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4 })
	italic({ Parent = body, Text = "What you get", TextColor3 = Ui.GOLD, Size = UDim2.fromOffset(240, 34), Position = UDim2.fromOffset(4, 70), TextXAlignment = Enum.TextXAlignment.Left })
	local perk = Ui.text({ Parent = body, Text = "", Size = UDim2.new(1, -8, 0, 64), Position = UDim2.fromOffset(4, 110), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 24, TextWrapped = true, Stroke = 2 })
	local left = Ui.button({ Parent = body, Text = "", Color = Ui.SLATE, Size = UDim2.fromOffset(220, 80), Position = UDim2.fromOffset(20, 190) })
	local right = Ui.button({ Parent = body, Color = Color3.fromRGB(214, 0, 230), Size = UDim2.fromOffset(220, 80), Position = UDim2.fromOffset(260, 190) })
	views.classCard = { root = root, icon = icon, name = name, perk = perk, left = left, right = right }
	left.Activated:Connect(function()
		local c = views.classCard.class
		if not c or not profile then
			return
		end
		if profile.classes[c.id] then
			Net.EquipClass:FireServer(profile.class == c.id and "" or c.id)
		elseif profile.deepstones >= c.deepstones then
			Net.BuyClass:FireServer(c.id, "deepstones")
		end
	end)
	right.Activated:Connect(function()
		local c = views.classCard.class
		if c then
			Net.BuyClass:FireServer(c.id, "robux")
		end
	end)
end

local function refreshClassCard()
	local v = views.classCard
	local c = v and v.class
	if not c or not profile then
		return
	end
	v.icon:ClearAllChildren()
	Ui.icon(c.icon, { Parent = v.icon, Size = UDim2.fromScale(1, 1) })
	v.name.Text = c.name
	v.perk.Text = c.perk
	local left = v.left
	for _, ch in left:GetChildren() do
		if ch.Name == "Label" or ch.Name == "Amount" then
			ch:Destroy()
		end
	end
	if profile.classes[c.id] then
		left.BackgroundColor3 = profile.class == c.id and Ui.SLATE or Ui.BUTTON_GREEN
		Ui.text({ Name = "Label", Parent = left, Text = profile.class == c.id and "Equipped" or "Equip", Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8) })
	elseif profile.deepstones >= c.deepstones then
		left.BackgroundColor3 = Ui.BUTTON_GREEN
		local amt = deepstoneAmount(left, tostring(c.deepstones), 44, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		amt.Name = "Amount"
		amt.Size = UDim2.fromOffset(160, 44)
	else
		left.BackgroundColor3 = Ui.SLATE
		Ui.text({ Name = "Label", Parent = left, Text = "Need " .. (c.deepstones - profile.deepstones), Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8) })
	end
	v.right:ClearAllChildren()
	Ui.stroke(4, Color3.new(0, 0, 0), true).Parent = v.right
	robuxLabel(v.right, c.robux)
	v.right.Visible = not profile.classes[c.id]
end

local function buildClasses()
	local root, body, close = Ui.panel(gui, "Classes", UDim2.fromOffset(640, 440))
	close.Activated:Connect(function()
		show(nil)
	end)
	views.classRows = {}
	for i, c in Content.CLASSES do
		local row = Ui.new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = Ui.INSET, Size = UDim2.new(1, -20, 0, 104), Position = UDim2.fromOffset(10, 6 + (i - 1) * 118), Parent = body }, { Ui.stroke(3, Color3.new(0, 0, 0), true) })
		Ui.icon(c.icon, { Parent = row, Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(14, 12) })
		-- (the name ends where the price starts, so long names never run under it)
		Ui.text({ Parent = row, Text = c.name, Size = UDim2.new(1, -330, 0, 52), Position = UDim2.fromOffset(108, 26), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4 })
		local cost = deepstoneAmount(row, tostring(c.deepstones), 60, UDim2.new(1, -210, 0, 22))
		cost.Size = UDim2.fromOffset(200, 60)
		row.Activated:Connect(function()
			views.classCard.class = c
			refreshClassCard()
			show(views.classCard.root)
		end)
		views.classRows[c.id] = cost
	end
	views.classes = root
end

local function refreshClasses()
	if not profile or not views.classRows then
		return
	end
	for _, c in Content.CLASSES do
		local cost = views.classRows[c.id]
		local label = cost:FindFirstChildOfClass("TextLabel")
		if profile.classes[c.id] then
			label.Text = profile.class == c.id and "Equipped" or "Owned"
			label.TextColor3 = Ui.GREEN
		else
			label.Text = tostring(c.deepstones)
			label.TextColor3 = Ui.GOLD
		end
	end
	refreshClassCard()
end

-- Journal ---------------------------------------------------------------------
local CREAM = Color3.fromRGB(242, 232, 204)
local PAGE_GREY = Color3.fromRGB(128, 122, 108)
local zoneIndex = 1

local function card(parent, pos: UDim2, size: UDim2, found: boolean, unclaimedReward: number?, text: string?)
	local f = Ui.new("Frame", { BackgroundColor3 = found and CREAM or PAGE_GREY, Size = size, Position = pos, Rotation = math.random(-2, 2), Parent = parent }, { Ui.stroke(3, Color3.fromRGB(40, 32, 24), true) })
	if found then
		Ui.new("TextLabel", { BackgroundTransparency = 1, Text = text or "", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.fromRGB(60, 44, 30), Size = UDim2.new(1, -12, 0.6, 0), Position = UDim2.fromOffset(6, 8), Parent = f })
	else
		italic({ Parent = f, Text = "?", Size = UDim2.fromScale(0.6, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	end
	if unclaimedReward then
		local pill = Ui.new("Frame", { BackgroundColor3 = Ui.GOLD, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.75, 0.92), Size = UDim2.fromOffset(74, 38), ZIndex = 3, Parent = f }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, Color3.new(0, 0, 0), true) })
		italic({ Parent = pill, Text = "+" .. unclaimedReward, Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), ZIndex = 4 })
	end
	return f
end

local function buildJournal()
	local root = Ui.new("Frame", { Name = "Journal", BackgroundColor3 = Color3.fromRGB(84, 56, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(820, 520), Visible = false, ZIndex = 10, Parent = gui }, { Ui.stroke(5, Color3.new(0, 0, 0), true) })
	local tab = Ui.new("Frame", { Name = "Tab", BackgroundColor3 = Color3.fromRGB(70, 140, 70), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(280, 92), Parent = root }, { Ui.stroke(4, Color3.new(0, 0, 0), true) })
	views.journalZone = Ui.text({ Parent = tab, Text = "", Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 6), Stroke = 4 })
	views.journalDots = {}
	for i = 1, #Config.ZONES do
		views.journalDots[i] = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (i - 3.5) * 26, 0, 58), Parent = tab }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(2, Color3.new(0, 0, 0), true) })
	end
	local leftPage = Ui.new("Frame", { BackgroundColor3 = CREAM, Position = UDim2.fromOffset(24, 26), Size = UDim2.new(0.5, -32, 1, -52), Parent = root }, { Ui.stroke(4, Color3.new(0, 0, 0), true) })
	local rightPage = Ui.new("Frame", { BackgroundColor3 = CREAM, Position = UDim2.new(0.5, 8, 0, 26), Size = UDim2.new(0.5, -32, 1, -52), Parent = root }, { Ui.stroke(4, Color3.new(0, 0, 0), true) })
	local function ink(parent, props)
		local l = Ui.new("TextLabel", { BackgroundTransparency = 1, FontFace = props.Italic and Ui.ITALIC or Ui.FONT, TextScaled = true, TextColor3 = props.Color or Color3.fromRGB(56, 42, 30), Text = props.Text, Size = props.Size, Position = props.Position, TextXAlignment = props.X or Enum.TextXAlignment.Center, Parent = parent })
		return l
	end
	ink(leftPage, { Text = "Notes", Italic = true, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 12) })
	views.journalAuthor = ink(leftPage, { Text = "", Color = Color3.fromRGB(110, 90, 66), Size = UDim2.new(1, -30, 0, 28), Position = UDim2.fromOffset(15, 70) })
	views.journalNotes = Ui.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 110), Size = UDim2.new(1, -32, 1, -130), Parent = leftPage })
	views.journalPagesTitle = ink(rightPage, { Text = "", Size = UDim2.new(1, -30, 0, 40), Position = UDim2.fromOffset(15, 18) })
	views.journalPages = Ui.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 0, 250), Parent = rightPage })
	views.journalWhole = ink(rightPage, { Text = "", Color = Color3.fromRGB(110, 90, 66), Size = UDim2.new(1, -30, 0, 30), Position = UDim2.fromOffset(15, 340) })
	local barHolder, barFill = Ui.bar({ Parent = rightPage, Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 376), Color = Ui.GREEN })
	barHolder.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	views.journalBar = barFill
	for _, dir in { -1, 1 } do
		local b = Ui.new("TextButton", { Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(dir < 0 and 0 or 1, dir * 40, 0.5, 0), Size = UDim2.fromOffset(60, 80), Parent = root })
		Ui.text({ Parent = b, Text = dir < 0 and "<" or ">", Size = UDim2.fromScale(1, 1), Stroke = 4 })
		b.Activated:Connect(function()
			zoneIndex = (zoneIndex - 1 + dir) % #Config.ZONES + 1
			Panels.refresh()
		end)
	end
	local close = Ui.new("TextButton", { BackgroundTransparency = 1, Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(60, 60), Parent = root })
	Ui.text({ Parent = close, Text = "X", TextColor3 = Color3.fromRGB(235, 30, 30), Size = UDim2.fromScale(1, 1), Stroke = 4 })
	close.Activated:Connect(function()
		show(nil)
	end)
	local claim = Ui.button({ Parent = root, Color = Ui.GOLD, Size = UDim2.fromOffset(320, 84), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -10) })
	claim.ZIndex = 5
	views.journalClaim = claim
	claim.Activated:Connect(function()
		Net.Claim:FireServer("journal")
	end)
	local delve = Ui.button({ Parent = root, Text = "Delve Log", Color = Color3.fromRGB(70, 140, 70), Size = UDim2.fromOffset(190, 58), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(14, 2) })
	delve.ZIndex = 5
	delve.Activated:Connect(function()
		refreshDelveLog()
		show(views.delveLog)
	end)
	views.journal = root
end

-- the Delve Log: every find, zone by zone; found ones show their icon and name
-- in their rarity colour, the rest a dark silhouette
local Finds = require(Shared.Finds)
local Art = require(Shared.Art)

local function buildDelveLog()
	local root, body, close = Ui.panel(gui, "Delve Log", UDim2.fromOffset(900, 560))
	close.Activated:Connect(function()
		show(views.journal)
	end)
	views.delveCount = italic({ Parent = body, Text = "", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3 })
	local grid = Ui.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 1, -56), Parent = body })
	Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(116, 108), CellPadding = UDim2.fromOffset(9, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	views.delveTiles = {}
	for i, f in Finds.LIST do
		if not f.cooked then
			local tile = Ui.new("Frame", { BackgroundColor3 = Ui.INSET, LayoutOrder = i, Parent = grid }, { Ui.corner(UDim.new(0, 10)) })
			local stroke = Ui.stroke(3, Color3.new(0, 0, 0), true)
			stroke.Parent = tile
			local icon = Ui.new("ImageLabel", { BackgroundTransparency = 1, Image = Art.icon(f.id) or "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.62, 0.62), ScaleType = Enum.ScaleType.Fit, Parent = tile })
			local name = Ui.text({ Parent = tile, Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 26), Stroke = 2 })
			local pill = Ui.new("Frame", { BackgroundColor3 = Ui.GOLD, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(44, 24), Visible = false, Parent = tile }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(2, Color3.new(0, 0, 0), true) })
			italic({ Parent = pill, Text = "+" .. Content.DELVE_REWARD, Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2) })
			views.delveTiles[f.id] = { icon = icon, name = name, stroke = stroke, pill = pill, find = f }
		end
	end
	views.delveLog = root
end

function refreshDelveLog()
	if not views.delveLog or not profile then
		return
	end
	local log = profile.delveLog or {}
	local n, total = 0, 0
	for id, t in views.delveTiles do
		total += 1
		local has = log[id] == true
		if has then
			n += 1
		end
		t.icon.ImageColor3 = has and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		t.icon.ImageTransparency = has and 0 or 0.45
		t.name.Text = has and t.find.name or ("? Zone " .. t.find.zone)
		t.name.TextColor3 = has and (Finds.RARITY[t.find.rarity] or Color3.new(1, 1, 1)) or Color3.fromRGB(150, 150, 150)
		t.stroke.Color = has and (Finds.RARITY[t.find.rarity] or Color3.new(0, 0, 0)) or Color3.new(0, 0, 0)
		t.pill.Visible = has and not ((profile.claimed.delveLog or {})[id])
	end
	views.delveCount.Text = "Finds delved    " .. n .. " / " .. total .. "      (claim new ones in the Journal)"
end

local function refreshJournal()
	if not views.journal or not profile then
		return
	end
	local z = Config.ZONES[zoneIndex]
	views.journalZone.Text = z.name
	for i, d in views.journalDots do
		d.BackgroundColor3 = i == zoneIndex and Color3.new(1, 1, 1) or (i <= zoneIndex + 1 and Color3.fromRGB(190, 220, 190) or Color3.fromRGB(40, 40, 40))
	end
	local found = 0
	views.journalNotes:ClearAllChildren()
	for n = 1, Content.NOTES_PER_ZONE do
		local id = "z" .. zoneIndex .. "n" .. n
		local has = profile.notes[id] ~= nil
		if has then
			found += 1
		end
		local col, row = (n - 1) % 3, math.floor((n - 1) / 3)
		card(views.journalNotes, UDim2.new(col / 3, 4, row / 2, 4), UDim2.new(1 / 3, -12, 0.5, -12), has, has and not profile.claimed.notes[id] and Content.NOTE_REWARD or nil, "Note " .. n)
	end
	views.journalAuthor.Text = "Left by " .. Content.NOTE_AUTHORS[zoneIndex] .. "    " .. found .. " / " .. Content.NOTES_PER_ZONE
	views.journalPages:ClearAllChildren()
	local pages = zoneIndex == #Config.ZONES and Content.PAGES_PER_ZONE + 1 or Content.PAGES_PER_ZONE
	local pf = 0
	for n = 1, pages do
		local id = "z" .. zoneIndex .. "p" .. n
		local has = profile.pages[id] ~= nil
		if has then
			pf += 1
		end
		card(views.journalPages, UDim2.new((n - 1) / pages, 6, 0, 0), UDim2.new(1 / pages, -16, 1, 0), has, has and not profile.claimed.pages[id] and Content.PAGE_REWARD or nil, "Page " .. n)
	end
	views.journalPagesTitle.Text = "Journal Pages    " .. pf .. " / " .. pages
	local total = Content.count(profile.notes) + Content.count(profile.pages)
	local all = Content.TOTAL_NOTES + Content.TOTAL_PAGES
	views.journalWhole.Text = "Whole book    " .. total .. " / " .. all .. " found"
	Ui.setFill(views.journalBar, total / all)
	local pending = Content.pendingJournal(profile)
	local claim = views.journalClaim
	claim.Visible = pending > 0
	claim:ClearAllChildren()
	Ui.stroke(4, Color3.new(0, 0, 0), true).Parent = claim
	italic({ Parent = claim, Text = "CLAIM", Size = UDim2.fromOffset(150, 60), Position = UDim2.fromOffset(16, 12), Stroke = 4 })
	deepstoneAmount(claim, tostring(pending), 56, UDim2.fromOffset(170, 14))
end

-- Badges ----------------------------------------------------------------------
local RING = { Distance = Color3.fromRGB(205, 210, 215), Challenges = Color3.fromRGB(176, 120, 230), Crew = Color3.fromRGB(110, 190, 240) }

local function buildBadges()
	local root, body, close = Ui.panel(gui, "Badges", UDim2.fromOffset(900, 560))
	close.Activated:Connect(function()
		show(nil)
	end)
	local left = Ui.inset({ Parent = body, Color = Color3.fromRGB(96, 64, 40), Size = UDim2.new(0.28, -10, 1, 0) })
	Ui.text({ Parent = left, Text = "BADGES", TextColor3 = Ui.GOLD, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 0), Size = UDim2.fromOffset(170, 40) })
	views.badgeCount = italic({ Parent = left, Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.27, 0), Size = UDim2.fromOffset(200, 70), Stroke = 4 })
	local barHolder, fill = Ui.bar({ Parent = left, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.44, 0), Size = UDim2.new(0.8, 0, 0, 32), Color = Ui.GREEN })
	barHolder.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
	views.badgeBar = fill
	views.badgePending = deepstoneAmount(left, "", 46, UDim2.new(0.5, 0, 0.58, 0), Vector2.new(0.5, 0))
	views.badgePending.Size = UDim2.fromOffset(170, 46)
	local claim = Ui.button({ Parent = left, Text = "CLAIM", Color = Ui.GOLD, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.72, 0), Size = UDim2.fromOffset(170, 72) })
	claim.Activated:Connect(function()
		Net.Claim:FireServer("badges")
	end)
	views.badgeClaim = claim
	local right = Ui.inset({ Parent = body, Color = Color3.fromRGB(96, 64, 40), Position = UDim2.new(0.28, 6, 0, 0), Size = UDim2.new(0.72, -6, 1, 0) })
	local scroll = Ui.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = right })
	Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = scroll })
	views.badgeCells = {}
	local order = 0
	for _, group in { "Distance", "Challenges", "Crew" } do
		order += 1
		Ui.text({ Parent = scroll, Text = string.upper(group), TextColor3 = Ui.GOLD, Size = UDim2.new(1, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order })
		order += 1
		local grid = Ui.new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order, Parent = scroll })
		Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(190, 230), CellPadding = UDim2.fromOffset(10, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
		for i, b in Content.BADGES do
			if b.group == group then
				local cell = Ui.new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = grid })
				local ring = Ui.new("Frame", { BackgroundColor3 = RING[group], AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(150, 150), Parent = cell }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(4, Color3.new(0, 0, 0), true) })
				local inner = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(26, 18, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), Parent = ring }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, Color3.new(0, 0, 0), true) })
				Ui.icon(b.icon, { Parent = inner, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72) })
				local check = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 190, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.86, 0.86), Size = UDim2.fromOffset(46, 46), Parent = ring, ZIndex = 3 }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, Color3.new(0, 0, 0), true) })
				Ui.text({ Parent = check, Text = "✓", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 4, Stroke = 2 })
				local dot = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(230, 40, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.86, 0.12), Size = UDim2.fromOffset(26, 26), Parent = ring, ZIndex = 3 }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, Color3.new(0, 0, 0), true) })
				local dim = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 44, 32), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Parent = ring, ZIndex = 2 }, { Ui.corner(UDim.new(0.5, 0)) })
				Ui.text({ Parent = cell, Text = b.name, Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 32) })
				local sub = Ui.text({ Parent = cell, Text = b.desc .. "   +" .. b.reward, TextColor3 = Color3.fromRGB(230, 220, 200), Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 24), Stroke = 2 })
				views.badgeCells[b.id] = { check = check, dot = dot, dim = dim, sub = sub }
			end
		end
	end
	views.badges = root
end

local function refreshBadges()
	if not views.badges or not profile then
		return
	end
	local earned = 0
	for _, b in Content.BADGES do
		local got = b.check(profile)
		local claimed = profile.claimed.badges[b.id] == true
		if got then
			earned += 1
		end
		local c = views.badgeCells[b.id]
		c.check.Visible = got and claimed
		c.dot.Visible = got and not claimed
		c.dim.Visible = not got
	end
	views.badgeCount.Text = earned .. " / " .. #Content.BADGES
	Ui.setFill(views.badgeBar, earned / #Content.BADGES)
	local pending = Content.pendingBadges(profile)
	views.badgePending.Visible = pending > 0
	views.badgePending:FindFirstChildOfClass("TextLabel").Text = "+" .. pending
	views.badgeClaim.Visible = pending > 0
end

-- Your Stats ------------------------------------------------------------------
local function fmtTime(s: number): string
	if not s or s <= 0 then
		return "None yet"
	end
	local h = math.floor(s / 3600)
	local m = math.floor(s % 3600 / 60)
	return h > 0 and (h .. "h " .. m .. "m") or (m .. "m " .. math.floor(s % 60) .. "s")
end

local function readKey(p, key: string)
	local v = p
	for part in string.gmatch(key, "[^%.]+") do
		v = v and v[part]
	end
	return v
end

local function buildStats()
	local root, body, close = Ui.panel(gui, "Your Stats", UDim2.fromOffset(900, 560))
	close.Activated:Connect(function()
		show(nil)
	end)
	local left = Ui.inset({ Parent = body, Color = Color3.fromRGB(96, 64, 40), Size = UDim2.new(0.34, -10, 1, 0) })
	local frame = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(80, 160, 230), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(170, 170), Parent = left }, { Ui.stroke(5, Ui.GOLD, true) })
	views.statsAvatar = Ui.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = frame })
	Ui.text({ Parent = left, Text = player.DisplayName, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 200), Size = UDim2.new(0.9, 0, 0, 40) })
	Ui.text({ Parent = left, Text = "BEST DEPTH", TextColor3 = Ui.GOLD, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 244), Size = UDim2.new(0.6, 0, 0, 30) })
	views.statsBest = italic({ Parent = left, Text = "", TextColor3 = Ui.GOLD, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 278), Size = UDim2.new(0.8, 0, 0, 66), Stroke = 4 })
	local tag = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 170, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 352), Size = UDim2.new(0.86, 0, 0, 52), Parent = left }, { Ui.stroke(4, Color3.new(0, 0, 0), true) })
	views.statsZone = Ui.text({ Parent = tag, Text = "", Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5) })
	views.statsRare = Ui.text({ Parent = left, Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 412), Size = UDim2.new(0.9, 0, 0, 56), TextWrapped = true })
	local right = Ui.inset({ Parent = body, Color = Color3.fromRGB(96, 64, 40), Position = UDim2.new(0.34, 6, 0, 0), Size = UDim2.new(0.66, -6, 1, 0) })
	local scroll = Ui.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = right })
	Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	views.statsRows = {}
	local order = 0
	for _, section in Content.STATS do
		order += 1
		Ui.text({ Parent = scroll, Text = section.title, TextColor3 = Ui.GOLD, Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order })
		for i, row in section.rows do
			order += 1
			local f = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(70, 46, 30), BackgroundTransparency = i % 2 == 0 and 0.3 or 1, BorderSizePixel = 0, Size = UDim2.new(1, -10, 0, 50), LayoutOrder = order, Parent = scroll })
			Ui.text({ Parent = f, Text = row[1], Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.62, 0, 1, -12), TextXAlignment = Enum.TextXAlignment.Left })
			views.statsRows[row[2]] = { label = italic({ Parent = f, Text = "", Position = UDim2.new(0.62, 0, 0, 6), Size = UDim2.new(0.38, -14, 1, -12), TextXAlignment = Enum.TextXAlignment.Right }), kind = row[3] }
		end
	end
	views.stats = root
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		end)
		if ok then
			views.statsAvatar.Image = img
		end
	end)
end

local function refreshStats()
	if not views.stats or not profile then
		return
	end
	views.statsBest.Text = string.format("%.1f mi", profile.bestMiles)
	local _, zoneName = Content.zoneAt(profile.bestMiles)
	views.statsZone.Text = zoneName
	views.statsRare.Text = profile.bestMiles > 0 and "Keep digging: the Core is " .. string.format("%.0f", 100 - profile.bestMiles) .. " miles down" or "Your first descent is waiting!"
	for key, v in views.statsRows do
		local val = readKey(profile, key)
		local text
		if v.kind == "miles" then
			text = string.format("%.1f mi", val or 0)
		elseif v.kind == "time" then
			text = fmtTime(val)
		elseif v.kind == "notes" then
			text = Content.count(val) .. " / " .. Content.TOTAL_NOTES
		elseif v.kind == "pages" then
			text = Content.count(val) .. " / " .. Content.TOTAL_PAGES
		else
			text = tostring(val or 0)
		end
		v.label.Text = text
	end
end

-- public ------------------------------------------------------------------------
function Panels.setProfile(p)
	profile = p
	Panels.refresh()
end

function Panels.refresh()
	refreshRevive()
	refreshClasses()
	refreshJournal()
	refreshDelveLog()
	refreshBadges()
	refreshStats()
end

function Panels.open(name: string)
	local map = {
		CreateParty = views.createParty,
		FreeRevive = views.revive and views.revive.root,
		Classes = views.classes,
		Journal = views.journal,
		Badges = views.badges,
		Stats = views.stats,
	}
	local root = map[name]
	if root then
		if open == root then
			show(nil)
		else
			Panels.refresh()
			show(root)
		end
	end
end

function Panels.isOpen(name: string): boolean
	return open ~= nil and open.Name == name
end

function Panels.init(screen: ScreenGui)
	gui = screen
	buildCreateParty()
	buildFreeRevive()
	buildClasses()
	buildClassCard()
	buildJournal()
	buildDelveLog()
	buildBadges()
	buildStats()
end

return Panels
