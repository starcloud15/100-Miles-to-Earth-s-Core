--[[
	The Delver's Hook, cast for real (owner: "it's supposed to physically throw out
	the hook, and the ... is supposed to be on the hook, not the HUD").

	The server picks where the hook lands and sets the caster's attributes:
	  HookState  "Cast" (waiting) / "Bite" (the tug: reel now!) / "" (reeled in)
	  HookAt     the landing point: on the rig's deck frame when HookRig, else world
	  HookTime   server time of the cast
	Every client draws every player's hook: it arcs out from the rod tip on a line,
	sits on the ground with "..." over it like the reference's bobber, jerks and
	shows "!" at the tug, and flies back to the rod when reeled in.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hook = {}

local FLY = 0.45 -- seconds out
local BACK = 0.22 -- seconds back in
local SCALE = 2.2 -- the thrown hook is drawn bigger than the one on the rod, to read at range
local LINE = Color3.fromRGB(236, 222, 190)
local STEEL = Color3.fromRGB(176, 182, 192)
local GLOW = Color3.fromRGB(255, 196, 80)

local deckFn: () -> BasePart?
local live: { [Player]: any } = {}
local folder: Folder

local function rodTip(p: Player): CFrame?
	local char = p.Character
	local tool = char and char:FindFirstChild("Delver's Hook")
	local handle = tool and tool:FindFirstChild("Handle") :: BasePart?
	if handle then
		return handle.CFrame * CFrame.new(-0.5, 2.4, 0) -- the end of the rod's tip arm
	end
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	return hand and hand.CFrame or nil
end

-- hide the hook hanging from the rod while it's out
local function hideRodHook(p: Player, hidden: boolean)
	local tool = p.Character and p.Character:FindFirstChild("Delver's Hook")
	if not tool then
		return
	end
	for _, n in { "Hook", "Glow", "Line" } do
		local part = tool:FindFirstChild(n) :: BasePart?
		if part then
			part.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function anchoredPart(props: { [string]: any }): BasePart
	local part = Instance.new(props.ClassName or "Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	for k, v in props do
		if k ~= "ClassName" then
			(part :: any)[k] = v
		end
	end
	return part
end

local function build(p: Player)
	local m = Instance.new("Model")
	m.Name = "Hook_" .. p.Name
	-- the line runs from an invisible point at the rod tip to the hook's eye
	local start = anchoredPart({ Name = "LineStart", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, Parent = m })
	local eye = anchoredPart({ Name = "Eye", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, Parent = m })
	local a0 = Instance.new("Attachment")
	a0.Parent = start
	local a1 = Instance.new("Attachment")
	a1.Parent = eye
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.08
	beam.Width1 = 0.08
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Color = ColorSequence.new(LINE)
	beam.LightEmission = 0.3
	beam.Parent = start

	-- the hook itself: the rod's own hook mesh (scaled up) when we can borrow it
	local pieces = {}
	local tool = p.Character and p.Character:FindFirstChild("Delver's Hook")
	local srcHook = tool and tool:FindFirstChild("Hook") :: BasePart?
	local srcGlow = tool and tool:FindFirstChild("Glow") :: BasePart?
	local function borrow(src: BasePart?, offset: Vector3, fallback: () -> BasePart): BasePart
		local part: BasePart
		if src then
			part = src:Clone()
			part:ClearAllChildren()
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Size *= SCALE
			part.LocalTransparencyModifier = 0
			part.Transparency = 0
		else
			part = fallback()
		end
		part.Parent = m
		table.insert(pieces, { part = part, offset = offset * SCALE })
		return part
	end
	-- (offsets from the line's end, as they hang on the rod)
	borrow(srcHook, Vector3.new(-0.23, -0.32, 0), function()
		return anchoredPart({ Name = "Hook", Size = Vector3.new(0.6, 0.64, 0.14) * SCALE, Color = STEEL, Material = Enum.Material.Metal })
	end)
	local glow = borrow(srcGlow, Vector3.new(-0.5, -0.05, 0), function()
		return anchoredPart({ Name = "Glow", Shape = Enum.PartType.Ball, Size = Vector3.new(0.28, 0.28, 0.28) * SCALE, Color = GLOW, Material = Enum.Material.Neon })
	end)
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = glow

	-- "..." over the hook, "!" at the tug
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(96, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.Adornee = eye
	gui.Parent = eye
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Text = ""
	label.Parent = gui

	m.Parent = folder
	return { model = m, start = start, eye = eye, pieces = pieces, label = label, gui = gui, light = light, reelFrom = nil, reelAt = 0 }
end

local function target(p: Player): Vector3?
	local at = p:GetAttribute("HookAt")
	if typeof(at) ~= "Vector3" then
		return nil
	end
	if p:GetAttribute("HookRig") then
		local d = deckFn()
		return d and d.CFrame:PointToWorldSpace(at) or nil
	end
	return at
end

local function place(h, pos: Vector3, spin: number, jiggle: number)
	h.eye.CFrame = CFrame.new(pos)
	local base = CFrame.new(pos) * CFrame.Angles(0, spin, jiggle)
	for _, pc in h.pieces do
		pc.part.CFrame = base * CFrame.new(pc.offset)
	end
end

local function step()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for _, p in Players:GetPlayers() do
		local st = p:GetAttribute("HookState") or ""
		local h = live[p]
		local tip = rodTip(p)
		if st ~= "" and tip then
			local to = target(p)
			if to then
				h = h or build(p)
				live[p] = h
				h.reelFrom = nil
				hideRodHook(p, true)
				h.start.CFrame = tip
				local t = math.clamp((now - (p:GetAttribute("HookTime") or now)) / FLY, 0, 1)
				local pos, spin, jiggle
				if t < 1 then
					-- the arc out from the rod tip, spinning
					pos = tip.Position:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * 6, 0)
					spin, jiggle = t * 14, 0
					h.label.Text = ""
				elseif st == "Bite" then
					if not h.bitSounded and p == Players.LocalPlayer then
						h.bitSounded = true
						local ok, Sfx = pcall(require, script.Parent:WaitForChild("Sfx"))
						if ok then
							Sfx.play("Bite", 0.8)
						end
					end
					-- the tug: it jerks into the rock
					pos = to + Vector3.new(0, -0.3 + math.sin(clock * 40) * 0.25, 0)
					spin, jiggle = 0, math.sin(clock * 30) * 0.35
					h.label.Text = "!"
					h.label.TextColor3 = Color3.fromRGB(255, 214, 40)
					h.gui.Size = UDim2.fromOffset(110 + math.sin(clock * 18) * 10, 66 + math.sin(clock * 18) * 6)
					h.light.Brightness = 3
				else
					-- waiting: a gentle bob and the reference's "..."
					pos = to + Vector3.new(0, math.sin(clock * 3) * 0.12, 0)
					spin, jiggle = 0, math.sin(clock * 2) * 0.08
					h.label.Text = string.rep(".", math.floor(clock * 2.5) % 3 + 1)
					h.label.TextColor3 = Color3.new(1, 1, 1)
					h.gui.Size = UDim2.fromOffset(96, 56)
					h.light.Brightness = 1.2
				end
				place(h, pos, spin, jiggle)
				continue
			end
		end
		if h then
			-- reeled in (or gone): fly back to the rod, then put the rod's hook back
			if not h.reelFrom then
				h.reelFrom = h.eye.Position
				h.reelAt = clock
				h.label.Text = ""
			end
			local t = math.clamp((clock - h.reelAt) / BACK, 0, 1)
			if tip and t < 1 then
				h.start.CFrame = tip
				place(h, h.reelFrom:Lerp(tip.Position, t) + Vector3.new(0, math.sin(t * math.pi) * 2, 0), t * 10, 0)
			else
				h.model:Destroy()
				live[p] = nil
				hideRodHook(p, false)
			end
		end
	end
end

function Hook.init(getDeck: () -> BasePart?)
	deckFn = getDeck
	folder = Instance.new("Folder")
	folder.Name = "Hooks"
	folder.Parent = workspace
	RunService.RenderStepped:Connect(step)
	Players.PlayerRemoving:Connect(function(p)
		local h = live[p]
		if h then
			h.model:Destroy()
			live[p] = nil
		end
	end)
end

return Hook
