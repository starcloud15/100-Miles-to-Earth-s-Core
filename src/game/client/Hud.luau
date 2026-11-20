--[[
	The Game place HUD, laid out like the reference (docs/ui/ui-mockup.html):
	  * top centre: "0.0 Miles", the day badge, the next goal, and the
	    horizontal route bar with the six zones;
	  * bottom right: the segmented speedometer, MPH and the Turbo pill, with
	    the two tread bars beside it;
	  * left: rig health and glowstone;
	  * centre: toasts ("THROWN OFF!", "PUSHED OFF!"...) and the Left Behind
	    warning.
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
local ticks: { Frame } = {}
local TICKS = 22

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- top centre ------------------------------------------------------------
	local top = Ui.new("Frame", { Name = "Top", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(620, 150), Parent = gui })
	el.miles = Ui.text({ Name = "Miles", Parent = top, Text = "0.0 Miles", Size = UDim2.fromOffset(440, 66), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Stroke = 4 })
	local badge = Ui.new("Frame", { Name = "DayBadge", Parent = top, BackgroundColor3 = Color3.fromRGB(230, 120, 40), Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0.5, 230, 0, 4) }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(4, Color3.fromRGB(30, 30, 30), true) })
	Ui.icon("Day", { Parent = badge, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1) })
	el.goal = Ui.text({ Name = "Goal", Parent = top, Text = "", TextColor3 = Ui.ORANGE, Size = UDim2.fromOffset(560, 36), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Stroke = 3 })

	-- the route bar: every zone, widths in proportion to their miles
	local bar = Ui.new("Frame", { Name = "RouteBar", Parent = top, BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 114), Size = UDim2.fromOffset(440, 18) }, { Ui.stroke(3, Color3.new(0, 0, 0), true) })
	local totalMiles = 0
	for _, z in Config.ZONES do
		totalMiles += z.miles
	end
	local x = 0
	for i, z in Config.ZONES do
		local w = z.miles / totalMiles
		Ui.new("Frame", { Name = "Zone" .. i, Parent = bar, BackgroundColor3 = z.color:Lerp(Color3.new(0, 0, 0), 0.45), BorderSizePixel = 0, Position = UDim2.new(x, 1, 0, 2), Size = UDim2.new(w, -2, 1, -4) })
		x += w
	end
	el.barFill = Ui.new("Frame", { Name = "Done", Parent = bar, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), ZIndex = 2 })
	el.barMarker = Ui.new("Frame", { Name = "You", Parent = bar, BackgroundColor3 = Color3.fromRGB(255, 210, 40), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(8, 30), ZIndex = 3 }, { Ui.stroke(2, Color3.new(0, 0, 0), true) })
	el.totalMiles = totalMiles

	-- left: rig health and glowstone ---------------------------------------
	local left = Ui.new("Frame", { Name = "Left", BackgroundTransparency = 1, Position = UDim2.new(0, 20, 0.5, -60), Size = UDim2.fromOffset(300, 160), Parent = gui })
	local _, hpFill = Ui.bar({ Parent = left, Label = "Rig", Size = UDim2.fromOffset(280, 34), Position = UDim2.fromOffset(0, 40), Color = Ui.GREEN })
	el.hpFill = hpFill
	local glow = Ui.new("Frame", { Name = "Glowstone", Parent = left, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 92), Size = UDim2.fromOffset(240, 52) })
	Ui.icon("Glowstone", { Parent = glow, Size = UDim2.fromOffset(52, 52) })
	el.glow = Ui.text({ Parent = glow, Text = "0", Position = UDim2.fromOffset(60, 6), Size = UDim2.fromOffset(170, 40), TextXAlignment = Enum.TextXAlignment.Left })

	-- bottom right: speedometer, Turbo pill, tread bars ---------------------
	local speedo = Ui.new("Frame", { Name = "Speedo", Parent = gui, BackgroundColor3 = Color3.fromRGB(28, 28, 30), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -36, 1, -96), Size = UDim2.fromOffset(176, 176) }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(4, Color3.new(0, 0, 0), true) })
	for i = 1, TICKS do
		-- a ring of segments from about 7 o'clock round to 5 o'clock
		local a = math.rad(-135 + (i - 1) * (270 / (TICKS - 1)))
		local r = 74
		local tick = Ui.new("Frame", {
			Parent = speedo,
			BackgroundColor3 = Color3.fromRGB(70, 70, 74),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(a) * r, 0.5, -math.cos(a) * r),
			Size = UDim2.fromOffset(7, 20),
			Rotation = math.deg(a),
		})
		ticks[i] = tick
	end
	el.mph = Ui.text({ Parent = speedo, Text = "0", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(100, 58), Stroke = 4 })
	Ui.text({ Parent = speedo, Text = "MPH", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromOffset(70, 26) })
	local turbo = Ui.new("Frame", { Name = "Turbo", Parent = gui, BackgroundColor3 = Ui.ORANGE, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -52, 1, -50), Size = UDim2.fromOffset(150, 40) }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, Color3.new(0, 0, 0), true) })
	Ui.icon("Turbo", { Parent = turbo, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(-26, -8) })
	Ui.text({ Parent = turbo, Text = "TURBO", Position = UDim2.fromOffset(28, 4), Size = UDim2.new(1, -36, 1, -8) })
	local price = Ui.new("Frame", { Parent = turbo, BackgroundColor3 = Ui.PURPLE, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.55, 0, 1, -6), Size = UDim2.fromOffset(64, 24) }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(2, Color3.new(0, 0, 0), true) })
	Ui.text({ Parent = price, Text = "R$ 25", Size = UDim2.fromScale(1, 1), Stroke = 2 })
	turbo.BackgroundTransparency = 0.35 -- M0: Turbo isn't wired up yet

	local treads = Ui.new("Frame", { Name = "Treads", Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -224, 1, -104), Size = UDim2.fromOffset(84, 160) })
	for i, side in { "L", "R" } do
		local holder = Ui.new("Frame", { Name = side, Parent = treads, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Position = UDim2.fromOffset((i - 1) * 46, 0), Size = UDim2.fromOffset(34, 130) })
		el["tread" .. side] = Ui.new("Frame", { Name = "Fill", Parent = holder, BackgroundColor3 = Color3.fromRGB(255, 196, 40), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -3), Size = UDim2.new(1, -6, 0, 0) })
		Ui.text({ Parent = treads, Text = side, Position = UDim2.fromOffset((i - 1) * 46, 132), Size = UDim2.fromOffset(34, 26) })
	end
	el.sync = Ui.text({ Name = "Sync", Parent = treads, Text = "SYNC!", TextColor3 = Ui.GREEN, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(100, 30), Visible = false })
	el.side = Ui.text({ Name = "Side", Parent = gui, Text = "", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -36, 1, -282), Size = UDim2.fromOffset(300, 30), TextXAlignment = Enum.TextXAlignment.Right })

	-- centre: banner, toasts, Left Behind -----------------------------------
	el.banner = Ui.text({ Name = "Banner", Parent = gui, Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(700, 70), Stroke = 4 })
	el.toast = Ui.text({ Name = "Toast", Parent = gui, Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 64), Stroke = 4, TextTransparency = 1 })
	el.toast.UIStroke.Transparency = 1
	el.vignette = Ui.new("Frame", { Name = "Vignette", Parent = gui, BackgroundColor3 = Color3.fromRGB(200, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 }, {
		Ui.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.18, 1), NumberSequenceKeypoint.new(0.82, 1), NumberSequenceKeypoint.new(1, 0.2) }) }),
	})
	el.behind = Ui.text({ Name = "Behind", Parent = gui, Text = "", TextColor3 = Ui.RED, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(620, 50), Visible = false })
	el.push = Ui.new("TextButton", { Name = "PushOff", Parent = gui, Text = "", BackgroundColor3 = Ui.PURPLE, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(240, 50), Visible = false, AutoButtonColor = true }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, Color3.new(0, 0, 0), true) })
	el.pushText = Ui.text({ Parent = el.push, Text = "Push Off [F]   R$ 19", Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6) })
end

local toastSeq = 0
function Hud.toast(text: string, color: Color3?, seconds: number?)
	toastSeq += 1
	local me = toastSeq
	local t = el.toast
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextTransparency = 0
	t.UIStroke.Transparency = 0
	t.Size = UDim2.fromOffset(480, 48)
	TweenService:Create(t, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(640, 64) }):Play()
	task.delay(seconds or 2, function()
		if me == toastSeq then
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(t.UIStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
end

function Hud.banner(text: string)
	el.banner.Text = text
end

local behindUntil = 0
function Hud.behind(metres: number?)
	if metres then
		behindUntil = os.clock() + 0.8
		el.behind.Text = "DON'T GET LEFT BEHIND!  RIG " .. metres .. " m"
	else
		behindUntil = 0
	end
end

function Hud.pushTarget(name: string?)
	el.push.Visible = name ~= nil
	if name then
		el.pushText.Text = "Push " .. name .. " [F]   R$ " .. Config.PushOff.PRICE
	end
end

function Hud.pushButton(): TextButton
	return el.push
end

function Hud.setSide(side: string?)
	if side == "L" then
		el.side.Text = "You crank the LEFT tread: steers right"
	elseif side == "R" then
		el.side.Text = "You crank the RIGHT tread: steers left"
	else
		el.side.Text = ""
	end
end

local function fmt(x: number): string
	return string.format("%.1f", x)
end

function Hud.update(state: Instance)
	local s = state:GetAttribute("Distance") or 0
	local miles = s / Config.STUDS_PER_MILE
	el.miles.Text = fmt(miles) .. " Miles"
	local total = (state:GetAttribute("Miles") or 10)
	local phase = state:GetAttribute("Phase")
	if phase == "Boarding" then
		el.goal.Text = "Departing in " .. tostring(state:GetAttribute("Countdown") or "") .. "..."
	elseif phase == "Complete" then
		el.goal.Text = "Waystation 1 reached!"
	else
		el.goal.Text = "Next stop: Waystation 1   " .. fmt(math.max(0, total - miles)) .. " mi"
	end
	local frac = math.clamp(miles / el.totalMiles, 0, 1)
	el.barFill.Size = UDim2.new(frac, 0, 1, 0)
	el.barMarker.Position = UDim2.fromScale(frac, 0.5)

	local hp, max = state:GetAttribute("Health") or 1, state:GetAttribute("MaxHealth") or 1
	Ui.setFill(el.hpFill, hp / max)
	el.hpFill.BackgroundColor3 = hp / max > 0.35 and Ui.GREEN or Ui.RED
	el.glow.Text = tostring(state:GetAttribute("Glowstone") or 0)

	local mph = (state:GetAttribute("Speed") or 0) * Config.MPH_PER_STUD
	el.mph.Text = tostring(math.floor(mph + 0.5))
	local lit = math.floor(math.clamp(mph / 60, 0, 1) * TICKS + 0.5)
	for i, t in ticks do
		t.BackgroundColor3 = i <= lit and (i > TICKS * 0.75 and Color3.fromRGB(255, 120, 40) or Color3.fromRGB(70, 230, 60)) or Color3.fromRGB(70, 70, 74)
	end
	for _, side in { "L", "R" } do
		local p = state:GetAttribute("Power" .. side) or 0
		el["tread" .. side].Size = UDim2.new(1, -6, p, -6 * p)
	end
	el.sync.Visible = state:GetAttribute("Synced") == true

	local showBehind = os.clock() < behindUntil
	el.behind.Visible = showBehind
	el.vignette.BackgroundTransparency = showBehind and 0.55 or 1
end

build()
return Hud
