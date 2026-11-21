--[[
	The hotbar, built like the reference's (bottom centre): dark rounded slots,
	the slot number top-left, the item's icon, "xN" for a stack, a white outline
	on the one in your hand, and a Bag slot at the end. Resources you collect fly
	into the Bag with the resource's icon and a green "+N" over it.

	Slots: the hand tools first, then your finds in the order you got them.
	1-9 (or a click / tap) equips; again puts it away. The Bag opens a little
	panel with what's in it (glowstone).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ui = require(Shared.Ui)
local Art = require(Shared.Art)
local Finds = require(Shared.Finds)

local Hotbar = {}

local player = Players.LocalPlayer
local TOOL_ORDER = { "Crank Pump", "Pickaxe", "Delver's Hook" }
local TOOL_ICON = { ["Crank Pump"] = "Crank", Pickaxe = "Pickaxe", ["Delver's Hook"] = "DelversHook" }
local SLOT = 84
local GAP = 8
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }

local gui: ScreenGui
local row: Frame
local bagSlot: TextButton
local bagCount: TextLabel
local bagPanel: Frame
local popIcon: ImageLabel
local popText: TextLabel
local slots: { { button: TextButton, icon: ImageLabel, num: TextLabel, count: TextLabel, stroke: UIStroke, tool: Tool? } } = {}
local ordered: { Tool } = {}

local function tools(): { Tool }
	local list = {}
	for _, where in { player:FindFirstChild("Backpack"), player.Character } do
		if where then
			for _, t in where:GetChildren() do
				if t:IsA("Tool") and not (t:GetAttribute("BagOnly") and t.Parent ~= player.Character) then
					table.insert(list, t)
				end
			end
		end
	end
	-- hand tools in their fixed order, then finds in the order they arrived
	table.sort(list, function(a, b)
		local ia, ib = table.find(TOOL_ORDER, a.Name) or 99, table.find(TOOL_ORDER, b.Name) or 99
		if ia ~= ib then
			return ia < ib
		end
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	return list
end

local function iconFor(t: Tool): string?
	local id = t:GetAttribute("Find") or TOOL_ICON[t.Name]
	return id and Art.icon(id) or (t.TextureId ~= "" and t.TextureId or nil)
end

local function toggle(t: Tool?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or not t then
		return
	end
	if t.Parent == char then
		hum:UnequipTools()
	else
		hum:EquipTool(t)
	end
end

local function newSlot(i: number)
	local b = Ui.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(24, 28, 26), BackgroundTransparency = 0.12, Size = UDim2.fromOffset(SLOT, SLOT), LayoutOrder = i, Parent = row }, { Ui.corner(UDim.new(0, 10)) })
	local stroke = Ui.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	local icon = Ui.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.82, 0.82), ScaleType = Enum.ScaleType.Fit, Parent = b })
	local num = Ui.new("TextLabel", { BackgroundTransparency = 1, Text = tostring(i), FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(16, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
	local count = Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -2), Size = UDim2.fromOffset(34, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = b }, { Ui.stroke(1.5, Color3.new(0, 0, 0)) })
	local s = { button = b, icon = icon, num = num, count = count, stroke = stroke, tool = nil }
	b.Activated:Connect(function()
		toggle(s.tool)
	end)
	b.MouseEnter:Connect(function()
		local t = s.tool
		if t then
			Hotbar.tip(t, b)
		end
	end)
	b.MouseLeave:Connect(function()
		Hotbar.tip(nil)
	end)
	return s
end

local tipFrame: Frame
local tipName: TextLabel
local tipRare: TextLabel
local tipDesc: TextLabel
function Hotbar.tip(t: Tool?, over: GuiObject?)
	if not t or not over then
		tipFrame.Visible = false
		return
	end
	local id = t:GetAttribute("Find")
	local f = id and Finds.BY_ID[id]
	tipName.Text = t.Name
	if id == "Glowstone" then
		f = Finds.GLOWSTONE
	end
	tipRare.Visible = f ~= nil
	tipRare.Text = f and f.rarity or ""
	tipRare.BackgroundColor3 = f and Finds.RARITY[f.rarity] or Color3.new(1, 1, 1)
	tipName.TextColor3 = f and Finds.RARITY[f.rarity] or Color3.new(1, 1, 1)
	tipDesc.Text = f and (f.hunger and (f.desc .. "  (+" .. f.hunger .. "% Hunger)") or f.desc) or t.ToolTip
	tipFrame.Position = UDim2.fromOffset(over.AbsolutePosition.X + over.AbsoluteSize.X / 2, over.AbsolutePosition.Y - 8)
	tipFrame.Visible = true
end

local function refresh()
	ordered = tools()
	local char = player.Character
	for i = 1, math.max(#ordered, #slots) do
		local t = ordered[i]
		if t and not slots[i] then
			slots[i] = newSlot(i)
		end
		local s = slots[i]
		if s then
			s.tool = t
			s.button.Visible = t ~= nil
			if t then
				s.icon.Image = iconFor(t) or ""
				local n = t:GetAttribute("Count") or 1
				s.count.Text = n > 1 and ("x" .. n) or ""
				s.stroke.Transparency = (t.Parent == char) and 0 or 1
			end
		end
	end
	bagSlot.LayoutOrder = 100
	local g = player:GetAttribute("Glowstone") or 0
	bagCount.Text = g > 0 and ("x" .. g) or ""
	if bagPanel.Visible then
		Hotbar.fillBag()
	end
end

-- the inventory: everything in your Bag as tiles (icon, xN, name); click one
-- to hold it, click it again to put it away
function Hotbar.fillBag()
	local grid = bagPanel:FindFirstChild("Grid") :: Frame
	for _, c in grid:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	local items = {}
	for _, where in { player:FindFirstChild("Backpack"), player.Character } do
		if where then
			for _, t in where:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("Find") then
					table.insert(items, t)
				end
			end
		end
	end
	table.sort(items, function(a, b)
		-- glowstone first, then finds as they came
		local ga, gb = a:GetAttribute("BagOnly") and 0 or 1, b:GetAttribute("BagOnly") and 0 or 1
		if ga ~= gb then
			return ga < gb
		end
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	local char = player.Character
	for i, t in items do
		local tile = Ui.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(38, 42, 40), LayoutOrder = i, Parent = grid }, { Ui.corner(UDim.new(0, 10)) })
		Ui.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = t.Parent == char and 0 or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tile })
		Ui.new("ImageLabel", { BackgroundTransparency = 1, Image = iconFor(t) or "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.04), Size = UDim2.fromScale(0.72, 0.72), ScaleType = Enum.ScaleType.Fit, Parent = tile })
		local n = t:GetAttribute("Count") or 1
		Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "x" .. n, FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 4), Size = UDim2.fromOffset(40, 18), TextXAlignment = Enum.TextXAlignment.Right, Parent = tile }, { Ui.stroke(1.5, Color3.new(0, 0, 0)) })
		Ui.new("TextLabel", { BackgroundTransparency = 1, Text = t.Name, FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.fromRGB(230, 230, 230), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 16), Parent = tile })
		tile.Activated:Connect(function()
			toggle(t)
			task.defer(Hotbar.fillBag)
		end)
		tile.MouseEnter:Connect(function()
			Hotbar.tip(t, tile)
		end)
		tile.MouseLeave:Connect(function()
			Hotbar.tip(nil)
		end)
	end
	local empty = bagPanel:FindFirstChild("Empty") :: TextLabel
	empty.Visible = #items == 0
end

-- a resource arrived in the Bag: its icon and a green "+N" over the Bag slot,
-- adding up while more keep coming (the reference's "+8" over a log)
local popTotal, popUntil, popKind = 0, 0, ""
function Hotbar.bagPop(kind: string, n: number)
	local now = os.clock()
	if now > popUntil or kind ~= popKind then
		popTotal = 0
	end
	popKind = kind
	popTotal += n
	popUntil = now + 1.6
	popIcon.Image = Art.icon(kind) or ""
	popText.Text = "+" .. popTotal
	popIcon.Visible, popText.Visible = true, true
	popIcon.ImageTransparency, popText.TextTransparency = 0, 0
	popText.Size = UDim2.fromOffset(98, 46)
	TweenService:Create(popText, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(84, 40) }):Play()
	local mine = popUntil
	task.delay(1.65, function()
		if popUntil == mine then
			TweenService:Create(popIcon, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
			TweenService:Create(popText, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
	end)
end

-- where the Bag (or a find's slot) is on screen, for things flying into it
function Hotbar.target(id: string?): Vector2?
	if id then
		for _, s in slots do
			if s.tool and s.tool:GetAttribute("Find") == id and s.button.Visible then
				return s.button.AbsolutePosition + s.button.AbsoluteSize / 2
			end
		end
	end
	return bagSlot.AbsolutePosition + bagSlot.AbsoluteSize / 2
end

-- a slot bumps when something lands in it
function Hotbar.bump(id: string?)
	for _, s in slots do
		if s.tool and s.tool:GetAttribute("Find") == id then
			s.icon.Size = UDim2.fromScale(1.05, 1.05)
			TweenService:Create(s.icon, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.82, 0.82) }):Play()
		end
	end
end

function Hotbar.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	gui = Ui.new("ScreenGui", { Name = "Hotbar", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
	row = Ui.new("Frame", { Name = "Row", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(SLOT * 10 + GAP * 9, SLOT), Parent = gui }, {
		Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	-- the Bag
	bagSlot = Ui.new("TextButton", { Name = "Bag", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(24, 28, 26), BackgroundTransparency = 0.12, Size = UDim2.fromOffset(SLOT, SLOT), LayoutOrder = 100, Parent = row }, { Ui.corner(UDim.new(0, 10)) })
	Ui.new("ImageLabel", { BackgroundTransparency = 1, Image = Art.icon("Bag") or "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.06), Size = UDim2.fromScale(0.62, 0.62), ScaleType = Enum.ScaleType.Fit, Parent = bagSlot })
	Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "Bag", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.fromOffset(40, 17), Parent = bagSlot })
	bagCount = Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.fromRGB(255, 214, 80), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(34, 16), TextXAlignment = Enum.TextXAlignment.Right, Parent = bagSlot }, { Ui.stroke(1.5, Color3.new(0, 0, 0)) })
	popIcon = Ui.new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(50, 50), Visible = false, ZIndex = 3, Parent = bagSlot })
	popText = Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "", FontFace = Ui.ITALIC, TextScaled = true, TextColor3 = Color3.fromRGB(110, 255, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -54), Size = UDim2.fromOffset(84, 40), Visible = false, ZIndex = 3, Parent = bagSlot }, { Ui.stroke(3, Color3.new(0, 0, 0)) })
	-- the inventory panel, opened by the Bag: the hotbar's dark rounded style,
	-- a grid of item tiles
	bagPanel = Ui.new("Frame", { Name = "Inventory", BackgroundColor3 = Color3.fromRGB(22, 26, 24), BackgroundTransparency = 0.06, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(SLOT + 30)), Size = UDim2.fromOffset(560, 330), Visible = false, Parent = gui }, { Ui.corner(UDim.new(0, 14)) })
	Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "Bag", FontFace = Ui.ITALIC, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(160, 34), TextXAlignment = Enum.TextXAlignment.Left, Parent = bagPanel }, { Ui.stroke(2.5, Color3.new(0, 0, 0)) })
	local close = Ui.new("TextButton", { Text = "X", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(220, 50, 50), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(32, 32), Parent = bagPanel }, { Ui.corner(UDim.new(0.3, 0)) })
	close.Activated:Connect(function()
		bagPanel.Visible = false
	end)
	-- (a tile's hover card never outlives the panel)
	bagPanel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not bagPanel.Visible then
			Hotbar.tip(nil)
		end
	end)
	Ui.new("TextLabel", { Name = "Empty", BackgroundTransparency = 1, Text = "Your Bag is empty. Mine glowstone and delve for finds!", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.fromRGB(200, 200, 200), Position = UDim2.fromOffset(20, 140), Size = UDim2.new(1, -40, 0, 26), Visible = false, Parent = bagPanel })
	local gridHolder = Ui.new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -32, 1, -66), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, Parent = bagPanel })
	Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(96, 104), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = gridHolder })
	bagSlot.Activated:Connect(function()
		bagPanel.Visible = not bagPanel.Visible
		if bagPanel.Visible then
			Hotbar.fillBag()
		end
	end)
	-- (B opens it too)
	ContextActionService:BindAction("OpenBag", function(_, st)
		if st == Enum.UserInputState.Begin then
			bagPanel.Visible = not bagPanel.Visible
			if bagPanel.Visible then
				Hotbar.fillBag()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)
	-- the hover card for an item
	tipFrame = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 18, 20), BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(300, 74), Visible = false, ZIndex = 5, Parent = gui }, { Ui.corner(UDim.new(0, 10)) })
	tipName = Ui.new("TextLabel", { BackgroundTransparency = 1, FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.fromRGB(140, 255, 120), Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -110, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = tipFrame })
	tipRare = Ui.new("TextLabel", { BackgroundColor3 = Color3.fromRGB(110, 220, 110), FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 9), Size = UDim2.fromOffset(84, 20), ZIndex = 6, Parent = tipFrame }, { Ui.corner(UDim.new(0.4, 0)) })
	tipDesc = Ui.new("TextLabel", { BackgroundTransparency = 1, FontFace = Ui.FONT, TextScaled = true, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = tipFrame })
	Ui.fit(gui)

	ContextActionService:BindAction("HotbarKeys", function(_, st, input)
		if st ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local i = table.find(KEYS, input.KeyCode)
		if i and ordered[i] then
			toggle(ordered[i])
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(KEYS))

	-- keep it in step with the Backpack, the hand and the counts
	local order = 0
	local function watch(container: Instance)
		container.ChildAdded:Connect(function(t)
			if t:IsA("Tool") then
				if not t:GetAttribute("Order") then
					order += 1
					t:SetAttribute("Order", order)
				end
				t:GetAttributeChangedSignal("Count"):Connect(refresh)
			end
			task.defer(refresh)
		end)
		container.ChildRemoved:Connect(function()
			task.defer(refresh)
		end)
		for _, t in container:GetChildren() do
			if t:IsA("Tool") then
				order += 1
				t:SetAttribute("Order", t:GetAttribute("Order") or order)
				t:GetAttributeChangedSignal("Count"):Connect(refresh)
			end
		end
	end
	player.ChildAdded:Connect(function(c)
		if c:IsA("Backpack") then
			watch(c)
			task.defer(refresh)
		end
	end)
	if player:FindFirstChild("Backpack") then
		watch(player.Backpack)
	end
	player.CharacterAdded:Connect(function(c)
		watch(c)
		task.defer(refresh)
	end)
	if player.Character then
		watch(player.Character)
	end
	player:GetAttributeChangedSignal("Glowstone"):Connect(refresh)
	refresh()
end

return Hotbar
