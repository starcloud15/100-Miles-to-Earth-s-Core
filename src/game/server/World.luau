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
local Story = require(Shared.Story)

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
World.notePrompts = {} -- the notice boards' "[E] Read" prompts

local FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
local AMBER = Color3.fromRGB(255, 178, 60)
local ROCK_RED = { Color3.fromRGB(190, 104, 70), Color3.fromRGB(170, 92, 64), Color3.fromRGB(206, 128, 86) }

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

-- an invisible wall along a drop-off: it stops the crew walking or jumping off
-- the route (only the crew collide with it; the rig and the world pass through)
local function barrier(model: Model, cf: CFrame, x: number, len: number)
	part({ Name = "Barrier", Size = Vector3.new(1, 18, len + 2), CFrame = cf * CFrame.new(x, 8, 0), Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false, CollisionGroup = "Barrier", Parent = model })
end

local VEIN_COLOR: Color3? = nil -- the zone's glowstone colour, if not amber

local function light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- strata: the rock changes with depth, in bands (warm sandstone, slate, dark basalt)
-- props: Blender meshes from Starport (tools/blender/props.py), painted by name
local PROP_PAINT = {
	Rock = { Color3.fromRGB(190, 104, 70), Enum.Material.Sandstone },
	RockDark = { Color3.fromRGB(140, 80, 58), Enum.Material.Slate },
	Wood = { Color3.fromRGB(150, 98, 58), Enum.Material.WoodPlanks },
	WoodDark = { Color3.fromRGB(104, 66, 40), Enum.Material.Wood },
	Glow = { Color3.fromRGB(255, 186, 70), Enum.Material.Neon },
	Steel = { Color3.fromRGB(110, 116, 126), Enum.Material.Metal },
	Cloth = { Color3.fromRGB(190, 70, 50), Enum.Material.Fabric },
	Moss = { Color3.fromRGB(90, 140, 70), Enum.Material.Grass },
	Paper = { Color3.fromRGB(236, 222, 186), Enum.Material.SmoothPlastic },
	Rope = { Color3.fromRGB(196, 170, 120), Enum.Material.Fabric },
}
local HANGING = { Stalactite = true }
local function prop(name: string, cf: CFrame, scale: number, model: Model, fallback: () -> ()): Model?
	local models = Shared:FindFirstChild("Models")
	local props = models and models:FindFirstChild("Props")
	local src = props and props:FindFirstChild(name)
	if not src then
		fallback()
		return nil
	end
	if not src:GetAttribute("Pivoted") then
		-- imported meshes keep their world placement: pivot on the bounds' bottom
		-- centre (top centre for hanging props), unrotated
		local bb, size = src:GetBoundingBox()
		src.WorldPivot = CFrame.new(bb.Position + Vector3.new(0, (HANGING[name] and 1 or -1) * size.Y / 2, 0))
		src:SetAttribute("Pivoted", true)
	end
	local c = src:Clone()
	if scale ~= 1 then
		c:ScaleTo(scale)
	end
	c:PivotTo(cf)
	for _, p in c:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CollisionGroup = "World"
			for prefix, look in PROP_PAINT do
				if p.Name:sub(1, #prefix) == prefix and #prefix > #(p:GetAttribute("Paint") or "") then
					p.Color = look[1]
					p.Material = look[2]
					p:SetAttribute("Paint", prefix)
				end
			end
		end
	end
	c.Parent = model
	return c
end

-- a glowstone vein to mine: the crystal cluster prop (or crystal parts), lit
local function glowVein(parent: Instance, base: CFrame, rng: Random, size: number, range: number, name: string?): Model
	local v = prop("CrystalCluster", base * CFrame.Angles(0, rng:NextNumber(0, 6), 0), size, parent :: any, function() end)
	if v then
		v.PrimaryPart = v:FindFirstChild("Glow") :: BasePart
	else
		v = Instance.new("Model")
		for j = 1, 5 do
			local c = part({ Name = "Crystal", Size = Vector3.new(1.6, 5, 1.6) * size * rng:NextNumber(0.8, 1.3), CFrame = base * CFrame.new(rng:NextNumber(-2, 2) * size, 2.5 * size, rng:NextNumber(-2, 2) * size) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5)), Color = j % 2 == 0 and AMBER or Color3.fromRGB(255, 214, 110), Material = Enum.Material.Neon, Parent = v })
			if j == 1 then
				v.PrimaryPart = c
			end
		end
		v.Parent = parent
	end
	v.Name = name or "Vein"
	if VEIN_COLOR then
		for _, p in v:GetDescendants() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
				p.Color = VEIN_COLOR
			end
		end
	end
	light(v.PrimaryPart :: BasePart, VEIN_COLOR or Color3.fromRGB(255, 170, 70), range, 1.3)
	return v :: Model
end

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
		local top = cf * CFrame.new(x, h * 0.86, rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
		prop("Stalactite", top, len / 8, model, function()
			part({ Name = "Stalactite", ClassName = "WedgePart", Size = Vector3.new(rng:NextNumber(1.5, 3), len, rng:NextNumber(1.5, 3)), CFrame = top * CFrame.new(0, -len / 2, 0) * CFrame.Angles(math.pi, 0, 0), Color = Color3.fromRGB(120, 92, 80), Material = Enum.Material.Rock, CanCollide = false, Parent = model })
		end)
	end
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local at = cf * CFrame.new(side * (w / 2 - 3), 0, rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	prop("RockCluster", at, rng:NextNumber(0.3, 0.45), model, function()
		for _ = 1, 2 do
			part({ Name = "Rubble", Size = Vector3.new(rng:NextNumber(1.5, 3.5), rng:NextNumber(1, 2.5), rng:NextNumber(1.5, 3.5)), CFrame = at * CFrame.new(rng:NextNumber(-2, 2), 0.8, rng:NextNumber(-2, 2)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)), Color = Color3.fromRGB(140, 104, 84), Material = Enum.Material.Slate, Parent = model })
		end
	end)
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
	-- a glowstone vein: amber crystals bursting out of a wall
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local base = cf * CFrame.new(side * (w / 2 - 0.5), rng:NextNumber(3, h * 0.6), rng:NextNumber(-8, 8)) * CFrame.Angles(0, 0, math.rad(side * 70))
	return glowVein(model, base, rng, big and 1.2 or 0.75, big and 24 or 18, big and "Vein" or "Glow")
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
	prop("BeaconRing", CFrame.new(pos), 1, model, function()
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			part({ Name = "Stone", Size = Vector3.new(2.6, 1.8, 2.2), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 4, 0.6, math.sin(a) * 4)) * CFrame.Angles(0, -a, rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(120, 112, 104), Material = Enum.Material.Slate, Parent = model })
		end
	end)
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
	local t = prop("Tent", at, 1, model, function()
		for _, side in { -1, 1 } do
			part({ ClassName = "WedgePart", Name = "Tent", Size = Vector3.new(8, 5, 3.5), CFrame = at * CFrame.new(side * 1.75, 2.5, 0) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0), Color = color, Material = Enum.Material.Fabric, Parent = model })
		end
	end)
	if t then
		for _, p in t:GetChildren() do
			if p.Name == "Cloth" then
				(p :: BasePart).Color = color
			end
		end
	end
end

local function buildStop(model: Model, stop)
	local cf, w, _, h = route:sample(stop.s)
	local rng = Random.new(route.seed + math.floor(stop.s))
	beacon(model, cf, stop.name)
	if stop.start then
		-- (the Waystation the crew left from: its spawn veins are mined instead)
	elseif stop.hall then
		-- on a platform in the cavern: veins in rock outcrops around its edge
		for i = 1, 8 do
			local side = i % 2 == 0 and 1 or -1
			local base = cf * CFrame.new(side * (w / 2 + rng:NextNumber(-2, 4)), 0, -96 + i * 22) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
			prop("RockCluster", base, 0.75, model, function()
				part({ Name = "Outcrop", Size = Vector3.new(9, 5, 8), CFrame = base * CFrame.new(0, 1.5, 0), Color = ROCK_RED[i % 3 + 1], Material = Enum.Material.Sandstone, Parent = model })
			end)
			local v = glowVein(model, base * CFrame.new(0, 2.6, 0), rng, 1.1, 22)
			v:SetAttribute("HP", 12)
			v:SetAttribute("Stop", stop.name)
			table.insert(World.veins, v)
		end
	else
		-- veins to mine around the walls (the reference's trees around the clearing)
		for i = 1, 8 do
			local zc = cf * CFrame.new(0, 0, -90 + i * 22)
			local v = vein(model, zc, w, h, rng, true)
			v:SetAttribute("HP", 12)
			v:SetAttribute("Stop", stop.name)
			table.insert(World.veins, v)
		end
	end
	-- the camp: tents, crates, lantern poles, a notice board
	tent(model, cf * CFrame.new(28, 0, -14) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(190, 70, 50))
	tent(model, cf * CFrame.new(32, 0, 10) * CFrame.Angles(0, -0.3, 0), Color3.fromRGB(70, 120, 170))
	for i = 1, 5 do
		local ccf = cf * CFrame.new(18 + (i % 3) * 3, math.floor(i / 3) * 2.6, 26 + (i % 2) * 3) * CFrame.Angles(0, rng:NextNumber(0, 1), 0)
		prop("Crate", ccf, 1, model, function()
			part({ Name = "Crate", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = ccf * CFrame.new(0, 1.3, 0), Color = Color3.fromRGB(160, 110, 66), Material = Enum.Material.WoodPlanks, Parent = model })
		end)
	end
	prop("Minecart", cf * CFrame.new(-30, 0, -26) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), 1, model, function() end)
	for _, z in { -40, 40 } do
		for _, x in { -40, 40 } do
			local pcf = cf * CFrame.new(x, 0, z) * CFrame.Angles(0, x > 0 and math.pi or 0, 0)
			local post = prop("LanternPost", pcf, 1, model, function()
				local pole = part({ Name = "LanternPole", Size = Vector3.new(0.8, 10, 0.8), CFrame = pcf * CFrame.new(0, 5, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood, Parent = model })
				local lamp = part({ Name = "Lantern", Size = Vector3.new(1.4, 1.6, 1.4), CFrame = pole.CFrame * CFrame.new(0, 5.6, 0), Color = Color3.fromRGB(255, 200, 110), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
				light(lamp, Color3.fromRGB(255, 190, 110), 30, 1.6)
			end)
			if post then
				light(post:FindFirstChild("Glow") :: BasePart, Color3.fromRGB(255, 190, 110), 30, 1.6)
			end
		end
	end
	local bcf = cf * CFrame.new(-12, 0, 34) * CFrame.Angles(0, math.rad(200), 0)
	local board = prop("NoticeBoard", bcf, 1, model, function()
		local boardPart = part({ Name = "NoticeBoard", Size = Vector3.new(6, 4, 0.5), CFrame = bcf * CFrame.new(0, 4.5, 0), Color = Color3.fromRGB(140, 96, 60), Material = Enum.Material.WoodPlanks, Parent = model })
		part({ Name = "Post", Size = Vector3.new(0.6, 4.5, 0.6), CFrame = boardPart.CFrame * CFrame.new(0, -3.5, 0.3), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood, Parent = model })
	end)
	if board then
		board.Name = "NoticeBoard"
	end
	-- "[E] Read": the notes pinned on this stop's board (docs/story.md)
	local boardPart = board and (board:FindFirstChild("Wood") or board:FindFirstChildWhichIsA("BasePart")) or model:FindFirstChild("NoticeBoard")
	if boardPart and not stop.start then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "NotePrompt"
		prompt.ActionText = "Read"
		prompt.ObjectText = "Note"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		local index = table.find(route.stops, stop) or 1
		prompt:SetAttribute("Notes", table.concat(Story.boardEntries(route.zone or 1, index, #route.stops), ","))
		prompt.Parent = boardPart
		table.insert(World.notePrompts, prompt)
	end
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

-- the zone's cavern (GDD 9.0): a giant hall the route crosses on bridges and ledges ----
local HALL = Config.ZONE_HALL[1] -- the current zone's cavern (World.init)
local function isHall(kind: string): boolean
	return kind:sub(1, 4) == "Hall"
end
-- where the route sits across the cavern (+ = right of the cavern's centre)
local function hallOffset(s: number): number
	return math.sin(s / 640) * 95 + math.sin(s / 230 + 1.3) * 28
end
local function hallFloor(s: number): number
	return HALL.FLOOR + math.noise(s / 400, 3.1) * 40
end
local function hallCeil(s: number): number
	return HALL.CEILING + math.noise(s / 500, 7.7) * 35
end


-- a Blender prop from Starport (src/shared/Models/Props), or a part fallback until it's uploaded

local function stalagmite(model: Model, at: CFrame, height: number, rng: Random)
	prop("Stalagmite", at, height / 30, model, function()
		local col = ROCK_RED[rng:NextInteger(1, 3)]
		local w = height * 0.35
		for i = 0, 2 do
			local f = 1 - i * 0.3
			part({ Name = "Stalagmite", Size = Vector3.new(w * f, height * 0.4, w * f), CFrame = at * CFrame.new(0, height * (0.2 + i * 0.3), 0) * CFrame.Angles(0, i * 0.7, 0), Color = col, Material = Enum.Material.Sandstone, Parent = model })
		end
	end)
end

local function arch(model: Model, centre: CFrame, radius: number)
	-- a natural sandstone arch spanning the cavern, from floor to floor over the route
	prop("Arch", centre, radius / 100, model, function()
		local n = 14
		for i = 0, n - 1 do
			local a0 = math.pi * i / n
			local a1 = math.pi * (i + 1) / n
			local p0 = Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
			local p1 = Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
			local mid = (p0 + p1) / 2
			local thick = 22 + math.sin(a0 * 2) * 4
			part({
				Name = "Arch",
				Size = Vector3.new((p1 - p0).Magnitude + 6, thick, 26),
				CFrame = centre * CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(p1.Y - p0.Y, p1.X - p0.X)),
				Color = ROCK_RED[i % 3 + 1],
				Material = Enum.Material.Sandstone,
				Parent = model,
			})
		end
	end)
end

local function lightShaft(model: Model, top: Vector3, bottom: Vector3)
	-- sunlight through a crack in the roof
	local mid = (top + bottom) / 2
	local len = (top - bottom).Magnitude
	part({ Name = "LightShaft", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 34, 34), CFrame = CFrame.lookAt(mid, top) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 226, 170), Material = Enum.Material.Neon, Transparency = 0.9, CanCollide = false, CanQuery = false, CastShadow = false, Parent = model })
	local crack = part({ Name = "Skylight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 26, 26), CFrame = CFrame.new(top) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 244, 210), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
	local spot = part({ Name = "SunSpot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 40, 40), CFrame = CFrame.new(bottom + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, Parent = model })
	light(spot, Color3.fromRGB(255, 220, 160), 60, 2)
	light(crack, Color3.fromRGB(255, 230, 180), 40, 1.5)
end

local function waterfall(model: Model, top: Vector3, bottom: Vector3, facing: CFrame)
	local h = top.Y - bottom.Y
	local at = CFrame.new((top + bottom) / 2) * facing.Rotation
	part({ Name = "Waterfall", Size = Vector3.new(22, h, 3), CFrame = at, Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false, CastShadow = false, Parent = model })
	part({ Name = "WaterfallCore", Size = Vector3.new(12, h, 4), CFrame = at, Color = Color3.fromRGB(230, 245, 255), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, CastShadow = false, Parent = model })
	local pool = part({ Name = "Pool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 60, 60), CFrame = CFrame.new(bottom + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 160, 200), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false, Parent = model })
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(230, 240, 255))
	mist.Size = NumberSequence.new(8, 20)
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.Lifetime = NumberRange.new(2, 3)
	mist.Speed = NumberRange.new(4, 9)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Rate = 6
	mist.Parent = pool
	light(pool, Color3.fromRGB(150, 210, 255), 50, 1.2)
end

local function trestle(model: Model, cf: CFrame, deckW: number, len: number, depth: number, k: number)
	local wood = Color3.fromRGB(140, 92, 54)
	part({ Name = "TrestleDeck", Size = Vector3.new(deckW, 2, len + 1), CFrame = cf * CFrame.new(0, -1, 0), Color = Color3.fromRGB(160, 108, 64), Material = Enum.Material.WoodPlanks, Parent = model })
	for _, side in { -1, 1 } do
		-- a timber fence: a kick rail, a hand rail and a post each span
		part({ Name = "TrestleRail", Size = Vector3.new(1.2, 1.2, len + 1), CFrame = cf * CFrame.new(side * (deckW / 2 - 0.6), 1.2, 0), Color = wood, Material = Enum.Material.Wood, Parent = model })
		part({ Name = "TrestleRail", Size = Vector3.new(0.8, 0.8, len + 1), CFrame = cf * CFrame.new(side * (deckW / 2 - 0.6), 4, 0), Color = wood, Material = Enum.Material.Wood, Parent = model })
		part({ Name = "TrestlePost", Size = Vector3.new(1, 4.6, 1), CFrame = cf * CFrame.new(side * (deckW / 2 - 0.6), 2.3, -len / 2 + 1), Color = wood, Material = Enum.Material.Wood, Parent = model })
	end
	if k % 2 == 0 then
		-- a bent: two legs splayed down to the floor, with a cross-brace
		for _, side in { -1, 1 } do
			local top = cf * Vector3.new(side * (deckW / 2 - 2), -2, 0)
			local bot = cf * Vector3.new(side * (deckW / 2 + 10), -depth, 0)
			local mid = (top + bot) / 2
			part({ Name = "TrestleLeg", Size = Vector3.new(2, (top - bot).Magnitude, 2), CFrame = CFrame.lookAt(mid, top) * CFrame.Angles(math.rad(90), 0, 0), Color = wood, Material = Enum.Material.Wood, Parent = model })
		end
		for _, y in { 0.3, 0.65 } do
			part({ Name = "TrestleBrace", Size = Vector3.new(deckW + 20 * y, 1.4, 1.4), CFrame = cf * CFrame.new(0, -depth * y, 0), Color = wood, Material = Enum.Material.Wood, Parent = model })
		end
	end
end

-- the colours glowing in the rock (the cave's palette beside the red stone)
local GEODE = {
	Color3.fromRGB(60, 230, 220), -- teal
	Color3.fromRGB(180, 110, 255), -- violet
	Color3.fromRGB(255, 110, 200), -- pink
	Color3.fromRGB(110, 170, 255), -- ice blue
	Color3.fromRGB(255, 186, 70), -- amber
}

local function geode(model: Model, at: CFrame, size: number, color: Color3, rng: Random)
	local g = prop("CrystalCluster", at * CFrame.Angles(0, rng:NextNumber(0, 6), 0), size, model, function()
		for i = 1, 5 do
			part({ Name = "Glow", Size = Vector3.new(1.4, 5, 1.4) * size * rng:NextNumber(0.7, 1.2), CFrame = at * CFrame.new(rng:NextNumber(-2, 2) * size, 2.4 * size, rng:NextNumber(-2, 2) * size) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 3), rng:NextNumber(-0.6, 0.6)), Color = color, Material = Enum.Material.Neon, Parent = model })
		end
	end)
	local glowPart
	if g then
		for _, p in g:GetChildren() do
			if p.Name == "Glow" then
				(p :: BasePart).Color = color
				glowPart = p
			end
		end
	end
	local anchor = glowPart or part({ Name = "GeodeLight", Size = Vector3.new(1, 1, 1), CFrame = at * CFrame.new(0, 3 * size, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
	light(anchor :: BasePart, color, 18 + size * 8, 1.6)
end

local function glowWorms(model: Model, at: CFrame, width: number, len: number)
	-- tiny blue-green lights speckling the roof, like the glow-worm caves
	local p = part({ Name = "GlowWorms", Size = Vector3.new(width, 1, len), CFrame = at, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = model })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(120, 230, 255), Color3.fromRGB(150, 255, 210))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.35)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.9, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Speed = NumberRange.new(0)
	e.Lifetime = NumberRange.new(20, 26)
	e.Rate = 3
	e.LockedToPart = true
	e.Parent = p
	e:Emit(60)
end

local function fungi(model: Model, at: CFrame, rng: Random)
	-- a clump of luminous teal mushrooms on the river bank
	for i = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(1.5, 4.5)
		local base = at * CFrame.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
		part({ Name = "Stem", Size = Vector3.new(0.6, h, 0.6), CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(226, 236, 222), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = model })
		local cap = part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(h * 0.9, h * 0.38, h * 0.9), CFrame = base * CFrame.new(0, h, 0), Color = i % 2 == 0 and Color3.fromRGB(70, 240, 210) or Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
		if i == 1 then
			light(cap, Color3.fromRGB(80, 240, 220), 22, 1.4)
		end
	end
end

-- zone 2, the Glowshroom Grotto (GDD 9.0): a deep indigo cavern grown with giant
-- glowing mushrooms; the route crosses a chain of mushroom caps and fallen stems,
-- spores drift down like snow, a luminous river winds along the floor ---------------------
local CAP = {
	Color3.fromRGB(60, 214, 200), -- teal
	Color3.fromRGB(150, 104, 242), -- violet
	Color3.fromRGB(232, 104, 196), -- pink
	Color3.fromRGB(92, 164, 255), -- blue
}
local STEM = Color3.fromRGB(222, 214, 200)
local GILLS = Color3.fromRGB(70, 46, 104)

local function giantMushroom(model: Model, at: CFrame, height: number, color: Color3, rng: Random)
	local m = prop("GiantMushroom", at * CFrame.Angles(0, rng:NextNumber(0, 6), 0), height / 60, model, function()
		local r = math.max(2, height * 0.07)
		local lean = CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
		local top = at * lean * CFrame.new(0, height, 0)
		part({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, r * 2, r * 2), CFrame = at * lean * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STEM, Material = Enum.Material.SmoothPlastic, Parent = model })
		part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(height * 0.75, height * 0.24, height * 0.75), CFrame = top, Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
		part({ Name = "Gills", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, height * 0.66, height * 0.66), CFrame = top * CFrame.new(0, -height * 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GILLS, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = model })
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			part({ Name = "Spots", Shape = Enum.PartType.Ball, Size = Vector3.one * height * 0.06, CFrame = top * CFrame.new(math.cos(a) * height * 0.2, height * 0.09, math.sin(a) * height * 0.2), Color = Color3.fromRGB(230, 255, 250), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
		end
	end)
	if m then
		for _, p in m:GetChildren() do
			if p.Name == "Cap" then
				(p :: BasePart).Color = color
			end
		end
	end
	local glow = part({ Name = "CapLight", Size = Vector3.one, CFrame = at * CFrame.new(0, height * 0.9, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
	light(glow, color, math.clamp(height * 0.6, 26, 50), 1.0)
end

local function sporeSnow(model: Model, at: CFrame, width: number, len: number)
	local p = part({ Name = "SporeSnow", Size = Vector3.new(width, 1, len), CFrame = at, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = model })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(170, 255, 236), Color3.fromRGB(210, 180, 255))
	e.LightEmission = 0.8
	e.Size = NumberSequence.new(0.45)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0.4, -0.2, 0)
	e.Lifetime = NumberRange.new(30, 40)
	e.Rate = 2
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Parent = p
end

local function buildGrotto(model: Model, cf: CFrame, len: number, w: number, s0: number, k: number, kind: string, rng: Random)
	local off = hallOffset(s0)
	local fl, ce = hallFloor(s0), hallCeil(s0)
	local W = HALL.WIDTH
	local ccf = cf * CFrame.new(-off, 0, 0)
	local L = len + 10
	-- the shell: dark indigo stone banded violet, lilac and pale teal
	T:FillBlock(ccf * CFrame.new(0, -fl - 12, 0), Vector3.new(W + 80, 24, L), Enum.Material.Basalt)
	T:FillBlock(ccf * CFrame.new(0, ce + 14, 0), Vector3.new(W + 80, 28, L), Enum.Material.Basalt)
	for _, side in { -1, 1 } do
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 14), (ce - fl) / 2, 0), Vector3.new(28, ce + fl + 50, L), Enum.Material.Sandstone)
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 4), -fl * 0.5, 0), Vector3.new(12, 14, L), Enum.Material.Slate)
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 4), ce * 0.3, 0), Vector3.new(12, 10, L), Enum.Material.Salt)
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 4), ce * 0.7, 0), Vector3.new(12, 6, L), Enum.Material.Limestone)
	end
	if rng:NextNumber() < 0.6 then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local r = rng:NextNumber(14, 30)
		T:FillBall((ccf * CFrame.new(side * (W / 2 - r * 0.25), rng:NextNumber(-fl, ce), 0)).Position, r, Enum.Material.Sandstone)
	end
	-- violet moss over the floor, a glowing river with teal moss banks
	T:FillBlock(ccf * CFrame.new(0, -fl + 0.5, 0), Vector3.new(W, 2, L), Enum.Material.Grass)
	local river = math.sin(s0 / 900) * W * 0.18
	T:FillBlock(ccf * CFrame.new(river, -fl - 3, 0), Vector3.new(W * 0.26, 8, L), Enum.Material.Water)
	for _, side in { -1, 1 } do
		T:FillBlock(ccf * CFrame.new(river + side * (W * 0.13 + 12), -fl + 1, 0), Vector3.new(20, 4, L), Enum.Material.LeafyGrass)
	end
	if k % 2 == 0 then
		-- a glow strip on the river, so it reads as luminous from up on the caps
		local strip = part({ Name = "RiverGlow", Size = Vector3.new(W * 0.2, 0.4, L), CFrame = ccf * CFrame.new(river, -fl - 0.6, 0), Color = Color3.fromRGB(60, 230, 210), Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false, CastShadow = false, Parent = model })
		if k % 6 == 0 then
			light(strip, Color3.fromRGB(70, 230, 210), 60, 1.2)
		end
	end
	if rng:NextNumber() < 0.5 then
		-- glowing vines hanging from the roof
		local top = ccf * CFrame.new(rng:NextNumber(-W / 2 + 20, W / 2 - 20), ce - 2, 0)
		for i = 1, rng:NextInteger(3, 6) do
			local h = rng:NextNumber(12, 45)
			part({ Name = "Vine", Size = Vector3.new(0.6, h, 0.6), CFrame = top * CFrame.new(rng:NextNumber(-8, 8), -h / 2, rng:NextNumber(-8, 8)), Color = i % 2 == 0 and Color3.fromRGB(80, 230, 200) or Color3.fromRGB(170, 130, 255), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false, CanQuery = false, CastShadow = false, Parent = model })
		end
	end

	-- the route: a chain of giant mushroom caps, each on its own stalk; every few
	-- hundred studs a fallen stem lies across the gap as a bridge
	local deckW = w + 16
	local isLog = kind == "Hall" and math.floor(s0 / 1100) % 3 == 1
	if isLog then
		part({ Name = "FallenStem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len + 2, 30, 30), CFrame = cf * CFrame.new(0, -15, 0) * CFrame.Angles(0, math.rad(90), 0), Color = STEM, Material = Enum.Material.SmoothPlastic, Parent = model })
		part({ Name = "StemWalk", Size = Vector3.new(deckW * 0.7, 2, len + 2), CFrame = cf * CFrame.new(0, -1, 0), Color = STEM:Lerp(Color3.new(0, 0, 0), 0.08), Material = Enum.Material.SmoothPlastic, Parent = model })
		if k % 2 == 0 then
			-- shelf fungi glowing along its flanks
			for _, side in { -1, 1 } do
				part({ Name = "Shelf", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 7, 7), CFrame = cf * CFrame.new(side * 15, -9, rng:NextNumber(-8, 8)) * CFrame.Angles(0, 0, math.rad(90)), Color = CAP[(k % #CAP) + 1], Material = Enum.Material.Neon, CanCollide = false, Parent = model })
			end
		end
	elseif k % 2 == 0 then
		local col = CAP[(math.floor(k / 2) % #CAP) + 1]
		local D = deckW + 18
		part({ Name = "CapPath", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, D, D), CFrame = cf * CFrame.new(0, -3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = col, Material = Enum.Material.SmoothPlastic, Parent = model })
		part({ Name = "CapRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, D + 3, D + 3), CFrame = cf * CFrame.new(0, -6.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = col:Lerp(Color3.new(1, 1, 1), 0.35), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = model })
		part({ Name = "CapGills", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, D - 4, D - 4), CFrame = cf * CFrame.new(0, -7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GILLS, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = model })
		if k % 4 == 0 then
			-- the cap's stalk, down to the moss
			local h = fl - 6
			part({ Name = "Stalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 16, 16), CFrame = cf * CFrame.new(0, -6 - h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STEM, Material = Enum.Material.SmoothPlastic, Parent = model })
			local glow = part({ Name = "CapLight", Size = Vector3.one, CFrame = cf * CFrame.new(0, -9, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
			light(glow, col, 50, 1.8)
		end
	end
	-- little glowing mushrooms along the walkway's edges
	if k % 3 == 1 then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		fungi(model, cf * CFrame.new(side * (deckW / 2 - 4), 0, rng:NextNumber(-6, 6)), rng)
	end
	for _, side in { -1, 1 } do
		barrier(model, cf, side * (deckW / 2 + 0.5), len)
	end

	-- the forest: giant mushrooms rising from the floor, some taller than the route
	if k % 2 == 1 then
		for _ = 1, 2 do
			local x = rng:NextNumber(-W / 2 + 20, W / 2 - 20)
			if math.abs(x - off) > 55 then
				giantMushroom(model, ccf * CFrame.new(x, -fl, rng:NextNumber(-10, 10)), rng:NextNumber(70, fl + 60), CAP[rng:NextInteger(1, #CAP)], rng)
			end
		end
	end
	if k % 41 == 20 then
		-- the mother mushroom: a canopy almost to the roof, beside the route
		local side = rng:NextNumber() < 0.5 and -1 or 1
		giantMushroom(model, ccf * CFrame.new(off + side * 90, -fl, 0), fl + ce - 30, CAP[2], rng)
	end
	if k % 5 == 2 then
		local x = rng:NextNumber(-W / 2 + 30, W / 2 - 30)
		if math.abs(x - off) > 40 then
			geode(model, ccf * CFrame.new(x, -fl, rng:NextNumber(-8, 8)), rng:NextNumber(2, 3.2), k % 10 == 2 and GEODE[1] or GEODE[2], rng)
		end
	end
	if k % 4 == 3 then
		fungi(model, ccf * CFrame.new(river + (rng:NextNumber() < 0.5 and -1 or 1) * (W * 0.13 + rng:NextNumber(4, 20)), -fl + 2, rng:NextNumber(-8, 8)), rng)
	end
	if k % 3 == 0 then
		glowWorms(model, ccf * CFrame.new(rng:NextNumber(-W / 4, W / 4), ce - 3, 0), W * 0.7, L)
	end
	if k % 4 == 2 then
		sporeSnow(model, ccf * CFrame.new(off * 0.5, ce * 0.6, 0), W * 0.6, L * 2)
	end
	if rng:NextNumber() < 0.35 then
		vein(model, ccf, W, ce, rng)
	end
end

local function buildHall(model: Model, cf: CFrame, len: number, w: number, s0: number, k: number, kind: string, rng: Random)
	if HALL.theme == "Grotto" then
		buildGrotto(model, cf, len, w, s0, k, kind, rng)
		return
	end
	local off = hallOffset(s0)
	local fl, ce = hallFloor(s0), hallCeil(s0)
	local W = HALL.WIDTH
	local ccf = cf * CFrame.new(-off, 0, 0) -- the cavern's centre line at route height
	local L = len + 10
	-- the shell: floor, ceiling and walls in red sandstone, with layered bands on the walls
	T:FillBlock(ccf * CFrame.new(0, -fl - 12, 0), Vector3.new(W + 80, 24, L), Enum.Material.Sandstone)
	T:FillBlock(ccf * CFrame.new(0, ce + 14, 0), Vector3.new(W + 80, 28, L), Enum.Material.Sandstone)
	for _, side in { -1, 1 } do
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 14), (ce - fl) / 2, 0), Vector3.new(28, ce + fl + 50, L), Enum.Material.Sandstone)
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 4), -fl * 0.4, 0), Vector3.new(12, 12, L), Enum.Material.Limestone)
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 4), ce * 0.35, 0), Vector3.new(12, 16, L), Enum.Material.Slate)
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 4), ce * 0.75, 0), Vector3.new(12, 10, L), Enum.Material.Salt)
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 4), -fl * 0.78, 0), Vector3.new(12, 8, L), Enum.Material.Salt)
		T:FillBlock(ccf * CFrame.new(side * (W / 2 + 4), ce * 0.08, 0), Vector3.new(12, 5, L), Enum.Material.Limestone)
	end
	-- lumps on the walls, stalactite knots on the roof, mounds on the floor
	if rng:NextNumber() < 0.6 then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local r = rng:NextNumber(14, 30)
		T:FillBall((ccf * CFrame.new(side * (W / 2 - r * 0.25), rng:NextNumber(-fl, ce), 0)).Position, r, rng:NextNumber() < 0.3 and Enum.Material.Rock or Enum.Material.Sandstone)
	end
	if rng:NextNumber() < 0.5 then
		local r = rng:NextNumber(8, 18)
		T:FillBall((ccf * CFrame.new(rng:NextNumber(-W / 2, W / 2), ce - r * 0.3, 0)).Position, r, Enum.Material.Sandstone)
	end
	if rng:NextNumber() < 0.5 then
		local r = rng:NextNumber(12, 26)
		T:FillBall((ccf * CFrame.new(rng:NextNumber(-W / 2 + 30, W / 2 - 30), -fl, 0)).Position, r, Enum.Material.Ground)
	end
	-- the underground river along the cavern floor, green moss banks either side
	local river = math.sin(s0 / 900) * W * 0.18
	T:FillBlock(ccf * CFrame.new(river, -fl - 3, 0), Vector3.new(W * 0.3, 6, L), Enum.Material.Water)
	for _, side in { -1, 1 } do
		T:FillBlock(ccf * CFrame.new(river + side * (W * 0.15 + 14), -fl + 1, 0), Vector3.new(24, 4, L), Enum.Material.LeafyGrass)
	end
	if rng:NextNumber() < 0.45 then
		-- moss and hanging roots on the ceiling
		local x = rng:NextNumber(-W / 2 + 20, W / 2 - 20)
		local top = ccf * CFrame.new(x, ce - 2, 0)
		for i = 1, rng:NextInteger(3, 6) do
			local h = rng:NextNumber(14, 40)
			part({ Name = "Root", Size = Vector3.new(0.8, h, 0.8), CFrame = top * CFrame.new(rng:NextNumber(-8, 8), -h / 2, rng:NextNumber(-8, 8)) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)), Color = Color3.fromRGB(70 + i * 6, 120, 58), Material = Enum.Material.Grass, CanCollide = false, CastShadow = false, Parent = model })
		end
	end

	-- the route: a rock causeway (or an old mining trestle), a ledge where it hugs a wall
	local deckW = w + 16
	local nearWall = math.abs(off) > W / 2 - 75
	local wallSide = off >= 0 and 1 or -1
	local isTrestle = kind == "Hall" and math.floor(s0 / 1100) % 3 == 1 and not nearWall
	if isTrestle then
		trestle(model, cf, deckW, len, fl, k)
	else
		local col = ROCK_RED[(k % 3) + 1]
		part({ Name = "Causeway", Size = Vector3.new(deckW, 6, len + 2), CFrame = cf * CFrame.new(0, -3, 0), Color = col, Material = Enum.Material.Sandstone, Parent = model })
		part({ Name = "Keel", Size = Vector3.new(deckW * 0.6, 10, len + 2), CFrame = cf * CFrame.new(0, -11, 0), Color = ROCK_RED[((k + 1) % 3) + 1], Material = Enum.Material.Sandstone, Parent = model })
		part({ Name = "Keel", Size = Vector3.new(deckW * 0.28, 12, len + 2), CFrame = cf * CFrame.new(0, -22, 0), Color = col, Material = Enum.Material.Sandstone, Parent = model })
		-- a weathered rock lip along each edge, and now and then a pile of rocks on it
		for _, side in { -1, 1 } do
			if not (nearWall and side == wallSide) then
				part({ Name = "Lip", Size = Vector3.new(3, 2.2, len + 2), CFrame = cf * CFrame.new(side * (deckW / 2 - 1.5), 1, 0), Color = ROCK_RED[((k + 2) % 3) + 1]:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Sandstone, Parent = model })
				if (k + (side > 0 and 1 or 0)) % 4 == 0 then
					prop("RockCluster", cf * CFrame.new(side * (deckW / 2 - 2), 0, rng:NextNumber(-8, 8)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng:NextNumber(0.35, 0.55), model, function() end)
				end
			end
		end
		if nearWall then
			-- a shelf back to the wall: the route runs along a ledge here
			local gap = W / 2 - math.abs(off)
			part({ Name = "Ledge", Size = Vector3.new(gap + 12, 16, len + 2), CFrame = cf * CFrame.new(wallSide * (deckW / 2 + gap / 2), -8, 0), Color = col, Material = Enum.Material.Sandstone, Parent = model })
			if gap > 14 and rng:NextNumber() < 0.3 then
				-- the Quarrymen worked these ledges: an old ore cart left by the wall
				prop("Minecart", cf * CFrame.new(wallSide * (deckW / 2 + math.min(gap, 20) / 2), 0, rng:NextNumber(-10, 10)) * CFrame.Angles(0, math.rad(90) + rng:NextNumber(-0.4, 0.4), 0), 1.4, model, function() end)
			end
		elseif k % 7 == 0 then
			-- a rock pillar down to the floor
			local h = fl - 26
			part({ Name = "Pillar", Size = Vector3.new(14, h, 14), CFrame = cf * CFrame.new(0, -28 - h / 2, 0) * CFrame.Angles(0, 0.4, 0), Color = ROCK_RED[(k % 3) + 1], Material = Enum.Material.Sandstone, Parent = model })
			part({ Name = "PillarFoot", Size = Vector3.new(26, 14, 26), CFrame = cf * CFrame.new(0, -fl + 4, 0) * CFrame.Angles(0, 0.9, 0), Color = col, Material = Enum.Material.Sandstone, Parent = model })
		end
	end

	for _, side in { -1, 1 } do
		barrier(model, cf, side * (deckW / 2 + 0.5), len)
	end

	-- colour: glowing geode pockets in the walls and on the floor, glow-worms on
	-- the roof, luminous fungi along the river banks
	if k % 5 == 2 then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local y = rng:NextNumber(-fl * 0.6, ce * 0.6)
		local at = ccf * CFrame.new(side * (W / 2 - 4), y, rng:NextNumber(-8, 8)) * CFrame.Angles(0, 0, math.rad(side * 75))
		geode(model, at, rng:NextNumber(1.6, 2.6), GEODE[(math.floor(k / 5) % #GEODE) + 1], rng)
	end
	if k % 6 == 3 then
		local x = rng:NextNumber(-W / 2 + 30, W / 2 - 30)
		if math.abs(x - off) > 40 then
			geode(model, ccf * CFrame.new(x, -fl, rng:NextNumber(-8, 8)), rng:NextNumber(2.2, 3.4), GEODE[(k % #GEODE) + 1], rng)
		end
	end
	if k % 3 == 0 then
		glowWorms(model, ccf * CFrame.new(rng:NextNumber(-W / 4, W / 4), ce - 3, 0), W * 0.7, L)
	end
	if k % 4 == 1 then
		local river = math.sin(s0 / 900) * W * 0.18
		local side = rng:NextNumber() < 0.5 and -1 or 1
		fungi(model, ccf * CFrame.new(river + side * (W * 0.15 + rng:NextNumber(6, 22)), -fl + 2, rng:NextNumber(-8, 8)), rng)
	end

	-- landmarks, placed by chunk so every run has them at the same rhythm
	if k % 27 == 5 then
		local x = rng:NextNumber(-W / 2 + 40, W / 2 - 40)
		lightShaft(model, (ccf * CFrame.new(x, ce - 4, 0)).Position, (ccf * CFrame.new(x + rng:NextNumber(-30, 30), -fl, rng:NextNumber(-20, 20))).Position)
	end
	if k % 61 == 30 then
		local side = -wallSide
		waterfall(model, (ccf * CFrame.new(side * (W / 2 - 14), ce, 0)).Position, (ccf * CFrame.new(side * (W / 2 - 30), -fl, 0)).Position, ccf * CFrame.Angles(0, math.rad(90), 0))
	end
	if k % 37 == 12 then
		arch(model, ccf * CFrame.new(0, -fl, 0), fl + 70)
	end
	for _ = 1, 2 do
		if rng:NextNumber() < 0.6 then
			local x = rng:NextNumber(-W / 2 + 20, W / 2 - 20)
			if math.abs(x - off) > 30 then
				stalagmite(model, ccf * CFrame.new(x, -fl, rng:NextNumber(-10, 10)), rng:NextNumber(20, 55), rng)
			end
		end
	end
	if rng:NextNumber() < 0.5 then
		local x = rng:NextNumber(-W / 2 + 20, W / 2 - 20)
		if math.abs(x - off) > 40 then
			prop("RockCluster", ccf * CFrame.new(x, -fl, rng:NextNumber(-10, 10)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), rng:NextNumber(1.5, 3), model, function() end)
		end
	end
	if rng:NextNumber() < 0.35 then
		-- glowstone glinting in the walls: the cavern's own light
		vein(model, ccf, W, ce, rng)
	end
end

-- the rock plug at the end of the dig: the drill smashes through it into the cavern
local function hallPlug(model: Model, s: number)
	local cf = route:sample(s)
	local off = hallOffset(s)
	local fl, ce = hallFloor(s), hallCeil(s)
	T:FillBlock(cf * CFrame.new(-off, (ce - fl) / 2, 6), Vector3.new(HALL.WIDTH + 60, ce + fl + 40, 16), HALL.theme == "Grotto" and Enum.Material.Basalt or Enum.Material.Sandstone)
	local _ = model
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
	elseif isHall(kind) then
		buildHall(model, cf, len, w, s0, k, kind, rng)
		if route.hall and route.hall.s0 >= s0 and route.hall.s0 < s0 + CHUNK_LEN then
			hallPlug(model, route.hall.s0)
		end
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
			-- the open side, over the shaft: a rock lip and a wall the crew can't jump
			local inner = cf.RightVector:Dot(sh.centre - cf.Position) >= 0 and 1 or -1
			part({ Name = "Lip", Size = Vector3.new(3, 2.2, len + 2), CFrame = cf * CFrame.new(inner * (w / 2 - 1.5), 1, 0), Color = Color3.fromRGB(150, 96, 70), Material = Enum.Material.Sandstone, Parent = model })
			barrier(model, cf, inner * (w / 2 + 0.5), len)
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
	local start = route.start
	if start and (start.s0 + start.s1) / 2 >= s0 and (start.s0 + start.s1) / 2 < s0 + CHUNK_LEN then
		-- the Waystation the crew set out from: its camp, without veins or notes
		buildStop(model, { s = (start.s0 + start.s1) / 2, name = start.name, kind = "waystation", start = true })
	end
	for _, h2 in route.hazards do
		if h2.s >= s0 and h2.s < s0 + CHUNK_LEN then
			local hcf = route:sample(h2.s)
			if h2.kind == "Boulder" then
				local bcf = hcf * CFrame.new(h2.offset, 0, 0) * CFrame.Angles(0, h2.s % 6, 0)
				prop("Boulder", bcf, 1.1, model, function()
					part({ Name = "Boulder", Size = Vector3.new(9, 8, 9), CFrame = bcf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0.3, 0, 0.2), Color = Color3.fromRGB(110, 96, 86), Material = Enum.Material.Rock, Parent = model })
				end)
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
		if isHall(kind) then
			local hs = route.hall and route.hall.s0 or s
			if s < hs + 16 then
				-- still in the rock plug at the cavern's edge: bore through it
				local pcf = route:sample(s)
				T:FillBlock(pcf * CFrame.new(0, Config.Tunnel.HEIGHT * 0.35 + 0.5, 0), Vector3.new(Config.Tunnel.WIDTH, Config.Tunnel.HEIGHT * 0.7, 4), Enum.Material.Air)
				what = what or "bore"
			elseif not World.hallOpen then
				-- breakthrough: blow the plug wide open and reveal the cavern
				World.hallOpen = true
				local pcf = route:sample(hs)
				T:FillBall((pcf * CFrame.new(0, 14, 8)).Position, 34, Enum.Material.Air)
				what = "breakthrough"
			end
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
	HALL = r.hallDef or HALL
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
	T:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(194, 120, 86))
	T:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(160, 98, 90))
	T:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(128, 92, 120))
	T:SetMaterialColor(Enum.Material.Salt, Color3.fromRGB(236, 152, 128))
	T:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(96, 150, 70))
	T.WaterColor = Color3.fromRGB(46, 150, 150)
	T.WaterTransparency = 0.6
	T.WaterReflectance = 0.4
	T.WaterWaveSize = 0.08
	T:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(238, 208, 160))
	T:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(70, 60, 70))
	T:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 110, 80))
	if HALL.theme == "Grotto" then
		-- zone 2: indigo stone, violet and teal moss, a luminous teal river
		for mat, rgb in {
			[Enum.Material.Sandstone] = { 96, 82, 132 },
			[Enum.Material.Rock] = { 80, 76, 112 },
			[Enum.Material.Slate] = { 116, 80, 156 },
			[Enum.Material.Basalt] = { 46, 42, 70 },
			[Enum.Material.Limestone] = { 130, 206, 198 },
			[Enum.Material.Salt] = { 196, 146, 234 },
			[Enum.Material.Ground] = { 66, 58, 90 },
			[Enum.Material.Grass] = { 112, 84, 196 },
			[Enum.Material.LeafyGrass] = { 52, 184, 164 },
		} do
			T:SetMaterialColor(mat, Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
		end
		T.WaterColor = Color3.fromRGB(40, 210, 200)
		T.WaterTransparency = 0.4
		VEIN_COLOR = Color3.fromRGB(70, 236, 214) -- teal glowstone in the mushroom roots (GDD 9.2)
	end
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
	-- zone 1's cavern, the Hollow Below: warm red haze, sunlight through the roof
	-- zone 2's cavern: teal haze, violet shadows, glowing everywhere
	Grotto = { amb = Color3.fromRGB(104, 112, 168), fog = Color3.fromRGB(64, 150, 184), density = 0.3, haze = 1.6, tint = Color3.fromRGB(226, 248, 255), sat = 0.22 },
	Hall = { amb = Color3.fromRGB(150, 118, 110), fog = Color3.fromRGB(214, 146, 120), density = 0.28, haze = 1.6, tint = Color3.fromRGB(255, 246, 238), sat = 0.24 },
}

-- glow: 1 = full glow, 0 = Lights Out (the reference's day -> dusk -> night grading)
function World.atmosphere(s: number, glow: number)
	if not atmosphere then
		ensureLighting()
	end
	local kind = route:kindAt(s)
	if kind:sub(1, 4) == "Stop" then
		kind = "Stop"
	elseif isHall(kind) then
		kind = HALL.theme == "Grotto" and "Grotto" or "Hall"
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
	grade.Saturation = grade.Saturation + ((sec.sat or 0.12) - grade.Saturation) * 0.08
	grade.Contrast = 0.14
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
		prop("RockCluster", base, 0.6, model, function()
			part({ Name = "Outcrop", Size = Vector3.new(7, 3, 6), CFrame = base * CFrame.new(0, 1, 0), Color = CLIFF[i % 4 + 1], Material = Enum.Material.Sandstone, Parent = model })
		end)
		local v = glowVein(model, base * CFrame.new(0, 2, 0), rng, 1, 18)
		v:SetAttribute("HP", 12)
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
