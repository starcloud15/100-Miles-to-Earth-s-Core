--[[
	The Game place HUD, built 1:1 on the reference's (docs/match-spec.md §1-2;
	positions are the measured centres and sizes as fractions of the screen).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Ui = require(Shared.Ui)

local Hud = {}
local player = Players.LocalPlayer
local gui: ScreenGui
local el: { [string]: any } = {}

local BLACK = Color3.new(0, 0, 0)
local YELLOW = Color3.fromRGB(255, 214, 40)
local OBJ_COLORS = { white = "#FFFFFF", orange = "#FF8C14", red = "#FF3B30" }

local function at(x: number, y: number, w: number, h: number): (UDim2, UDim2, Vector2)
	return UDim2.fromScale(x, y), UDim2.fromScale(w, h), Vector2.new(0.5, 0.5)
end

local function frame(props)
	local f = Ui.new("Frame", { BackgroundTransparency = 1, Parent = props.Parent or gui })
	for k, v in props do
		if k ~= "Parent" then
			(f :: any)[k] = v
		end
	end
	return f
end

local function italic(props)
	local l = Ui.text(props)
	l.FontFace = Ui.ITALIC
	return l
end

local function circle(parent, color: Color3, scale: number)
	return Ui.new("Frame", { BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale), Parent = parent }, { Ui.corner(UDim.new(0.5, 0)) })
end

-- a ring of segments, used for the speedometer and the day badge's arc
local function ring(parent, count: number, from: number, to: number, radius: number, segW: number, segH: number)
	local segs = {}
	for i = 1, count do
		local a = math.rad(from + (to - from) * (i - 1) / (count - 1))
		segs[i] = Ui.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(60, 60, 64),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(a) * radius, 0.5 - math.cos(a) * radius),
			Size = UDim2.fromScale(segW, segH),
			Rotation = math.deg(a),
			Parent = parent,
		})
	end
	return segs
end

local function build()
	gui = Ui.new("ScreenGui", { Name = "Hud", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	-- distance: "0.0 Miles" -----------------------------------------------------
	local pos, size, anchor = at(0.46, 0.108, 0.195, 0.066)
	el.miles = italic({ Name = "Miles", Parent = gui, Position = pos, Size = size, AnchorPoint = anchor, Text = "0 Miles", Stroke = 4 })
	el.milesHome = { pos = pos, size = size }

	-- the day badge --------------------------------------------------------------
	pos, size, anchor = at(0.61, 0.106, 0.055, 0.055)
	local badge = frame({ Name = "DayBadge", Position = pos, Size = size, AnchorPoint = anchor })
	Ui.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = badge })
	circle(badge, BLACK, 1)
	el.badgeArc = ring(badge, 28, 0, 350, 0.4, 0.13, 0.14)
	el.badgeDisc = circle(badge, Color3.fromRGB(110, 190, 240), 0.66)
	el.badgeSun = Ui.icon("Day", { Parent = el.badgeDisc, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8) })
	el.badgeMoon = Ui.icon("Night", { Parent = el.badgeDisc, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), Visible = false, FallbackColor = Color3.fromRGB(230, 230, 255) })
	el.badge = badge
	el.badgeHome = { pos = pos, size = size }

	-- objective line -------------------------------------------------------------
	pos, size, anchor = at(0.505, 0.186, 0.35, 0.038)
	el.objective = italic({ Name = "Objective", Parent = gui, Position = pos, Size = size, AnchorPoint = anchor, Text = "", RichText = true, Stroke = 3 })
	el.objIconHolder = frame({ Parent = el.objective, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.08, 1.2) })
	Ui.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = el.objIconHolder })

	-- route bar: 6 zones sized by their miles --------------------------------------
	pos, size, anchor = at(0.5, 0.23, 0.224, 0.023)
	local bar = Ui.new("Frame", { Name = "RouteBar", BackgroundColor3 = Color3.fromRGB(24, 24, 24), BorderSizePixel = 0, Position = pos, Size = size, AnchorPoint = anchor, Parent = gui }, { Ui.stroke(3, BLACK, true) })
	local total = 0
	for _, z in Config.ZONES do
		total += z.miles
	end
	local x = 0
	local tones = { Color3.fromRGB(56, 88, 52), Color3.fromRGB(84, 92, 48), Color3.fromRGB(70, 84, 110), Color3.fromRGB(58, 96, 66), Color3.fromRGB(104, 78, 54), Color3.fromRGB(76, 80, 90) }
	for i, z in Config.ZONES do
		Ui.new("Frame", { BackgroundColor3 = tones[i], BorderSizePixel = 0, Position = UDim2.new(x, 1, 0.15, 0), Size = UDim2.new(z.miles / total, -2, 0.7, 0), Parent = bar })
		x += z.miles / total
	end
	el.barDone = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(110, 220, 90), BackgroundTransparency = 0.25, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.15), Size = UDim2.fromScale(0, 0.7), ZIndex = 2, Parent = bar })
	Ui.new("Frame", { BackgroundColor3 = YELLOW, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 5, 1.7, 0), ZIndex = 3, Parent = bar }, { Ui.stroke(1.5, BLACK, true) })
	el.barMarker = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 5, 1.7, 0), ZIndex = 4, Parent = bar }, { Ui.stroke(1.5, BLACK, true) })
	el.bar = bar
	el.totalMiles = total

	-- Starter Pack: the Glow Mole portrait with its price ----------------------------
	pos, size, anchor = at(0.044, 0.324, 0.045, 0.08)
	local pack = frame({ Name = "StarterPack", Position = pos, Size = size, AnchorPoint = anchor })
	Ui.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = pack })
	circle(pack, Color3.fromRGB(120, 76, 40), 1)
	local inner = circle(pack, Color3.fromRGB(250, 226, 190), 0.84)
	Ui.icon("GlowMole", { Parent = inner, Size = UDim2.fromScale(1, 1), FallbackColor = Color3.fromRGB(160, 120, 100) })
	local pill = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(214, 0, 230), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.15, 0.08), Size = UDim2.fromScale(0.85, 0.36), Parent = pack }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(2, BLACK, true) })
	Ui.new("ImageLabel", { BackgroundTransparency = 1, Image = Ui.ROBUX, Position = UDim2.fromScale(0.08, 0.15), Size = UDim2.fromScale(0.3, 0.7), Parent = pill }, { Ui.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	Ui.text({ Parent = pill, Text = "49", Position = UDim2.fromScale(0.4, 0.05), Size = UDim2.fromScale(0.55, 0.9), Stroke = 2 })

	-- Hunger and Health --------------------------------------------------------------
	for _, b in { { "Hunger", 0.46, Color3.fromRGB(255, 138, 26) }, { "Health", 0.539, Color3.fromRGB(76, 255, 26) } } do
		pos, size, anchor = at(0.063, b[2], 0.117, 0.027)
		local holder = Ui.new("Frame", { Name = b[1], BackgroundColor3 = Color3.fromRGB(40, 40, 40), BorderSizePixel = 0, Position = pos, Size = size, AnchorPoint = anchor, Parent = gui }, { Ui.stroke(3, BLACK, true) })
		el[b[1]] = Ui.new("Frame", { BackgroundColor3 = b[3], BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = holder })
		Ui.text({ Parent = gui, Text = b[1], AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.005, b[2] - 0.016), Size = UDim2.fromScale(0.06, 0.032), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5 })
	end
	-- the zone's temperature (Cold / Heat), under Health, in the zones that have one
	pos, size, anchor = at(0.063, 0.618, 0.117, 0.027)
	el.tempHolder = Ui.new("Frame", { Name = "Exposure", BackgroundColor3 = Color3.fromRGB(40, 40, 40), BorderSizePixel = 0, Position = pos, Size = size, AnchorPoint = anchor, Visible = false, Parent = gui }, { Ui.stroke(3, BLACK, true) })
	el.temp = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(120, 196, 255), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = el.tempHolder })
	el.tempLabel = Ui.text({ Parent = gui, Text = "Cold", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.005, 0.618 - 0.016), Size = UDim2.fromScale(0.06, 0.032), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5, Visible = false })

	-- speedometer and Turbo -------------------------------------------------------------
	pos, size, anchor = at(0.925, 0.43, 0.093, 0.165)
	local speedo = frame({ Name = "Speedo", Position = pos, Size = size, AnchorPoint = anchor })
	Ui.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = speedo })
	circle(speedo, Color3.fromRGB(30, 30, 32), 1).ZIndex = 0
	el.ticks = ring(speedo, 40, -135, 135, 0.4, 0.03, 0.13)
	el.mph = italic({ Parent = speedo, Text = "0", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.62, 0.36), Stroke = 4 })
	italic({ Parent = speedo, Text = "MPH", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.42, 0.17), Stroke = 2.5 })
	el.speedo = speedo
	pos, size, anchor = at(0.925, 0.50, 0.08, 0.04)
	local turbo = Ui.new("Frame", { Name = "Turbo", BackgroundColor3 = Color3.fromRGB(255, 140, 20), Position = pos, Size = size, AnchorPoint = anchor, Parent = gui }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, BLACK, true) })
	Ui.icon("Turbo", { Parent = turbo, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.02, 0.45), Size = UDim2.fromScale(0.42, 1.5) })
	italic({ Parent = turbo, Text = "TURBO", Position = UDim2.fromScale(0.24, 0.06), Size = UDim2.fromScale(0.7, 0.88), Stroke = 2.5 })
	local key = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.97, -0.05), Size = UDim2.fromScale(0.2, 0.75), Parent = turbo }, { Ui.corner(UDim.new(0.15, 0)), Ui.stroke(2, BLACK, true) })
	Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "T", FontFace = Ui.FONT, TextScaled = true, TextColor3 = BLACK, Size = UDim2.fromScale(1, 1), Parent = key })
	local price = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(150, 40, 230), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.62, 0.8), Size = UDim2.fromScale(0.42, 0.62), Parent = turbo }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(2, BLACK, true) })
	Ui.new("ImageLabel", { BackgroundTransparency = 1, Image = Ui.ROBUX, Position = UDim2.fromScale(0.08, 0.15), Size = UDim2.fromScale(0.32, 0.7), Parent = price }, { Ui.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	Ui.text({ Parent = price, Text = "25", Position = UDim2.fromScale(0.42, 0.05), Size = UDim2.fromScale(0.52, 0.9), Stroke = 2 })
	el.turbo = turbo

	-- action hint ------------------------------------------------------------------------
	pos, size, anchor = at(0.955, 0.962, 0.071, 0.04)
	local hint = Ui.new("Frame", { Name = "Hint", BackgroundColor3 = Color3.fromRGB(20, 20, 22), BackgroundTransparency = 0.25, Position = pos, Size = size, AnchorPoint = anchor, Parent = gui }, { Ui.corner(UDim.new(0.2, 0)) })
	local cap = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromScale(0.05, 0.12), Size = UDim2.fromScale(0.38, 0.76), Parent = hint }, { Ui.corner(UDim.new(0.25, 0)) })
	local UIS = game:GetService("UserInputService")
	local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	Ui.new("TextLabel", { BackgroundTransparency = 1, Text = touch and "Tap" or "Click", FontFace = Ui.FONT, TextScaled = true, TextColor3 = BLACK, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Parent = cap })
	el.hintVerb = Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "Crank", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromScale(0.47, 0.12), Size = UDim2.fromScale(0.5, 0.76), Parent = hint })
	el.hint = hint

	-- (glowstone and finds live in the hotbar now: client/Hotbar.luau)
	-- the second hint, "G Drop", while you hold a find (like the reference's food)
	pos, size, anchor = at(0.955, 0.912, 0.071, 0.04)
	local drop = Ui.new("TextButton", { Name = "DropHint", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(20, 20, 22), BackgroundTransparency = 0.25, Position = pos, Size = size, AnchorPoint = anchor, Visible = false, Parent = gui }, { Ui.corner(UDim.new(0.2, 0)) })
	local dcap = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromScale(0.05, 0.12), Size = UDim2.fromScale(0.38, 0.76), Parent = drop }, { Ui.corner(UDim.new(0.25, 0)) })
	Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "G", FontFace = Ui.FONT, TextScaled = true, TextColor3 = BLACK, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), Parent = dcap })
	Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "Drop", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromScale(0.47, 0.12), Size = UDim2.fromScale(0.5, 0.76), Parent = drop })
	el.dropHint = drop
	-- (tap it on a phone: there's no G key)
	drop.Activated:Connect(function()
		require(Shared.Net).Drop:FireServer()
	end)

	-- boarding: BOARD THE RIG! / LEAVING IN 30 / ALL ABOARD! ---------------------------------
	pos, size, anchor = at(0.5, 0.10, 0.35, 0.06)
	el.boardTitle = italic({ Parent = gui, Position = pos, Size = size, AnchorPoint = anchor, Text = "", RichText = true, Stroke = 4, Visible = false })
	el.boardRow = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.195), Size = UDim2.fromScale(0.3, 0.092), Visible = false })
	Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.01, 0), Parent = el.boardRow })
	el.boardText = italic({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.27), Size = UDim2.fromScale(0.3, 0.035), Text = "", RichText = true, Stroke = 2.5, Visible = false })

	-- RIG IS LEAVING (you're off it while it counts down) ------------------------------------
	el.leavingTitle = italic({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.045), Size = UDim2.fromScale(0.3, 0.05), Text = "RIG IS LEAVING", TextColor3 = Color3.fromRGB(255, 140, 20), Stroke = 3, Visible = false })
	local lbar = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 30, 20), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.095), Size = UDim2.fromScale(0.25, 0.03), Visible = false, Parent = gui }, { Ui.stroke(3, BLACK, true) })
	el.leavingFill = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 140, 20), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = lbar })
	el.leavingBar = lbar
	el.leavingSub = italic({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.135), Size = UDim2.fromScale(0.2, 0.03), Text = "Get back to the rig", Stroke = 2, Visible = false })

	-- DON'T GET LEFT BEHIND! ---------------------------------------------------------------------
	el.vignette = frame({ Name = "Vignette", Size = UDim2.fromScale(1, 1), ZIndex = 0, Visible = false })
	for i, rot in { 0, 90, 180, 270 } do
		Ui.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(220, 0, 0),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(i == 2 and 0.92 or (i == 4 and 0.08 or 0.5), i == 1 and 0.08 or (i == 3 and 0.92 or 0.5)),
			Size = (i % 2 == 1) and UDim2.fromScale(1, 0.16) or UDim2.fromScale(0.16, 1),
			Parent = el.vignette,
		}, { Ui.new("UIGradient", { Rotation = rot + 90, Transparency = NumberSequence.new(0.35, 1) }) })
	end
	el.behindTitle = italic({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.503, 0.109), Size = UDim2.fromScale(0.39, 0.053), Text = "DON'T GET LEFT BEHIND!", TextColor3 = Color3.fromRGB(255, 50, 50), Stroke = 4, Visible = false })
	local bbar = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 20, 20), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.169), Size = UDim2.fromScale(0.25, 0.032), Visible = false, Parent = gui }, { Ui.stroke(3, BLACK, true) })
	el.behindFill = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(235, 30, 30), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = bbar })
	el.behindBar = bbar
	el.behindSub = italic({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.218), Size = UDim2.fromScale(0.25, 0.032), Text = "Slide back to the rig", Stroke = 2, Visible = false })

	-- the RIG marker: on the rig, or clamped to the screen edge ---------------------------------
	local marker = frame({ Name = "RigMarker", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromScale(0.05, 0.11), Visible = false })
	local tag = Ui.new("Frame", { BackgroundColor3 = YELLOW, Size = UDim2.fromScale(1, 0.32), Parent = marker }, { Ui.stroke(2, BLACK, true) })
	Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "RIG", FontFace = Ui.ITALIC, TextScaled = true, TextColor3 = BLACK, Size = UDim2.fromScale(1, 1), Parent = tag })
	el.markerDist = Ui.text({ Parent = marker, Text = "", Position = UDim2.fromScale(0, 0.34), Size = UDim2.fromScale(1, 0.26), Stroke = 2 })
	local secs = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(220, 30, 30), Position = UDim2.fromScale(0.15, 0.62), Size = UDim2.fromScale(0.7, 0.26), Parent = marker }, { Ui.stroke(2, BLACK, true) })
	el.markerSecs = Ui.text({ Parent = secs, Text = "", Size = UDim2.fromScale(1, 1), Stroke = 2 })
	el.markerSecsBox = secs
	el.marker = marker

	-- PULLED BACK (the reference's SWEPT AWAY) ----------------------------------------------------
	local pulled = Ui.new("Frame", { Name = "PulledBack", BackgroundColor3 = Color3.fromRGB(70, 44, 26), Size = UDim2.fromScale(1, 1), ZIndex = 40, Visible = false, Parent = gui }, {
		Ui.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 96, 52), Color3.fromRGB(40, 24, 14)) }),
	})
	italic({ Parent = pulled, Text = "PULLED BACK", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.5, 0.1), Stroke = 4, ZIndex = 41 })
	italic({ Parent = pulled, Text = "The winch hauled you back to the rig", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.4, 0.04), Stroke = 2, ZIndex = 41 })
	el.pulled = pulled

	-- stop name, banners, toasts ----------------------------------------------------------------
	el.stopName = italic({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.5, 0.09), Text = "", TextColor3 = Color3.fromRGB(255, 186, 40), Stroke = 4, Visible = false })
	el.toast = italic({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.4, 0.06), Text = "", Stroke = 4, Visible = false })

	-- the night bar: moon, bar, sun and the multiplier; crew in the ring --------------------------
	local night = frame({ Name = "Night", Size = UDim2.fromScale(1, 1), Visible = false })
	Ui.icon("Night", { Parent = night, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.326, 0.126), Size = UDim2.fromScale(0.03, 0.054), FallbackColor = Color3.fromRGB(230, 230, 255) })
	local nbar = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.472, 0.126), Size = UDim2.fromScale(0.248, 0.036), Parent = night }, { Ui.stroke(3, BLACK, true) })
	el.nightFill = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(50, 90, 230), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = nbar })
	Ui.icon("Day", { Parent = night, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.618, 0.126), Size = UDim2.fromScale(0.03, 0.054) })
	el.nightMult = italic({ Parent = night, Text = "", TextColor3 = YELLOW, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.64, 0.126), Size = UDim2.fromScale(0.05, 0.05), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3 })
	el.ringRow = frame({ Parent = night, Position = UDim2.fromScale(0.305, 0.168), Size = UDim2.fromScale(0.2, 0.064) })
	Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.02, 0), Parent = el.ringRow })
	el.ringText = italic({ Parent = night, Text = "", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.47, 0.2), Size = UDim2.fromScale(0.42, 0.03), TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Stroke = 2 })
	el.night = night
end

-- portraits for the boarding and ring rows ------------------------------------------------------
local thumbs: { [number]: string } = {}
local function portrait(parent, userId: number, on: boolean, widthScale: number)
	local f = Ui.new("Frame", { BackgroundColor3 = on and Color3.fromRGB(60, 190, 70) or Color3.fromRGB(40, 40, 44), BackgroundTransparency = on and 0 or 0.35, Size = UDim2.fromScale(widthScale, 1), Parent = parent }, { Ui.stroke(2.5, BLACK, true), Ui.new("UIAspectRatioConstraint", { AspectRatio = 0.9 }) })
	local img = Ui.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ImageTransparency = on and 0 or 0.5, Parent = f })
	if thumbs[userId] then
		img.Image = thumbs[userId]
	else
		task.spawn(function()
			local ok, t = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok then
				thumbs[userId] = t
				img.Image = t
			end
		end)
	end
	if on then
		local tick = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 200, 60), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1.05, 1.05), Size = UDim2.fromScale(0.4, 0.4), ZIndex = 3, Parent = f }, { Ui.stroke(2, BLACK, true) })
		Ui.text({ Parent = tick, Text = "✓", Size = UDim2.fromScale(1, 1), ZIndex = 4, Stroke = 1.5 })
	end
end

local lastRow = ""
local function crewRow(parent, onFn: (Player) -> boolean, widthScale: number)
	local sig = ""
	local list = Players:GetPlayers()
	for _, p in list do
		sig ..= p.UserId .. (onFn(p) and "1" or "0")
	end
	if parent:GetAttribute("Sig") == sig then
		return
	end
	parent:SetAttribute("Sig", sig)
	for _, c in parent:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for _, p in list do
		portrait(parent, p.UserId, onFn(p), widthScale)
	end
end

-- public --------------------------------------------------------------------------------------
local toastSeq = 0
function Hud.toast(text: string, color: Color3?, seconds: number?)
	toastSeq += 1
	local me = toastSeq
	local t = el.toast
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Visible = true
	t.Size = UDim2.fromScale(0.3, 0.045)
	TweenService:Create(t, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.4, 0.06) }):Play()
	task.delay(seconds or 1.8, function()
		if me == toastSeq then
			t.Visible = false
		end
	end)
end

function Hud.stopName(name: string)
	local s = el.stopName
	s.Text = name
	s.Visible = true
	s.Size = UDim2.fromScale(0.15, 0.03)
	TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.5, 0.09) }):Play()
	task.delay(2, function()
		s.Visible = false
	end)
end

function Hud.pulledBack()
	local p = el.pulled
	p.Position = UDim2.fromScale(0, 0)
	p.Visible = true
	task.delay(2.6, function()
		TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0, -1) }):Play()
		task.delay(0.55, function()
			p.Visible = false
		end)
	end)
end

function Hud.setHint(verb: string?, canDrop: boolean?)
	el.hint.Visible = verb ~= nil
	if verb then
		el.hintVerb.Text = verb
	end
	el.dropHint.Visible = canDrop == true
end

local lastTenth, compact = -1, false
local function setCompact(on: boolean)
	if on == compact then
		return
	end
	compact = on
	local info = TweenInfo.new(0.25)
	if on then
		TweenService:Create(el.miles, info, { Position = UDim2.fromScale(0.475, 0.055), Size = UDim2.fromScale(0.1, 0.034), TextTransparency = 0.35 }):Play()
		TweenService:Create(el.badge, info, { Position = UDim2.fromScale(0.545, 0.055), Size = UDim2.fromScale(0.03, 0.03) }):Play()
		el.miles.TextColor3 = Color3.fromRGB(210, 210, 210)
	else
		TweenService:Create(el.miles, info, { Position = el.milesHome.pos, Size = el.milesHome.size, TextTransparency = 0 }):Play()
		TweenService:Create(el.badge, info, { Position = el.badgeHome.pos, Size = el.badgeHome.size }):Play()
		el.miles.TextColor3 = Color3.new(1, 1, 1)
	end
end

-- the RIG marker, every frame (Main binds it after the camera): clamped to the
-- screen edge when the rig is off-screen
local markerWanted = false
local behindWarn = false
local behindShown = 0
function Hud.marker(v: Vector3?, onScreen: boolean, metres: number, studs: number?, dt: number?)
	if not el.marker then
		return
	end
	-- DON'T GET LEFT BEHIND!: the bar fills smoothly with your own distance from
	-- the rig, every frame (owner: it jumped when it followed the server's figure)
	if behindWarn and studs then
		local C = Config.Crew
		local target = math.clamp((studs - C.WARN_STUDS) / C.PULL_STUDS, 0, 1)
		behindShown += (target - behindShown) * math.min(1, (dt or 1 / 60) * 10)
		el.behindFill.Size = UDim2.fromScale(behindShown, 1)
		el.behindSub.Text = behindShown > 0.8 and "The dig will drag you back!" or "Slide back to the rig"
		for _, g in el.vignette:GetChildren() do
			g.BackgroundTransparency = 0.6 - behindShown * 0.5
		end
	elseif not behindWarn then
		behindShown = 0
	end
	local show = markerWanted and v ~= nil
	el.marker.Visible = show
	if not show then
		return
	end
	local cam = workspace.CurrentCamera.ViewportSize
	local x, y = (v :: Vector3).X / cam.X, (v :: Vector3).Y / cam.Y
	if not onScreen then
		x, y = math.clamp(x, 0.05, 0.95), math.clamp(y, 0.15, 0.9)
	end
	el.marker.Position = UDim2.fromScale(x, y)
	el.markerDist.Text = metres .. "m"
end

function Hud.update(state: Instance, me: { aboard: boolean, behind: number, rigDistance: number, rigScreen: Vector3?, onScreen: boolean })
	local s = state:GetAttribute("Distance") or 0
	local miles = (state:GetAttribute("MileOffset") or 0) + s / Config.STUDS_PER_MILE
	local phase = state:GetAttribute("Phase") or "Spawn"
	local moving = state:GetAttribute("Moving") == true
	local riding = moving and me.aboard

	-- distance, with the reference's odometer roll and whole-mile flash
	local tenth = math.floor(miles * 10)
	if tenth ~= lastTenth then
		local whole = tenth % 10 == 0 and tenth > 0
		local value = whole and tostring(tenth // 10) or string.format("%.1f", tenth / 10)
		el.miles.Text = value .. (value == "1" and " Mile" or " Miles")
		if lastTenth >= 0 and not compact then
			local home = el.milesHome.pos
			el.miles.Position = home + UDim2.fromScale(0, -0.012)
			TweenService:Create(el.miles, TweenInfo.new(0.15), { Position = home }):Play()
		end
		if whole and lastTenth >= 0 then
			el.miles.TextColor3 = YELLOW
			task.delay(0.75, function()
				el.miles.TextColor3 = compact and Color3.fromRGB(210, 210, 210) or Color3.new(1, 1, 1)
			end)
		end
		lastTenth = tenth
	end
	setCompact(not riding)

	-- the day badge: blue + sun, orange late, navy + moon at Lights Out
	local glow = state:GetAttribute("Glow") or 1
	local lit = math.floor(glow * #el.badgeArc + 0.5)
	for i, seg in el.badgeArc do
		seg.BackgroundColor3 = i <= lit and (glow > 0.4 and YELLOW or Color3.fromRGB(255, 90, 50)) or Color3.fromRGB(40, 50, 90)
	end
	local nightNow = glow <= 0.01 or phase == "Night"
	el.badgeDisc.BackgroundColor3 = nightNow and Color3.fromRGB(30, 40, 90) or (glow > 0.4 and Color3.fromRGB(110, 190, 240) or Color3.fromRGB(240, 130, 50))
	el.badgeSun.Visible = not nightNow
	el.badgeMoon.Visible = nightNow

	-- objective
	local text = state:GetAttribute("Objective") or ""
	local value = state:GetAttribute("ObjectiveValue") or ""
	local color = OBJ_COLORS[state:GetAttribute("ObjectiveColor") or "white"] or "#FFFFFF"
	local showObj = text ~= "" and not (phase == "Night")
	el.objective.Visible = showObj
	el.objective.Text = string.format('<font color="%s">%s</font>  %s', color, text, value)
	local icon = state:GetAttribute("ObjectiveIcon") or ""
	if el.objIconHolder:GetAttribute("Icon") ~= icon then
		el.objIconHolder:SetAttribute("Icon", icon)
		el.objIconHolder:ClearAllChildren()
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = el.objIconHolder })
		if icon ~= "" then
			Ui.icon(icon, { Parent = el.objIconHolder, Size = UDim2.fromScale(1, 1) })
		end
	end
	local tb = el.objective.TextBounds.X
	el.objIconHolder.Position = UDim2.new(0.5, -tb / 2 - 6, 0.5, 0)

	-- route bar: hidden at stops; moves up when there's no objective
	el.bar.Visible = riding
	el.bar.Position = UDim2.fromScale(0.5, showObj and 0.23 or 0.182)
	local frac = math.clamp(miles / el.totalMiles, 0, 1)
	el.barDone.Size = UDim2.fromScale(frac, 0.7)
	el.barMarker.Position = UDim2.fromScale(frac, 0.5)

	-- Hunger and Health
	el.Hunger.Size = UDim2.fromScale(math.clamp((player:GetAttribute("Hunger") or 100) / 100, 0, 1), 1)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	el.Health.Size = UDim2.fromScale(hum and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 1, 1)
	local temp = Config.Temperature[state:GetAttribute("Zone") or 1]
	el.tempHolder.Visible = temp ~= nil
	el.tempLabel.Visible = temp ~= nil
	if temp then
		local e = (player:GetAttribute("Exposure") or 0) / 100
		el.tempLabel.Text = temp.name
		el.temp.BackgroundColor3 = e >= 1 and Color3.fromRGB(255, 40, 40) or temp.color
		el.temp.Size = UDim2.fromScale(math.clamp(e, 0, 1), 1)
	end

	-- speedometer: only while aboard and moving
	el.speedo.Visible = riding
	-- (TURBO is a paid boost that isn't for sale yet: hidden until it is)
	el.turbo.Visible = false
	local mph = (state:GetAttribute("Speed") or 0) * Config.MPH_PER_STUD
	el.mph.Text = tostring(math.floor(mph + 0.5))
	local litTicks = math.floor(math.clamp(mph / 60, 0, 1) * #el.ticks + 0.5)
	for i, t in el.ticks do
		t.BackgroundColor3 = i <= litTicks and (i > #el.ticks * 0.88 and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(70, 230, 50)) or Color3.fromRGB(60, 60, 64)
	end

	-- boarding UI
	local boarding = state:GetAttribute("Boarding") or ""
	local count = state:GetAttribute("Countdown") or 0
	local aboard, crewSize, need = state:GetAttribute("Aboard") or 0, state:GetAttribute("CrewSize") or 1, state:GetAttribute("Need") or 1
	-- (at the spawn it waits until you've mined your glowstone or the countdown runs, like the reference)
	local spawnReady = phase ~= "Spawn" or boarding ~= "Board" or (player:GetAttribute("Glowstone") or 0) >= 12
	local showBoard = boarding ~= "" and spawnReady and (phase == "Spawn" or phase == "Stop" or phase == "Morning" or phase == "Night")
	if showBoard then
		el.objective.Visible = false
	end
	el.boardTitle.Visible = showBoard
	el.boardRow.Visible = showBoard
	el.boardText.Visible = showBoard
	if showBoard then
		if boarding == "AllAboard" then
			el.boardTitle.Text = '<font color="#5BE65B">ALL ABOARD!</font>'
			el.boardText.Text = 'Leaving in <font color="#FF3B30">' .. count .. "</font>"
		elseif boarding == "Leaving" then
			el.boardTitle.Text = 'LEAVING IN <font color="' .. (count <= 1 and "#FF3B30" or "#FFD628") .. '">' .. count .. "</font>"
			el.boardText.Text = aboard .. "/" .. crewSize .. " aboard"
		else
			el.boardTitle.Text = "BOARD THE RIG!"
			el.boardText.Text = aboard .. "/" .. crewSize .. ' aboard · <font color="#FFD628">' .. math.max(0, need - aboard) .. " more</font> to leave"
		end
		crewRow(el.boardRow, function(p)
			return p:GetAttribute("Aboard") == true
		end, 0.17)
	end

	-- RIG IS LEAVING: you're off it while it counts down
	local leaving = showBoard and boarding ~= "Board" and not me.aboard
	el.leavingTitle.Visible = leaving
	el.leavingBar.Visible = leaving
	el.leavingSub.Visible = leaving
	if leaving then
		local full = boarding == "AllAboard" and Config.LEAVE_COUNTDOWN_ALL or (phase == "Spawn" and Config.LEAVE_COUNTDOWN_SPAWN or Config.LEAVE_COUNTDOWN)
		el.leavingFill.Size = UDim2.fromScale(math.clamp(count / full, 0, 1), 1)
	end

	-- DON'T GET LEFT BEHIND!
	local behind = me.behind
	local warn = behind >= 0
	el.behindTitle.Visible = warn
	el.behindBar.Visible = warn
	el.behindSub.Visible = warn
	el.vignette.Visible = warn
	behindWarn = warn
	-- (the fill itself slides every frame in Hud.marker)

	-- the RIG marker, clamped to the screen edge when the rig is off-screen
	markerWanted = (warn or leaving) == true
	el.markerSecsBox.Visible = leaving
	el.markerSecs.Text = count .. "s"

	-- the night
	local isNight = phase == "Night"
	el.night.Visible = isNight
	if isNight then
		local prog = (state:GetAttribute("NightProgress") or 0) / 100
		local mult = state:GetAttribute("NightMult") or 1
		el.nightFill.Size = UDim2.fromScale(prog, 1)
		el.nightFill.BackgroundColor3 = mult > 1.01 and Color3.fromRGB(255, 196, 40) or Color3.fromRGB(50, 90, 230)
		el.nightMult.Text = mult > 1.01 and string.format("%.1fx", mult) or ""
		local inRing, n = state:GetAttribute("InRing") or 0, state:GetAttribute("CrewSize") or 1
		el.ringText.Text = inRing < n and ((n - inRing) .. " more to speed up the night") or (mult > 1.01 and "Feed the Beacon to go faster" or "Feed the Beacon to speed up the night")
		if (state:GetAttribute("RepairNeed") or 0) <= 0 and not state:GetAttribute("NightLeave") then
			el.ringText.Text ..= '  ·  <font color="#FFD628">or leave now: [F] on the rig</font>'
		end
		local beaconPos = state:GetAttribute("BeaconPos")
		crewRow(el.ringRow, function(p)
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			return beaconPos ~= nil and r ~= nil and (r.Position - beaconPos).Magnitude <= Config.Night.RING
		end, 0.16)
	end
end

build()
return Hud
