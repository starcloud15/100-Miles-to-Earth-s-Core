--[[
	The world around the route (docs/look-proposal.md, approved):
	  * the surface: an open red-rock gorge of faceted cliffs and cube pines;
	  * The Drop: a ledge spiralling down an open sinkhole shaft;
	  * tunnels: voxel rock in strata bands, carved live by the drill as the
	    rig moves (it breaks the rock in front of it), lit by glowstone veins;
	  * caverns with glow pools, crystals and mushrooms, to break up the
	    enclosure;
	  * stop chambers with veins to mine, the Beacon and a prop cluster.
	Everything is built in a window ahead of the rig.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Route = require(Shared.Route)

local World = {}

local CHUNK = 6 -- nodes per chunk (24 studs)
local CHUNK_LEN = Route.STEP * CHUNK
local AHEAD = 760
local SHELL = Config.Tunnel.SHELL
local T = Workspace.Terrain

local route
local folder: Folder
local built: { [number]: boolean } = {}
local models: { [number]: Model } = {}
local carvedTo = 0
local lastVein = 0
World.veins = {} -- harvestable vein models at stops: { model, hp }
World.beacons = {} -- stop name -> beacon part

local FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
local AMBER = Color3.fromRGB(255, 178, 60)

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "World"
	for k, v in props do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	return p
end

local function light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- strata: the rock changes with depth, in bands (warm sandstone, slate, dark basalt)
local function rockAt(y: number, s: number): Enum.Material
	local band = math.floor((-y + math.noise(s / 300, 0.3) * 40) / 70) % 4
	return ({ Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt })[band + 1]
end

-- surface ----------------------------------------------------------------------
local CLIFF = { Color3.fromRGB(196, 106, 70), Color3.fromRGB(176, 92, 62), Color3.fromRGB(214, 128, 84), Color3.fromRGB(160, 84, 60) }

local function cubePine(model: Model, pos: Vector3, size: number)
	part({ Name = "Trunk", Size = Vector3.new(1.6, 9, 1.6) * size, Position = pos + Vector3.new(0, 4.5 * size, 0), Color = Color3.fromRGB(150, 98, 58), Material = Enum.Material.Wood, Parent = model })
	part({ Name = "Leaves", Size = Vector3.new(9, 7, 9) * size, Position = pos + Vector3.new(0, 11 * size, 0), Color = Color3.fromRGB(64, 150, 62), Material = Enum.Material.Grass, Parent = model })
	part({ Name = "Leaves", Size = Vector3.new(5.5, 5, 5.5) * size, Position = pos + Vector3.new(0, 16.5 * size, 0), Color = Color3.fromRGB(80, 170, 70), Material = Enum.Material.Grass, Parent = model })
end

local function buildSurface(model: Model, cf: CFrame, len: number, w: number, k: number)
	local rng = Random.new(route.seed + k)
	part({ Name = "Floor", Size = Vector3.new(w + 70, 6, len + 2), CFrame = cf * CFrame.new(0, -3, 0), Color = Color3.fromRGB(226, 196, 150), Material = Enum.Material.Sand, Parent = model })
	part({ Name = "Track", Size = Vector3.new(w * 0.7, 0.2, len + 2), CFrame = cf * CFrame.new(0, 0.05, 0), Color = Color3.fromRGB(190, 150, 108), Material = Enum.Material.Ground, CanCollide = false, Parent = model })
	-- grass strips along the foot of the cliffs
	for _, side in { -1, 1 } do
		part({ Name = "Grass", Size = Vector3.new(14, 0.4, len + 2), CFrame = cf * CFrame.new(side * (w / 2 + 14), 0.1, 0), Color = Color3.fromRGB(96, 168, 70), Material = Enum.Material.Grass, CanCollide = false, Parent = model })
	end
	for _, side in { -1, 1 } do
		-- faceted cliffs: stacked, tilted blocks in a few terracotta tones
		local x = side * (w / 2 + 35 + rng:NextNumber(0, 6))
		local h = rng:NextNumber(50, 95)
		local base = cf * CFrame.new(x, h / 2 - 4, 0)
		part({ Name = "Cliff", Size = Vector3.new(30, h, len + 6), CFrame = base * CFrame.Angles(0, 0, math.rad(side * rng:NextNumber(4, 10))), Color = CLIFF[rng:NextInteger(1, 4)], Material = Enum.Material.Sandstone, Parent = model })
		part({ Name = "CliffFacet", ClassName = "WedgePart", Size = Vector3.new(len + 4, h * 0.45, 14), CFrame = cf * CFrame.new(side * (w / 2 + 22), h * 0.22 - 4, 0) * CFrame.Angles(0, math.rad(90 * side), 0), Color = CLIFF[rng:NextInteger(1, 4)], Material = Enum.Material.Sandstone, Parent = model })
		if rng:NextNumber() < 0.7 then
			cubePine(model, (cf * CFrame.new(x + rng:NextNumber(-8, 8), h - 4, rng:NextNumber(-8, 8))).Position, rng:NextNumber(1, 1.5))
		end
		if rng:NextNumber() < 0.25 then
			part({ Name = "Boulder", Size = Vector3.new(6, 5, 7) * rng:NextNumber(0.7, 1.3), CFrame = cf * CFrame.new(side * (w / 2 + rng:NextNumber(6, 20)), 2, rng:NextNumber(-8, 8)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), Color = CLIFF[rng:NextInteger(1, 4)], Material = Enum.Material.Sandstone, Parent = model })
		end
	end
end

-- underground ------------------------------------------------------------------
local function fillShell(cf: CFrame, len: number, w: number, h: number, s: number)
	local mat = rockAt(cf.Position.Y, s)
	T:FillBlock(cf * CFrame.new(0, h / 2, 0), Vector3.new(w + SHELL * 2, h + SHELL * 2, len + 4), mat)
	-- strata: thick, contrasting layers of other rock run along the walls (thin
	-- ones blend away in smooth terrain), at heights that wander along the route
	local n1 = math.noise(s / 220, 1.7)
	local n2 = math.noise(s / 260, 5.3)
	local layers = { Enum.Material.Limestone, Enum.Material.Slate, Enum.Material.Basalt }
	local i0 = math.floor((s / 900) % 3) + 1
	T:FillBlock(cf * CFrame.new(0, h * (0.22 + n1 * 0.12), 0), Vector3.new(w + SHELL * 2, 8, len + 4), layers[i0])
	T:FillBlock(cf * CFrame.new(0, h * (0.66 + n2 * 0.1), 0), Vector3.new(w + SHELL * 2, 10, len + 4), layers[i0 % 3 + 1])
	T:FillBlock(cf * CFrame.new(0, -3, 0), Vector3.new(w + SHELL * 2, 6, len + 4), Enum.Material.Ground)
end

-- old mine timbers: a frame of posts and a beam across the bore
local function timbers(model: Model, cf: CFrame, w: number, h: number)
	local wood = Color3.fromRGB(120, 80, 48)
	for _, side in { -1, 1 } do
		part({ Name = "Timber", Size = Vector3.new(1.6, h * 0.62, 1.6), CFrame = cf * CFrame.new(side * (w / 2 - 2), h * 0.31, 0) * CFrame.Angles(0, 0, math.rad(-side * 4)), Color = wood, Material = Enum.Material.WoodPlanks, Parent = model })
	end
	part({ Name = "Beam", Size = Vector3.new(w - 1, 1.6, 1.8), CFrame = cf * CFrame.new(0, h * 0.62, 0), Color = wood, Material = Enum.Material.WoodPlanks, Parent = model })
	local lamp = part({ Name = "MineLamp", Size = Vector3.new(1, 1.2, 1), CFrame = cf * CFrame.new(0, h * 0.62 - 1.4, 0), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
	light(lamp, Color3.fromRGB(255, 190, 120), 26, 1)
end

-- stalactites from the roof and rubble along the floor's edges
local function detail(model: Model, cf: CFrame, w: number, h: number, rng: Random)
	for _ = 1, 2 do
		local x = rng:NextNumber(-w / 2 + 5, w / 2 - 5)
		local len = rng:NextNumber(3, 8)
		part({ Name = "Stalactite", ClassName = "WedgePart", Size = Vector3.new(rng:NextNumber(1.5, 3), len, rng:NextNumber(1.5, 3)), CFrame = cf * CFrame.new(x, h * 0.86 - len / 2, rng:NextNumber(-6, 6)) * CFrame.Angles(math.pi, rng:NextNumber(0, 3), 0), Color = Color3.fromRGB(120, 92, 80), Material = Enum.Material.Rock, CanCollide = false, Parent = model })
	end
	local side = rng:NextNumber() < 0.5 and -1 or 1
	for _ = 1, 2 do
		part({ Name = "Rubble", Size = Vector3.new(rng:NextNumber(1.5, 3.5), rng:NextNumber(1, 2.5), rng:NextNumber(1.5, 3.5)), CFrame = cf * CFrame.new(side * (w / 2 - rng:NextNumber(1, 4)), 0.8, rng:NextNumber(-8, 8)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)), Color = Color3.fromRGB(140, 104, 84), Material = Enum.Material.Slate, Parent = model })
	end
end

local function hollow(cf: CFrame, len: number, w: number, h: number, rng: Random)
	-- a flat floor and a domed roof, with lumpy walls
	T:FillBlock(cf * CFrame.new(0, h * 0.35 + 0.5, 0), Vector3.new(w, h * 0.7, len + 4), Enum.Material.Air)
	T:FillCylinder(cf * CFrame.new(0, h * 0.62, 0) * CFrame.Angles(math.rad(90), 0, 0), len + 4, math.min(w, h * 1.4) / 2, Enum.Material.Air)
	for _ = 1, 2 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		T:FillBall((cf * CFrame.new(side * (w / 2 + rng:NextNumber(-2, 4)), rng:NextNumber(4, h * 0.8), rng:NextNumber(-len / 2, len / 2))).Position, rng:NextNumber(4, 9), Enum.Material.Air)
	end
	if rng:NextNumber() < 0.5 then
		-- a rock lump pushing in from a wall
		local side = rng:NextNumber() < 0.5 and -1 or 1
		T:FillBall((cf * CFrame.new(side * (w / 2 + 3), rng:NextNumber(10, h), 0)).Position, rng:NextNumber(4, 7), Enum.Material.Rock)
	end
end

local function vein(model: Model, cf: CFrame, w: number, h: number, rng: Random, big: boolean?): Model
	-- a glowstone vein: a cluster of amber crystals on a wall, with a light
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local base = cf * CFrame.new(side * (w / 2 - 0.5), rng:NextNumber(3, h * 0.6), rng:NextNumber(-8, 8)) * CFrame.Angles(0, 0, math.rad(-side * 70))
	local v = Instance.new("Model")
	v.Name = big and "Vein" or "Glow"
	local n = big and 6 or 3
	for i = 1, n do
		local size = (big and 1.6 or 1) * rng:NextNumber(0.8, 1.4)
		local c = part({
			Name = "Crystal",
			Size = Vector3.new(1.4, 4.5, 1.4) * size,
			CFrame = base * CFrame.new(rng:NextNumber(-2, 2), rng:NextNumber(0, 2), rng:NextNumber(-2.5, 2.5)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 3), rng:NextNumber(-0.6, 0.6)),
			Color = i % 2 == 0 and AMBER or Color3.fromRGB(255, 214, 110),
			Material = Enum.Material.Neon,
			CanCollide = big == true,
			Parent = v,
		})
		if i == 1 then
			light(c, Color3.fromRGB(255, 170, 70), big and 24 or 18, big and 1.3 or 0.9)
			v.PrimaryPart = c
		end
	end
	v.Parent = model
	return v
end

local function signPost(model: Model, cf: CFrame, w: number, text: string)
	local base = cf * CFrame.new(-(w / 2 - 3), 0, 0)
	part({ Name = "SignPost", Size = Vector3.new(0.8, 9, 0.8), CFrame = base * CFrame.new(0, 4.5, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood, Parent = model })
	local board = part({ Name = "Sign", Size = Vector3.new(7, 7, 0.5), CFrame = base * CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(15), math.rad(45)), Color = Color3.fromRGB(255, 200, 30), Parent = model })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(200, 200)
	gui.LightInfluence = 0.4
	gui.Parent = board
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Rotation = -45
	l.FontFace = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(0, 0, 0)
	l.Text = text == "STEEP DROP!" and "⬇" or (text == "THE DROP" and "⬇⬇" or "!")
	l.Parent = gui
	light(board, Color3.fromRGB(255, 220, 120), 10, 0.8)
end

local function beacon(model: Model, cf: CFrame, name: string)
	local pos = (cf * CFrame.new(-24, 0, 0)).Position
	local rng = Random.new(#name)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		part({ Name = "Stone", Size = Vector3.new(2.6, 1.8, 2.2), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 4, 0.6, math.sin(a) * 4)) * CFrame.Angles(0, -a, rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(120, 112, 104), Material = Enum.Material.Slate, Parent = model })
	end
	local core = part({ Name = "Beacon", Size = Vector3.new(3, 4.5, 3), CFrame = CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0.3, 0.6, 0.2), Color = AMBER, Material = Enum.Material.Neon, Parent = model })
	core:SetAttribute("Stop", name)
	light(core, Color3.fromRGB(255, 170, 80), 60, 3)
	local fire = Instance.new("Fire")
	fire.Size = 7
	fire.Heat = 12
	fire.Color = Color3.fromRGB(255, 160, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 230, 140)
	fire.Parent = core
	-- the safe ring on the floor
	part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, Config.Night.RING * 2, Config.Night.RING * 2), CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 210, 90), Material = Enum.Material.Neon, Transparency = 0.82, CanCollide = false, CastShadow = false, Parent = model })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FeedPrompt"
	prompt.ActionText = "Feed the Beacon"
	prompt.ObjectText = "Glowstone"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = core
	World.beacons[name] = core
	return core
end

local function tent(model: Model, at: CFrame, color: Color3)
	for _, side in { -1, 1 } do
		part({ ClassName = "WedgePart", Name = "Tent", Size = Vector3.new(8, 5, 3.5), CFrame = at * CFrame.new(side * 1.75, 2.5, 0) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0), Color = color, Material = Enum.Material.Fabric, Parent = model })
	end
end

local function buildStop(model: Model, stop)
	local cf, w, _, h = route:sample(stop.s)
	local rng = Random.new(route.seed + math.floor(stop.s))
	beacon(model, cf, stop.name)
	-- veins to mine around the walls (the reference's trees around the clearing)
	for i = 1, 8 do
		local zc = cf * CFrame.new(0, 0, -90 + i * 22)
		local v = vein(model, zc, w, h, rng, true)
		v:SetAttribute("HP", 12)
		v:SetAttribute("Stop", stop.name)
		table.insert(World.veins, v)
	end
	-- the camp: tents, crates, lantern poles, a notice board
	tent(model, cf * CFrame.new(28, 0, -14) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(190, 70, 50))
	tent(model, cf * CFrame.new(32, 0, 10) * CFrame.Angles(0, -0.3, 0), Color3.fromRGB(70, 120, 170))
	for i = 1, 5 do
		part({ Name = "Crate", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = cf * CFrame.new(18 + (i % 3) * 3, 1.3 + math.floor(i / 3) * 2.6, 26 + (i % 2) * 3) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Color = Color3.fromRGB(160, 110, 66), Material = Enum.Material.WoodPlanks, Parent = model })
	end
	for _, z in { -40, 40 } do
		for _, x in { -40, 40 } do
			local pole = part({ Name = "LanternPole", Size = Vector3.new(0.8, 10, 0.8), CFrame = cf * CFrame.new(x, 5, z), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood, Parent = model })
			local lamp = part({ Name = "Lantern", Size = Vector3.new(1.4, 1.6, 1.4), CFrame = pole.CFrame * CFrame.new(0, 5.6, 0), Color = Color3.fromRGB(255, 200, 110), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
			light(lamp, Color3.fromRGB(255, 190, 110), 30, 1.6)
		end
	end
	local boardPart = part({ Name = "NoticeBoard", Size = Vector3.new(6, 4, 0.5), CFrame = cf * CFrame.new(-12, 4.5, 34) * CFrame.Angles(0, math.rad(200), 0), Color = Color3.fromRGB(140, 96, 60), Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Name = "Post", Size = Vector3.new(0.6, 4.5, 0.6), CFrame = boardPart.CFrame * CFrame.new(0, -3.5, 0.3), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood, Parent = model })
end

local function buildCavern(model: Model, cf: CFrame, w: number, h: number, rng: Random)
	if rng:NextNumber() < 0.45 then
		-- a glow pool
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local r = rng:NextNumber(10, 16)
		local p = part({ Name = "GlowPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, r * 2, r * 2), CFrame = cf * CFrame.new(side * (w / 2 - r - 4), 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 220, 230), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, Parent = model })
		light(p, Color3.fromRGB(80, 220, 255), 30, 1.4)
	end
	if rng:NextNumber() < 0.5 then
		-- crystal spires
		local side = rng:NextNumber() < 0.5 and -1 or 1
		for i = 1, 3 do
			local c = part({ Name = "Spire", Size = Vector3.new(3, rng:NextNumber(10, 22), 3), CFrame = cf * CFrame.new(side * (w / 2 - 8 - i * 3), 5, rng:NextNumber(-10, 10)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(170, 110, 255), Material = Enum.Material.Neon, Transparency = 0.1, Parent = model })
			if i == 1 then
				light(c, Color3.fromRGB(170, 120, 255), 30, 1.5)
			end
		end
	end
	if rng:NextNumber() < 0.5 then
		-- glowing mushrooms
		local side = rng:NextNumber() < 0.5 and -1 or 1
		for i = 1, 4 do
			local x = side * (w / 2 - 6 - i * 4)
			local stem = rng:NextNumber(3, 8)
			part({ Name = "Stem", Size = Vector3.new(1.4, stem, 1.4), CFrame = cf * CFrame.new(x, stem / 2, rng:NextNumber(-12, 12)), Color = Color3.fromRGB(230, 220, 200), Material = Enum.Material.SmoothPlastic, Parent = model })
			local cap = part({ Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, stem * 1.2, stem * 1.2), CFrame = cf * CFrame.new(x, stem, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 230, 200), Material = Enum.Material.Neon, Parent = model })
			if i == 1 then
				light(cap, Color3.fromRGB(90, 240, 210), 18, 1)
			end
		end
	end
end

local function inCavern(s: number): boolean
	for _, c in route.caverns do
		if s >= c.s0 - 4 and s <= c.s1 + 4 then
			return true
		end
	end
	return false
end

local function buildChunk(k: number)
	local nodes = route.nodes
	local a = k * CHUNK + 1
	local b = math.min(a + CHUNK, #nodes)
	if a >= #nodes then
		return
	end
	local pa, pb = nodes[a].p, nodes[b].p
	local mid = (pa + pb) / 2
	local len = (pb - pa).Magnitude
	local w = math.max(nodes[a].w, nodes[b].w)
	local h = math.max(nodes[a].h, nodes[b].h)
	local cf = CFrame.lookAt(mid, pb)
	local s0 = (a - 1) * Route.STEP
	local kind = nodes[a].kind
	local model = Instance.new("Model")
	model.Name = "Chunk" .. k
	local rng = Random.new(route.seed * 7 + k)
	if kind == "Gorge" then
		buildSurface(model, cf, len, w, k)
	else
		fillShell(cf, len, w, h, s0)
		local region = World.regionAt(s0)
		if region and region.opened then
			hollow(cf, len, w, h, rng) -- the drill already broke into this void
		end
		if kind == "Drop" and World.shaft then
			-- keep the shaft open through this slice of the spiral
			local sh = World.shaft
			T:FillCylinder(CFrame.new(sh.centre.X, cf.Position.Y + h / 2, sh.centre.Z), h + SHELL * 2 + 12, sh.radius - 18, Enum.Material.Air)
		end
		if kind == "Cavern" then
			buildCavern(model, cf, w, h, rng)
		end
	end
	for _, st in route.stops do
		if st.s >= s0 and st.s < s0 + CHUNK_LEN then
			buildStop(model, st)
		end
	end
	for _, h2 in route.hazards do
		if h2.s >= s0 and h2.s < s0 + CHUNK_LEN then
			local hcf = route:sample(h2.s)
			if h2.kind == "Boulder" then
				part({ Name = "Boulder", Size = Vector3.new(9, 8, 9), CFrame = hcf * CFrame.new(h2.offset, 3.5, 0) * CFrame.Angles(0.3, h2.s % 3, 0.2), Color = Color3.fromRGB(110, 96, 86), Material = Enum.Material.Rock, Parent = model })
			end
		end
	end
	for _, sg in route.signs do
		if sg.s >= s0 and sg.s < s0 + CHUNK_LEN then
			local scf, sw = route:sample(sg.s)
			signPost(model, scf, sw, sg.text)
		end
	end
	model.Parent = folder
	models[k] = model
	built[k] = true
end

-- natural voids (caverns, stop chambers, The Drop) open all at once when the
-- drill breaks into them
local regions = {}
function World.regionAt(s: number)
	for _, r in regions do
		if s >= r.s0 and s < r.s1 then
			return r
		end
	end
	return nil
end

local function openRegion(r)
	r.opened = true
	for s = r.s0, r.s1, CHUNK_LEN do
		local k = math.floor(s / CHUNK_LEN)
		if built[k] then
			local cf, w, _, h = route:sample(s + CHUNK_LEN / 2)
			hollow(cf, CHUNK_LEN + 6, w, h, Random.new(k))
		end
	end
end

-- the drill: carve the bore just ahead of the bit, revealing veins as it goes.
-- Returns "breakthrough" when it opens into a void, "bore" while carving rock.
function World.carve(toS: number): string?
	local what = nil
	while carvedTo < toS do
		local s = carvedTo
		carvedTo += 3
		local kind = route:kindAt(s)
		if kind == "Gorge" then
			continue
		end
		local region = World.regionAt(s)
		if region then
			if not region.opened then
				openRegion(region)
				what = "breakthrough"
			end
			continue
		end
		local cf, w, _, h = route:sample(s)
		T:FillBlock(cf * CFrame.new(0, h * 0.35 + 0.5, 0), Vector3.new(w, h * 0.7, 4), Enum.Material.Air)
		T:FillCylinder(cf * CFrame.new(0, h * 0.6, 0) * CFrame.Angles(math.rad(90), 0, 0), 4, math.min(w, h * 1.3) / 2, Enum.Material.Air)
		if s % 12 < 3 then
			-- lumpy walls: bites out of the rock, sometimes a deep alcove
			local rng = Random.new(math.floor(s))
			local side = rng:NextNumber() < 0.5 and -1 or 1
			local r = rng:NextNumber() < 0.12 and rng:NextNumber(9, 13) or rng:NextNumber(4, 8)
			T:FillBall((cf * CFrame.new(side * (w / 2 + r * 0.4), rng:NextNumber(4, h * 0.85), 0)).Position, r, Enum.Material.Air)
			if rng:NextNumber() < 0.35 then
				-- and a boss of rock bulging back in from the other wall
				T:FillBall((cf * CFrame.new(-side * (w / 2 + 2), rng:NextNumber(6, h * 0.7), 0)).Position, rng:NextNumber(3, 5), Enum.Material.Rock)
			end
		end
		local k = math.floor(s / CHUNK_LEN)
		if models[k] then
			if s - lastVein > 26 then
				lastVein = s
				vein(models[k], cf, w, h, Random.new(math.floor(s) + 17))
			end
			if s % 96 < 3 and math.floor(s / 96) % 3 ~= 1 then
				timbers(models[k], cf, w, h)
			end
			if s % 12 < 3 then
				detail(models[k], cf, w, h, Random.new(math.floor(s) + 5))
			end
		end
		what = what or "bore"
	end
	return what
end

-- The Drop: an open shaft down the middle of the spiral, lit from the sky above
local function openShaft()
	local d = route.drop
	if not d then
		return
	end
	local sum, n = Vector3.zero, 0
	local top, bottom = -math.huge, math.huge
	for s = d.s0, d.s1, 40 do
		local p = route:sample(s).Position
		sum += Vector3.new(p.X, 0, p.Z)
		n += 1
		top = math.max(top, p.Y)
		bottom = math.min(bottom, p.Y)
	end
	local c = sum / n
	local radius = 1150 / (1.5 * 2 * math.pi)
	World.shaft = { centre = c, radius = radius, top = top, bottom = bottom }
	-- (each Drop chunk keeps its slice of the shaft open as it's built)
	task.spawn(function()
		-- the sinkhole's rim at the surface
		for i = 1, 26 do
			local a = i / 26 * math.pi * 2
			part({ Name = "Rim", Size = Vector3.new(16, 6 + i % 4 * 3, 12), CFrame = CFrame.new(c.X + math.cos(a) * (radius + 26), top + 2, c.Z + math.sin(a) * (radius + 26)) * CFrame.Angles(0.2 * (i % 2), -a, 0.15), Color = CLIFF[i % 4 + 1], Material = Enum.Material.Sandstone, Parent = folder })
		end
		local sunShaft = part({ Name = "SunShaft", Shape = Enum.PartType.Cylinder, Size = Vector3.new(top - bottom, radius * 1.4, radius * 1.4), CFrame = CFrame.new(c.X, (top + bottom) / 2, c.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 230, 170), Material = Enum.Material.Neon, Transparency = 0.94, CanCollide = false, CanQuery = false, CastShadow = false, Parent = folder })
		sunShaft:SetAttribute("Decor", true)
	end)
end

function World.init(r)
	route = r
	local old = Workspace:FindFirstChild("Cavern")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Cavern"
	folder.Parent = Workspace
	T.CollisionGroup = "World"
	-- (Workspace.FallenPartsDestroyHeight must be set in the place, to -20000:
	-- the route goes far below the default -500)
	-- strata colours (terrain materials are tinted globally)
	T:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(168, 118, 96))
	T:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 116, 102))
	T:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(104, 116, 146))
	T:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(196, 186, 168))
	T:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(70, 60, 70))
	T:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 110, 80))
	regions = {}
	for _, p in route.pieces do
		if p.kind == "Cavern" or p.kind == "Drop" or p.kind:sub(1, 4) == "Stop" then
			table.insert(regions, { s0 = p.s0, s1 = p.s1, kind = p.kind, opened = false })
		end
	end
	openShaft()
end

function World.update(s: number, budget: number?)
	local last = math.min(math.floor(route.length / CHUNK_LEN), math.floor((s + AHEAD) / CHUNK_LEN))
	local built_ = 0
	for k = math.max(0, math.floor((s - 100) / CHUNK_LEN)), last do
		if not built[k] then
			buildChunk(k)
			built_ += 1
			if budget and built_ >= budget then
				break
			end
		end
	end
	-- drop prop models far behind (the terrain stays for anyone left behind)
	for k, m in models do
		if (k + 1) * CHUNK_LEN < s - 900 then
			m:Destroy()
			models[k] = nil
		end
	end
end

-- per-section atmosphere and the glow cycle's colour grade (docs/look-proposal.md)
local atmosphere, grade, bloom
local function ensureLighting()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	grade = Lighting:FindFirstChild("Grade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Parent = Lighting
	bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 22
	bloom.Threshold = 1.5
	bloom.Parent = Lighting
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
end

local SECTIONS = {
	Gorge = { amb = Color3.fromRGB(150, 120, 100), fog = Color3.fromRGB(255, 196, 150), density = 0.32, haze = 2.2, tint = Color3.fromRGB(255, 244, 230) },
	Drop = { amb = Color3.fromRGB(110, 86, 70), fog = Color3.fromRGB(230, 150, 90), density = 0.42, haze = 2.6, tint = Color3.fromRGB(255, 236, 214) },
	Tunnel = { amb = Color3.fromRGB(96, 92, 100), fog = Color3.fromRGB(120, 104, 100), density = 0.32, haze = 1, tint = Color3.fromRGB(240, 240, 250) },
	Chute = { amb = Color3.fromRGB(130, 84, 70), fog = Color3.fromRGB(200, 96, 60), density = 0.38, haze = 1.8, tint = Color3.fromRGB(255, 222, 204) },
	Cavern = { amb = Color3.fromRGB(90, 120, 130), fog = Color3.fromRGB(70, 170, 180), density = 0.34, haze = 2.2, tint = Color3.fromRGB(230, 250, 255) },
	Stop = { amb = Color3.fromRGB(130, 104, 84), fog = Color3.fromRGB(200, 140, 90), density = 0.3, haze = 1.6, tint = Color3.fromRGB(255, 240, 220) },
}

-- glow: 1 = full glow, 0 = Lights Out (the reference's day -> dusk -> night grading)
function World.atmosphere(s: number, glow: number)
	if not atmosphere then
		ensureLighting()
	end
	local kind = route:kindAt(s)
	if kind:sub(1, 4) == "Stop" then
		kind = "Stop"
	end
	local sec = SECTIONS[kind] or SECTIONS.Tunnel
	local dusk = Color3.fromRGB(255, 120, 110)
	local night = Color3.fromRGB(110, 140, 230)
	local tint = glow > 0.35 and sec.tint:Lerp(dusk, (1 - glow) * 0.6) or dusk:Lerp(night, (0.35 - glow) / 0.35)
	local amb = sec.amb:Lerp(Color3.fromRGB(30, 34, 60), (1 - glow) * 0.7)
	Lighting.Ambient = Lighting.Ambient:Lerp(amb, 0.1)
	Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(amb, 0.1)
	atmosphere.Color = atmosphere.Color:Lerp(sec.fog, 0.08)
	atmosphere.Decay = atmosphere.Decay:Lerp(sec.fog:Lerp(Color3.new(0, 0, 0), 0.4), 0.08)
	atmosphere.Density = atmosphere.Density + (sec.density - atmosphere.Density) * 0.08
	atmosphere.Haze = atmosphere.Haze + (sec.haze - atmosphere.Haze) * 0.08
	grade.TintColor = grade.TintColor:Lerp(tint, 0.08)
	grade.Saturation = 0.08
	grade.Contrast = 0.12
	Lighting.ClockTime = kind == "Gorge" and 14.5 or 14.5
end

-- glowstone outcrops on the ground by the spawn ("Mine glowstone 0/12")
function World.spawnVeins(at: CFrame)
	local model = Instance.new("Model")
	model.Name = "SpawnVeins"
	model.Parent = folder
	local rng = Random.new(route.seed)
	for i, off in { Vector3.new(-18, 0, 26), Vector3.new(16, 0, 30), Vector3.new(-8, 0, 44), Vector3.new(22, 0, 50), Vector3.new(-24, 0, 58) } do
		local base = at * CFrame.new(off) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
		part({ Name = "Outcrop", Size = Vector3.new(7, 3, 6), CFrame = base * CFrame.new(0, 1, 0), Color = CLIFF[i % 4 + 1], Material = Enum.Material.Sandstone, Parent = model })
		local v = Instance.new("Model")
		v.Name = "Vein"
		for j = 1, 5 do
			local c = part({ Name = "Crystal", Size = Vector3.new(1.6, 5, 1.6) * rng:NextNumber(0.8, 1.3), CFrame = base * CFrame.new(rng:NextNumber(-2, 2), 3.5, rng:NextNumber(-2, 2)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5)), Color = j % 2 == 0 and AMBER or Color3.fromRGB(255, 214, 110), Material = Enum.Material.Neon, Parent = v })
			if j == 1 then
				light(c, Color3.fromRGB(255, 170, 70), 18, 1.4)
				v.PrimaryPart = c
			end
		end
		v:SetAttribute("HP", 12)
		v.Parent = model
		table.insert(World.veins, v)
	end
end

function World.removeVein(v: Model)
	local i = table.find(World.veins, v)
	if i then
		table.remove(World.veins, i)
	end
	v:Destroy()
end

return World
