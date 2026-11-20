--[[
	The Journal note popup (docs/research/frames seg-1 §2, seg-2): a cream paper
	card in the middle of a dimmed screen, a grey tape strip at the top, a red
	tilted "NEW!" pill top left, a red hand-drawn X top right, a charcoal sketch
	in the top half, one or two lines of dark text and an italic signature.
	Journal Pages are headed "Journal Page" with a smaller sketch. A board with
	several entries flips between them.

	Sketches are images from Starport (assets/ui/sketches/<id>.png, made by
	tools/blender/sketches.py); until uploaded, a pencil-hatched blank.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Art = require(Shared.Art)
local Story = require(Shared.Story)
local Ui = require(Shared.Ui)

local Journal = {}

local PAPER = Color3.fromRGB(242, 232, 206)
local INK = Color3.fromRGB(52, 42, 34)
local RED = Color3.fromRGB(222, 40, 36)

local gui: ScreenGui
local card: Frame
local el = {}
local entries = {}
local index = 1

local function sketchFor(id: string): string?
	-- a sketch of its own, or the zone's
	return Art.get("sketches", id) or Art.get("sketches", id:match("^z%d+") or "")
end

local function hatch(parent: Instance)
	-- a blank sketch: loose pencil strokes (unrotated, so the frame clips them)
	local rng = Random.new(7)
	for i = 1, 16 do
		local w = rng:NextNumber(0.2, 0.7)
		Ui.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(150, 140, 120),
			BackgroundTransparency = rng:NextNumber(0.6, 0.85),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95 - w), i / 17),
			Size = UDim2.new(w, 0, 0, 2),
			Parent = parent,
		})
	end
end

local function show()
	local e = entries[index]
	if not e then
		return
	end
	local kind, text, by = Story.entry(e.id)
	local isPage = kind == "page"
	el.heading.Visible = isPage
	el.new.Visible = e.new
	el.sketchFrame.Position = UDim2.fromScale(0.5, isPage and 0.2 or 0.08)
	el.sketchFrame.Size = UDim2.fromScale(0.84, isPage and 0.34 or 0.46)
	local img = sketchFor(e.id)
	el.sketch.Image = img or ""
	el.blank.Visible = img == nil
	el.text.Position = UDim2.fromScale(0.5, isPage and 0.57 or 0.57)
	el.text.Size = UDim2.fromScale(0.84, isPage and 0.28 or 0.24)
	el.text.Text = text or ""
	el.by.Text = "– " .. (by or "")
	el.prev.Visible = #entries > 1
	el.next.Visible = #entries > 1
	el.count.Visible = #entries > 1
	el.count.Text = ("%d / %d"):format(index, #entries)
	-- a little tilt per page, like loose paper
	card.Rotation = (index % 2 == 0) and 1.2 or -1.2
end

local function close()
	if not gui.Enabled then
		return
	end
	ContextActionService:UnbindAction("JournalClose")
	TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(0.02, 0.05) }):Play()
	task.delay(0.15, function()
		gui.Enabled = false
	end)
end

function Journal.open(list: { { id: string, new: boolean } })
	entries = list
	-- new ones first
	table.sort(entries, function(a, b)
		if a.new ~= b.new then
			return a.new
		end
		return a.id < b.id
	end)
	index = 1
	show()
	gui.Enabled = true
	card.Size = UDim2.fromScale(0.05, 0.1)
	TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.3, 0.74) }):Play()
	ContextActionService:BindAction("JournalClose", function(_, st)
		if st == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
end

function Journal.init()
	gui = Ui.new("ScreenGui", { Name = "JournalNote", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	local dim = Ui.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Parent = gui })
	dim.Activated:Connect(close)

	card = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.74),
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		Ui.new("UICorner", { CornerRadius = UDim.new(0.015, 0) }),
		Ui.new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(196, 180, 146) }),
		-- paper that has been folded and carried: a faint warm vignette
		Ui.new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.8, Color3.fromRGB(250, 246, 236)), ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 212, 182)) }) }),
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 0.62 }),
	}) :: Frame

	-- the tape strip
	Ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.0), Size = UDim2.fromScale(0.34, 0.055), Rotation = 3, BackgroundColor3 = Color3.fromRGB(214, 212, 200), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 3, Parent = card })

	-- NEW! and the red X
	el.new = Ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.08, 0.035), Size = UDim2.fromScale(0.26, 0.065), Rotation = -14, BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 4, Parent = card }, {
		Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Ui.new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(120, 10, 10), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	Ui.text({ Parent = el.new, Text = "NEW!", FontFace = Ui.ITALIC, Size = UDim2.fromScale(0.86, 0.8), Position = UDim2.fromScale(0.07, 0.1), Stroke = 2, ZIndex = 5 })
	local x = Ui.new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.93, 0.04), Size = UDim2.fromScale(0.12, 0.08), BackgroundTransparency = 1, Text = "X", FontFace = Ui.ITALIC, TextScaled = true, TextColor3 = RED, Rotation = 6, ZIndex = 5, Parent = card }, {
		Ui.new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(120, 10, 10) }),
	})
	x.Activated:Connect(close)

	el.heading = Ui.text({ Parent = card, Text = "Journal Page", FontFace = Ui.ITALIC, TextColor3 = INK, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.075), Size = UDim2.fromScale(0.7, 0.08), Stroke = 0 })

	-- the sketch
	el.sketchFrame = Ui.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(236, 226, 200), BorderSizePixel = 0, ClipsDescendants = true, Parent = card }, {
		Ui.new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(150, 136, 110) }),
	})
	el.blank = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = el.sketchFrame })
	hatch(el.blank)
	el.sketch = Ui.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, Parent = el.sketchFrame })

	-- the words, and who wrote them
	el.text = Ui.new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, FontFace = Ui.FONT, TextColor3 = INK, TextScaled = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = card }, {
		Ui.new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 10 }),
	})
	el.by = Ui.new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.92, 0.86), Size = UDim2.fromScale(0.8, 0.06), BackgroundTransparency = 1, FontFace = Ui.ITALIC, TextColor3 = INK, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })

	-- flipping between a board's entries
	local function arrow(text: string, xPos: number, dir: number)
		local b = Ui.new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(xPos, 0.5), Size = UDim2.fromScale(0.13, 0.08), BackgroundColor3 = PAPER, Text = text, FontFace = Ui.ITALIC, TextScaled = true, TextColor3 = INK, ZIndex = 5, Parent = card }, {
			Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Ui.new("UIStroke", { Thickness = 2, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		b.Activated:Connect(function()
			index = (index - 1 + dir) % #entries + 1
			show()
		end)
		return b
	end
	el.prev = arrow("<", -0.08, -1)
	el.next = arrow(">", 1.08, 1)
	el.count = Ui.text({ Parent = card, Text = "", TextColor3 = Color3.fromRGB(120, 108, 90), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.93), Size = UDim2.fromScale(0.3, 0.045), Stroke = 0 })
end

return Journal
