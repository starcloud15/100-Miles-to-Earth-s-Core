--[[
	UI building blocks in the reference's look: the Cartoon font (Comic Neue
	Angular Bold), white text with a thick black outline, chunky bars with
	black borders, and the icon pack's art (via Art, with a fallback until
	Starport has uploaded it).
]]

local Art = require(script.Parent.Art)

local Ui = {}

Ui.FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
-- the reference sets numbers and HUD labels in a slanted version of the same font
Ui.ITALIC = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
Ui.ROBUX = "rbxasset://textures/ui/common/robux.png" -- Roblox's own Robux glyph, from the client
Ui.ORANGE = Color3.fromRGB(255, 140, 20)
Ui.GREEN = Color3.fromRGB(80, 255, 30)
Ui.RED = Color3.fromRGB(255, 60, 60)
Ui.PURPLE = Color3.fromRGB(200, 30, 255)
Ui.DARK = Color3.fromRGB(26, 26, 26)

function Ui.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class)
	local parent
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- scale a pixel-sized ScreenGui with the screen: full size at 1080 tall, never
-- below half (phones held sideways are about 390 tall). Each top-level element
-- gets its own UIScale, so it shrinks about its anchor (a UIScale on the
-- ScreenGui itself draws buttons away from where their clicks land).
function Ui.fit(gui: ScreenGui, design: number?)
	local camera = workspace.CurrentCamera
	local scales: { UIScale } = {}
	local function value(): number
		return math.clamp(camera.ViewportSize.Y / (design or 1080), 0.5, 1.25)
	end
	local function add(child: Instance)
		if child:IsA("GuiObject") and not child:FindFirstChild("Fit") then
			local s = Instance.new("UIScale")
			s.Name = "Fit"
			s.Scale = value()
			s.Parent = child
			table.insert(scales, s)
		end
	end
	for _, c in gui:GetChildren() do
		add(c)
	end
	gui.ChildAdded:Connect(add)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local v = value()
		for _, s in scales do
			s.Scale = v
		end
	end)
end

-- a soft click on a button (Assets.sounds.Click; nothing until it's uploaded)
function Ui.clickSound(b: GuiButton)
	b.Activated:Connect(function()
		local Art = require(script.Parent.Art)
		local id = Art.sound("Click")
		if id then
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = 0.4
			game:GetService("SoundService"):PlayLocalSound(s)
		end
	end)
end

function Ui.corner(radius: UDim?): UICorner
	return Ui.new("UICorner", { CornerRadius = radius or UDim.new(0, 8) })
end

function Ui.stroke(thickness: number?, color: Color3?, border: boolean?): UIStroke
	return Ui.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Color3.new(0, 0, 0),
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- white text with a black outline, like the reference HUD
function Ui.text(props: { [string]: any }): TextLabel
	local p = {
		BackgroundTransparency = 1,
		FontFace = Ui.FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Text = "",
	}
	for k, v in props do
		if k ~= "Stroke" then
			p[k] = v
		end
	end
	local label = Ui.new("TextLabel", p)
	local stroke = Ui.stroke(props.Stroke or 3)
	stroke.Parent = label
	return label
end

-- an icon from the pack; until Starport has uploaded it, a rounded tile with
-- the name's first letter
function Ui.icon(name: string, props: { [string]: any }): GuiObject
	local id = Art.icon(name)
	if id then
		local p = { BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit }
		for k, v in props do
			if k ~= "FallbackColor" then
				p[k] = v
			end
		end
		return Ui.new("ImageLabel", p)
	end
	local p = { BackgroundColor3 = props.FallbackColor or Color3.fromRGB(255, 196, 60), Name = props.Name or name }
	for k, v in props do
		if k ~= "FallbackColor" then
			p[k] = v
		end
	end
	local tile = Ui.new("Frame", p, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, nil, true) })
	Ui.text({
		Parent = tile,
		Size = UDim2.fromScale(1, 1),
		Text = string.sub(name, 1, 1),
		Stroke = 2,
	})
	return tile
end

-- a labelled bar like the reference's Hunger and Health bars
function Ui.bar(props: { [string]: any }): (Frame, Frame)
	local holder = Ui.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Parent = props.Parent,
		Name = props.Name or "Bar",
	})
	local fill = Ui.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = props.Color or Ui.GREEN,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		Parent = holder,
	})
	if props.Label then
		Ui.text({
			Parent = holder,
			Text = props.Label,
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, -34),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	return holder, fill
end

function Ui.setFill(fill: Frame, frac: number)
	frac = math.clamp(frac, 0, 1)
	fill.Size = UDim2.new(frac, -8 * frac, 1, -8)
end

-- the reference's panels: a plank board with a black border and nails, dark
-- inset boxes, a big white title outside the top-left and a red X
Ui.WOOD = Color3.fromRGB(141, 96, 60)
Ui.WOOD_LINE = Color3.fromRGB(120, 80, 48)
Ui.INSET = Color3.fromRGB(58, 40, 26)
Ui.SLATE = Color3.fromRGB(76, 84, 98)
Ui.GOLD = Color3.fromRGB(255, 214, 80)
Ui.BUTTON_GREEN = Color3.fromRGB(96, 220, 80)

function Ui.button(props: { [string]: any }): TextButton
	local b = Ui.new("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = props.Color or Ui.BUTTON_GREEN,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}, { Ui.stroke(props.Border or 4, Color3.new(0, 0, 0), true) })
	if props.Gradient ~= false then
		Ui.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)), Parent = b })
	end
	if props.Text then
		Ui.text({ Name = "Label", Parent = b, Text = props.Text, Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6), Stroke = props.TextStroke or 3 })
		Ui.clickSound(b)
	end
	return b
end

function Ui.inset(props: { [string]: any }): Frame
	local f = Ui.new("Frame", {
		Name = props.Name or "Inset",
		BackgroundColor3 = props.Color or Ui.INSET,
		BorderSizePixel = 0,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}, { Ui.stroke(3, Color3.new(0, 0, 0), true) })
	return f
end

-- returns the panel's root, its body (inside the border) and the close button
function Ui.panel(parent: Instance, title: string, size: UDim2): (Frame, Frame, TextButton)
	local root = Ui.new("Frame", {
		Name = title:gsub("%s", ""),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = size,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(size.X.Offset, size.Y.Offset), Parent = root })
	local board = Ui.new("Frame", { Name = "Board", BackgroundColor3 = Ui.WOOD, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = root }, { Ui.stroke(5, Color3.new(0, 0, 0), true) })
	for i = 1, 5 do
		Ui.new("Frame", { BackgroundColor3 = Ui.WOOD_LINE, BorderSizePixel = 0, Position = UDim2.fromScale(0, i / 6), Size = UDim2.new(1, 0, 0, 2), Parent = board })
		for _, x in { 0, 1 } do
			Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(70, 46, 28), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, x == 0 and 14 or -14, (i - 0.5) / 6, 0), Size = UDim2.fromOffset(6, 6), Parent = board }, { Ui.corner(UDim.new(0.5, 0)) })
		end
	end
	local body = Ui.new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 22), Size = UDim2.new(1, -56, 1, -44), Parent = board })
	Ui.text({ Name = "Title", Parent = root, Text = title, Position = UDim2.fromOffset(0, -62), Size = UDim2.fromOffset(math.max(260, #title * 30), 62), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 5 })
	local close = Ui.new("TextButton", { Name = "Close", BackgroundTransparency = 1, Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 8, 0, -4), Size = UDim2.fromOffset(60, 60), Parent = root })
	Ui.text({ Parent = close, Text = "X", TextColor3 = Color3.fromRGB(235, 30, 30), Size = UDim2.fromScale(1, 1), Stroke = 4 })
	return root, body, close
end

-- a big "+25 DEEPSTONES" in the middle of the screen
function Ui.pop(parent: Instance, text: string, color: Color3?)
	local TweenService = game:GetService("TweenService")
	local label = Ui.text({ Parent = parent, Text = text, TextColor3 = color or Ui.GOLD, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(300, 50), Stroke = 5, ZIndex = 50 })
	TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(640, 96) }):Play()
	task.delay(1.8, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.35) }):Play()
		TweenService:Create(label.UIStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		task.delay(0.6, function()
			label:Destroy()
		end)
	end)
end

return Ui
