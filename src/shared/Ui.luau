--[[
	UI building blocks in the reference's look: the Cartoon font (Comic Neue
	Angular Bold), white text with a thick black outline, chunky bars with
	black borders, and the icon pack's art (via Art, with a fallback until
	Starport has uploaded it).
]]

local Art = require(script.Parent.Art)

local Ui = {}

Ui.FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
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
			p[k] = v
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

return Ui
