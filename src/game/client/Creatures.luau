--[[
	Draws the creatures the server puts on the rig (RunState.Creatures, see
	server/Creatures.luau) and runs their SPAM! buttons.

	Models: Shared.Models.Creatures.<Kind> from Starport (tools/blender/creatures.py),
	or a part stand-in. Pieces are named "<Group>_<Paint>": a group moves as one
	(Body for a boarder; Head and Seg1..SegN for a grabber's body), and the paint
	picks the colour, since FBX colours are lost on import.

	The SPAM! button (docs/research/frames seg-2 to seg-6): a red glossy disc,
	white italic "SPAM!", a thick white outer ring and a green arc that fills
	clockwise as you click. World-anchored on the creature (small) or on the
	grabbed player (big). Success: "KNOCKED OFF!" / "BROKE FREE!".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Ui = require(Shared.Ui)

local player = Players.LocalPlayer
local Creatures = {}

local PAINT = {
	Shell = { Color3.fromRGB(118, 64, 48), Enum.Material.Slate },
	Belly = { Color3.fromRGB(206, 156, 112), Enum.Material.SmoothPlastic },
	Legs = { Color3.fromRGB(74, 46, 38), Enum.Material.SmoothPlastic },
	Flesh = { Color3.fromRGB(206, 178, 166), Enum.Material.SmoothPlastic },
	Plate = { Color3.fromRGB(118, 88, 80), Enum.Material.Slate },
	Bone = { Color3.fromRGB(242, 232, 212), Enum.Material.SmoothPlastic },
	Glow = { Color3.fromRGB(255, 214, 130), Enum.Material.Neon },
	Eye = { Color3.fromRGB(255, 70, 50), Enum.Material.Neon },
}

local RED = Color3.fromRGB(226, 38, 38)
local GREEN = Color3.fromRGB(70, 230, 70)
local YELLOW = Color3.fromRGB(255, 222, 40)

-- part stand-ins, until the Blender models are uploaded ---------------------------------
local function piece(model: Model, name: string, shape: Enum.PartType?, size: Vector3, cf: CFrame)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Parent = model
	return p
end

local STANDIN = {}
function STANDIN.Cragskitter(m: Model)
	-- an armoured rock crawler: a domed shell, a pale belly, six legs, glowing eyes
	piece(m, "Body_Belly", Enum.PartType.Ball, Vector3.new(3.4, 1.3, 3.8), CFrame.new(0, 1.1, 0))
	piece(m, "Body_Shell", Enum.PartType.Ball, Vector3.new(4.2, 2.4, 4.8), CFrame.new(0, 1.7, 0.3))
	for i = 0, 2 do
		for _, side in { -1, 1 } do
			piece(m, "Body_Legs", nil, Vector3.new(2.6, 0.35, 0.35), CFrame.new(side * 2.2, 0.8, -1.2 + i * 1.3) * CFrame.Angles(0, side * (i - 1) * 0.4, side * -0.6))
		end
	end
	for _, side in { -1, 1 } do
		piece(m, "Body_Glow", Enum.PartType.Ball, Vector3.new(0.55, 0.55, 0.55), CFrame.new(side * 0.7, 1.7, -2.3))
	end
end
function STANDIN.Burrowmaw(m: Model)
	-- a pale burrowing worm: plated segments and a round toothed maw
	for i = 1, 7 do
		local r = 3.4 - i * 0.16
		piece(m, ("Seg%d_Flesh"):format(i), Enum.PartType.Ball, Vector3.new(r, r, r), CFrame.new(0, 0, 0))
		piece(m, ("Seg%d_Plate"):format(i), nil, Vector3.new(r * 0.8, 0.5, r * 0.6), CFrame.new(0, r * 0.42, 0))
	end
	piece(m, "Head_Flesh", Enum.PartType.Ball, Vector3.new(3.8, 3.8, 3.8), CFrame.new())
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		piece(m, "Head_Bone", nil, Vector3.new(0.4, 0.4, 1.4), CFrame.new(math.cos(a) * 1.2, math.sin(a) * 1.2, -1.9) * CFrame.Angles(math.sin(a) * 0.5, -math.cos(a) * 0.5, 0))
	end
	for _, side in { -1, 1 } do
		piece(m, "Head_Eye", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), CFrame.new(side * 1.1, 1.2, -1.2))
	end
end

-- a creature's model, split into its moving groups ---------------------------------------
local function build(kind: string)
	local models = Shared:FindFirstChild("Models")
	local lib = models and models:FindFirstChild("Creatures")
	local src = lib and lib:FindFirstChild(kind)
	local m: Model
	if src then
		m = src:Clone()
	else
		m = Instance.new("Model")
		local fn = STANDIN[kind] or STANDIN.Cragskitter
		fn(m)
	end
	m.Name = kind
	local groups = {} -- [group] = { origin = CFrame, parts = { { part, offset } } }
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			local g, paint = p.Name:match("^(%w+)_(%w+)")
			g = g or "Body"
			local look = PAINT[paint or ""]
			if look then
				p.Color = look[1]
				p.Material = look[2]
			end
			groups[g] = groups[g] or { parts = {} }
			table.insert(groups[g].parts, p)
		end
	end
	for _, g in groups do
		local sum = Vector3.zero
		for _, p in g.parts do
			sum += p.Position
		end
		g.origin = CFrame.new(sum / #g.parts)
		g.offsets = {}
		for i, p in g.parts do
			g.offsets[i] = g.origin:ToObjectSpace(p.CFrame)
		end
	end
	-- a boarder's Body sits on the deck: its origin drops to the lowest point
	if groups.Body then
		local low = math.huge
		for _, p in groups.Body.parts do
			low = math.min(low, p.Position.Y - p.Size.Y / 2)
		end
		local o = groups.Body.origin
		local base = CFrame.new(o.X, low, o.Z)
		for i, p in groups.Body.parts do
			groups.Body.offsets[i] = base:ToObjectSpace(p.CFrame)
		end
	end
	local segs = {}
	for i = 1, 20 do
		if groups["Seg" .. i] then
			table.insert(segs, groups["Seg" .. i])
		end
	end
	return m, groups, segs
end

local function place(g, cf: CFrame)
	for i, p in g.parts do
		p.CFrame = cf * g.offsets[i]
	end
end

-- the SPAM! button -------------------------------------------------------------------------
local gui: ScreenGui
local function circle(parent: Instance, size: number, color: Color3, z: number): Frame
	return Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }) :: Frame
end

-- a clockwise arc from 12 o'clock: two clipped halves, each a disc with a hard-edged gradient
local function arc(parent: Instance, size: number, color: Color3, z: number)
	local halves = {}
	for i, x in { 0.5, 0 } do
		local clip = Ui.new("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromScale(x, 0), Size = UDim2.fromScale(0.5, 1), ZIndex = z, Parent = parent })
		local disc = circle(clip, 1, color, z)
		disc.Size = UDim2.fromScale(2 * size, size)
		disc.Position = UDim2.fromScale(i == 1 and 0 or 1, 0.5)
		disc.SizeConstraint = Enum.SizeConstraint.RelativeXY
		local grad = Ui.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = disc })
		halves[i] = grad
	end
	return function(p: number)
		p = math.clamp(p, 0, 1)
		halves[1].Rotation = math.min(p, 0.5) * 360
		halves[2].Rotation = 180 + math.max(0, p - 0.5) * 360
	end
end

local function spamButton(big: boolean, onClick: () -> ())
	-- a screen-space button that follows the creature (clamped to the screen edge
	-- when it's off-screen, like the reference's); see step()
	local bb = Ui.new("Frame", {
		Name = "Spam",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(big and 0.086 or 0.05, big and 0.086 or 0.05),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		Parent = gui,
	}) :: Frame
	bb:SetAttribute("Lift", big and 3.5 or 2.5)
	local holder = Ui.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = bb })
	circle(holder, 1, Color3.new(1, 1, 1), 1)
	local setArc = arc(holder, 1, GREEN, 2)
	local disc = circle(holder, 0.74, RED, 3)
	Ui.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 120, 110), Color3.fromRGB(190, 20, 20)), Parent = disc })
	Ui.new("UIStroke", { Thickness = big and 3 or 2, Color = Color3.fromRGB(110, 0, 0), Parent = disc })
	Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.4),
		Text = "SPAM!",
		FontFace = Ui.ITALIC,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = holder,
	}, { Ui.new("UIStroke", { Thickness = big and 3 or 2, Color = Color3.fromRGB(60, 0, 0) }) })
	local star = Ui.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), Text = "✦", TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, ZIndex = 5, Parent = holder })
	local button = Ui.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = holder }) :: TextButton
	button.Activated:Connect(function()
		onClick()
		-- a punch and a white impact star where you hit it
		holder.Size = UDim2.fromScale(0.88, 0.88)
		TweenService:Create(holder, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.fromScale(1, 1) }):Play()
		star.Position = UDim2.fromScale(0.5 + math.random(-25, 25) / 100, 0.5 + math.random(-25, 25) / 100)
		star.TextTransparency = 0
		star.Rotation = math.random(0, 90)
		TweenService:Create(star, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
	end)
	return bb, setArc
end

-- the hurt flash: red screen edges ----------------------------------------------------------
local flash: Frame
local function hurtFlash(strength: number)
	for _, v in flash:GetChildren() do
		v.BackgroundTransparency = 1 - strength
		TweenService:Create(v, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end
end

-- running ---------------------------------------------------------------------------------
local live = {} -- [Configuration] = view
local deckFn: () -> BasePart?
local shakeFn: (number) -> ()
local toastFn: (string, Color3?, number?) -> ()

local function rootOf(userId: number): BasePart?
	local p = Players:GetPlayerByUserId(userId)
	local c = p and p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function add(f: Instance)
	local kind = f:GetAttribute("Kind")
	local mode = f:GetAttribute("Mode")
	local m, groups, segs = build(kind)
	m.Parent = workspace
	local view = { f = f, m = m, groups = groups, segs = segs, mode = mode, shown = 0, bites = 0, lunge = 0 }
	live[f] = view
	local anchor: BasePart
	if mode == "Grab" then
		anchor = groups.Head and groups.Head.parts[1] or m:FindFirstChildWhichIsA("BasePart") :: BasePart
	else
		anchor = groups.Body and groups.Body.parts[1] or m:FindFirstChildWhichIsA("BasePart") :: BasePart
	end
	view.anchor = anchor
	view.bb, view.setArc = spamButton(mode == "Grab", function()
		if f:GetAttribute("Phase") == "On" then
			view.shown = math.min(view.shown + 1, f:GetAttribute("Need") - 0.3)
			view.lunge = 0.15
			Net.Spam:FireServer(f.Name)
		end
	end)
	if mode == "Grab" and f:GetAttribute("Target") == player.UserId then
		toastFn("SPAM! to break free", RED, 1.4)
		shakeFn(0.8)
	end
	f:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = f:GetAttribute("Phase")
		view.bb.Visible = false
		view.endT = os.clock()
		local mine = f:GetAttribute("By") == player.UserId or f:GetAttribute("Target") == player.UserId
		if phase == "KnockedOff" then
			toastFn("KNOCKED OFF!", YELLOW, 1.4)
		elseif phase == "BrokeFree" then
			toastFn("BROKE FREE!", GREEN, 1.4)
		elseif phase == "Dragged" and f:GetAttribute("Target") == player.UserId then
			toastFn("DRAGGED OFF!", RED, 1.6)
		end
		if mine then
			shakeFn(0.5)
		end
	end)
	f:GetAttributeChangedSignal("Bites"):Connect(function()
		view.lunge = 0.35
	end)
	f.Destroying:Connect(function()
		live[f] = nil
		m:Destroy()
		view.bb:Destroy()
	end)
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	return a:Lerp(b, t):Lerp(b:Lerp(c, t), t)
end

local function step(dt: number)
	local deck = deckFn()
	if not deck then
		return
	end
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local top = deck.CFrame * CFrame.new(0, deck.Size.Y / 2, 0)
	for f, v in live do
		local age = now - (f:GetAttribute("Born") or now)
		local phase = f:GetAttribute("Phase")
		local ended = v.endT and (clock - v.endT) or 0
		local need = f:GetAttribute("Need") or 1
		v.shown = math.max(v.shown, f:GetAttribute("Hits") or 0)
		v.setArc(v.shown / need)
		if phase == "On" then
			local target = v.anchor.Position
			if v.mode == "Grab" then
				local r = rootOf(f:GetAttribute("Target"))
				target = r and r.Position or target
			end
			local cam = workspace.CurrentCamera
			local vp = cam.ViewportSize
			local sp, onScreen = cam:WorldToViewportPoint(target + Vector3.new(0, v.bb:GetAttribute("Lift"), 0))
			local x, y = sp.X, sp.Y
			if sp.Z < 0 then
				x, y = vp.X - x, vp.Y - y
			end
			if not onScreen then
				local m = v.bb.AbsoluteSize.X * 0.6
				x, y = math.clamp(x, m, vp.X - m), math.clamp(y, m, vp.Y - m)
				if sp.Z < 0 then
					y = vp.Y - m
				end
			end
			v.bb.Position = UDim2.fromOffset(x, y)
		end
		v.lunge = math.max(0, v.lunge - dt)

		if v.mode == "Board" then
			local ox, oz = f:GetAttribute("OffX") or 0, f:GetAttribute("OffZ") or 0
			local yaw = (f:GetAttribute("Yaw") or 0) + math.sin(age * 3) * 0.35
			local cf = top * CFrame.new(ox + math.sin(age * 2.2) * 0.5, 0, oz + math.cos(age * 1.7) * 0.4) * CFrame.Angles(0, yaw, 0)
			-- dropping from the roof
			if age < 0.6 then
				local k = 1 - age / 0.6
				cf = cf * CFrame.new(0, 26 * k * k, 0) * CFrame.Angles(k * 2, 0, 0)
			else
				-- scuttling, and a lunge when it bites or gets hit
				cf = cf * CFrame.new(0, math.abs(math.sin(age * 14)) * 0.15, -v.lunge * 3)
			end
			if phase ~= "On" then
				-- flung off the side (or hopping off on its own)
				local out = (ox >= 0 and 1 or -1)
				local t = ended * (phase == "Gone" and 0.7 or 1)
				cf = top * CFrame.new(ox + out * t * 34, t * 22 - t * t * 30, oz) * CFrame.Angles(t * 9, yaw, out * t * 7)
			end
			if v.groups.Body then
				place(v.groups.Body, cf)
			end
		else
			local side = f:GetAttribute("Side") or 1
			local root = rootOf(f:GetAttribute("Target"))
			local emerge = (top * CFrame.new(side * 16, -7, 2)).Position
			local grip = root and (root.Position + top.RightVector * side * 1.2) or (top * CFrame.new(side * 3, 2, 0)).Position
			local reach = math.clamp(age / 0.45, 0, 1)
			if phase ~= "On" then
				reach = math.clamp(1 - ended / (phase == "Dragged" and 0.9 or 0.45), 0, 1)
			end
			local ctrl = (emerge + grip) / 2 + Vector3.new(0, 7, 0) + top.RightVector * side * 2
			local n = #v.segs
			local function at(t: number): Vector3
				local p = bezier(emerge, ctrl, grip, t * reach)
				return p + top.UpVector * math.sin(clock * 9 - t * 6) * 0.35 * reach
			end
			local function facing(p: Vector3, q: Vector3): CFrame
				local d = q - p
				if d.Magnitude < 0.01 then
					d = top.UpVector
				end
				return CFrame.lookAt(p, p + d.Unit)
			end
			for i, g in v.segs do
				local t = 1 - i / (n + 1)
				place(g, facing(at(t), at(t + 0.02)))
			end
			if v.groups.Head then
				local shake = math.sin(clock * 40) * 0.12
				place(v.groups.Head, facing(at(0.97), at(1)) * CFrame.new(0, 0, -(at(1) - at(0.97)).Magnitude) * CFrame.Angles(0, 0, shake))
			end
			if f:GetAttribute("Target") == player.UserId and phase == "On" and age > 0.5 and math.floor(age * 3) ~= math.floor((age - dt) * 3) then
				hurtFlash(0.4)
				shakeFn(0.35)
			end
		end
	end
end

function Creatures.init(opts: { deck: () -> BasePart?, shake: (number) -> (), toast: (string, Color3?, number?) -> () })
	deckFn, shakeFn, toastFn = opts.deck, opts.shake, opts.toast
	gui = Instance.new("ScreenGui")
	gui.Name = "Creatures"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	flash = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui }) :: Frame
	for i, rot in { 0, 90, 180, 270 } do
		Ui.new("Frame", {
			BackgroundColor3 = Color3.fromRGB(220, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(i == 2 and 0.92 or (i == 4 and 0.08 or 0.5), i == 1 and 0.08 or (i == 3 and 0.92 or 0.5)),
			Size = (i % 2 == 1) and UDim2.fromScale(1, 0.16) or UDim2.fromScale(0.16, 1),
			Parent = flash,
		}, { Ui.new("UIGradient", { Rotation = rot + 90, Transparency = NumberSequence.new(0, 1) }) })
	end
	local state = ReplicatedStorage:WaitForChild("RunState")
	local folder = state:WaitForChild("Creatures")
	for _, f in folder:GetChildren() do
		add(f)
	end
	folder.ChildAdded:Connect(add)
	Net.Notify.OnClientEvent:Connect(function(kind)
		if kind == "Bitten" then
			hurtFlash(0.55)
			shakeFn(0.5)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return Creatures
