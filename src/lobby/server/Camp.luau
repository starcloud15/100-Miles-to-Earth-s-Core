--[[
	Topside Camp's world (GDD 14.1), backdrop A of docs/look-proposal.md:
	the expedition's camp on a sunny red-rock plateau at the rim of the
	giant sinkhole. A player spawns facing the arc of glass party bays; right
	behind them the hole drops away in terraced benches and glows amber from
	below. A steel headframe spans the hole and lowers a drill rig on cables.
	Around the camp: tents with flags, string lights and bunting, crates of
	glowstone, a rope bridge and an overlook at the rim, cube-pine woods and
	faceted mesas on the horizon, all under warm haze.

	The functional pieces (bays, boards, Free Revive, Classes hut) are built
	first, with the names other scripts use; the scenery follows in chunks.
	Everything is plain Parts, WedgeParts and CornerWedgeParts: rich from
	layered silhouettes, colour, props and light, not from fine detail.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Camp = {}

local FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
local WOOD = Color3.fromRGB(124, 84, 52)
local WOOD_DARK = Color3.fromRGB(86, 56, 34)

-- the palette: sun-baked red rock, saturated greens, yellow steel, amber glow
local DUST = Color3.fromRGB(214, 126, 72)
local DUST_LIGHT = Color3.fromRGB(226, 166, 112)
local GRASS = Color3.fromRGB(104, 170, 64)
local ROCK = {
	Color3.fromRGB(222, 108, 52), -- orange
	Color3.fromRGB(196, 74, 44), -- red
	Color3.fromRGB(236, 150, 84), -- tan
	Color3.fromRGB(170, 60, 38), -- deep red
	Color3.fromRGB(136, 48, 34), -- oxblood
}
local SHAFT = {
	Color3.fromRGB(150, 66, 46),
	Color3.fromRGB(122, 54, 40),
	Color3.fromRGB(104, 50, 38),
	Color3.fromRGB(90, 46, 36),
	Color3.fromRGB(80, 42, 34),
}
local PINES = { Color3.fromRGB(46, 140, 70), Color3.fromRGB(62, 160, 64), Color3.fromRGB(36, 118, 66), Color3.fromRGB(88, 170, 58) }
local TRUNK = Color3.fromRGB(110, 70, 42)
local STEEL = Color3.fromRGB(244, 178, 34)
local STEEL_DARK = Color3.fromRGB(70, 66, 72)
local RIG_RED = Color3.fromRGB(212, 58, 42)
local GLOW = Color3.fromRGB(255, 168, 46)
local GLOW_HOT = Color3.fromRGB(255, 120, 24)
local CLOTH = {
	Color3.fromRGB(236, 96, 40),
	Color3.fromRGB(40, 130, 220),
	Color3.fromRGB(230, 200, 60),
	Color3.fromRGB(40, 170, 150),
	Color3.fromRGB(200, 50, 70),
	Color3.fromRGB(150, 80, 200),
}
local BULBS = { Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 120, 60), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 240, 200), Color3.fromRGB(140, 255, 120) }

local STONE = Enum.Material.SmoothPlastic -- flat, saturated, low-poly rock
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local PLANKS = Enum.Material.WoodPlanks
local TAU = math.pi * 2

local folder: Instance -- where part() and blk() put new parts
local rng = Random.new(2026)

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Parent = p.Parent or folder
	return p
end

-- the scenery's workhorse: an anchored block (or wedge) with no fuss
local function blk(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, cls: string?): BasePart
	local p = Instance.new(cls or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or SMOOTH
	p.Parent = folder
	return p
end

-- a glowing part: neon, no shadow, no collision
local function glow(size: Vector3, cf: CFrame, color: Color3, cls: string?): BasePart
	local p = blk(size, cf, color, NEON, cls)
	p.CastShadow = false
	p.CanCollide = false
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

-- a square bar from a to b
local function beam(a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?): BasePart
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
	local p = blk(Vector3.new(t, t, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, mat or METAL)
	return p
end

local function shade(c: Color3, amount: number): Color3
	return amount >= 0 and c:Lerp(Color3.new(1, 1, 1), amount) or c:Lerp(Color3.new(0, 0, 0), -amount)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		if k ~= "Stroke" then
			(l :: any)[k] = v
		end
	end
	local s = Instance.new("UIStroke")
	s.Thickness = props.Stroke or 3
	s.Parent = l
	l.Parent = parent
	return l
end

-- a wooden board on two posts with a little roof, facing `look`
local function signFrame(name: string, pos: Vector3, look: Vector3, w: number, h: number): BasePart
	local cf = CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = folder
	for _, side in { -1, 1 } do
		part({ Name = "Post", Size = Vector3.new(1.4, h + 4, 1.4), CFrame = cf * CFrame.new(side * (w / 2 + 0.7), (h + 4) / 2, 0.6), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = model })
	end
	part({ Name = "Back", Size = Vector3.new(w + 1, h + 1, 0.8), CFrame = cf * CFrame.new(0, h / 2 + 3, 0.8), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Name = "Roof", Size = Vector3.new(w + 5, 0.8, 3.4), CFrame = cf * CFrame.new(0, h + 4.2, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(60, 40, 26), Material = Enum.Material.Wood, Parent = model })
	local screen = part({ Name = "Screen", Size = Vector3.new(w, h, 0.2), CFrame = cf * CFrame.new(0, h / 2 + 3, 0.3), Color = Color3.fromRGB(70, 46, 30), Material = Enum.Material.SmoothPlastic, Parent = model })
	return screen
end

---------------------------------------------------------------------------
-- scenery kit
---------------------------------------------------------------------------

-- a faceted boulder: a tilted block, a wedge cap and a corner-wedge chip
local function rock(pos: Vector3, s: number, color: Color3)
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	blk(Vector3.new(s * 1.6, s, s * 1.3), base * CFrame.new(0, s * 0.25, 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), color, STONE)
	blk(Vector3.new(s * 1.3, s * 0.9, s * 1.1), base * CFrame.new(-s * 0.1, s * 0.85, -s * 0.1) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.25, 0.25)), shade(color, 0.12), STONE, "WedgePart")
	blk(Vector3.new(s * 0.9, s * 0.8, s * 0.9), base * CFrame.new(s * 0.75, s * 0.3, s * 0.45) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), shade(color, -0.12), STONE, "CornerWedgePart")
end

-- a cube pine: a trunk and three stacked, twisted cubes
local function pine(pos: Vector3, s: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	local g = pick(PINES)
	blk(Vector3.new(1.4, 7, 1.4) * s, cf * CFrame.new(0, 3.5 * s, 0), TRUNK, Enum.Material.Wood)
	blk(Vector3.new(9, 5.5, 9) * s, cf * CFrame.new(0, 7.5 * s, 0), g, SMOOTH)
	blk(Vector3.new(6.6, 5, 6.6) * s, cf * CFrame.new(0, 12 * s, 0) * CFrame.Angles(0, math.pi / 4, 0), shade(g, 0.08), SMOOTH)
	blk(Vector3.new(3.8, 4, 3.8) * s, cf * CFrame.new(0, 15.8 * s, 0), shade(g, 0.16), SMOOTH)
end

-- a round cube tree like the reference's: one big cube canopy and a bump
local function cubeTree(pos: Vector3, s: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi / 2), 0)
	local g = pick(PINES)
	blk(Vector3.new(1.8, 10, 1.8) * s, cf * CFrame.new(0, 5 * s, 0), TRUNK, Enum.Material.Wood)
	blk(Vector3.new(11, 9, 11) * s, cf * CFrame.new(0, 13 * s, 0), g, SMOOTH)
	blk(Vector3.new(6, 5, 6) * s, cf * CFrame.new(2 * s, 17.5 * s, -1.5 * s) * CFrame.Angles(0, 0.4, 0), shade(g, 0.12), SMOOTH)
end

local function tree(pos: Vector3, s: number)
	if rng:NextNumber() < 0.7 then
		pine(pos, s)
	else
		cubeTree(pos, s)
	end
end

local function bush(pos: Vector3, s: number)
	local g = pick(PINES)
	blk(Vector3.new(3.2, 2.4, 3.2) * s, CFrame.new(pos + Vector3.new(0, 1 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), shade(g, 0.05), SMOOTH)
	blk(Vector3.new(2.2, 2, 2.2) * s, CFrame.new(pos + Vector3.new(1.4 * s, 0.8 * s, 0.6 * s)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), g, SMOOTH)
end

-- a faceted mesa: a banded core, talus wedges round its foot, corner wedges
-- to close it, a cap, a few chunks and pines on top
local function mesa(pos: Vector3, w: number, d: number, h: number, yaw: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local base = pick(ROCK)
	blk(Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), base, STONE)
	blk(Vector3.new(w + 1.5, h * 0.12, d + 1.5), cf * CFrame.new(0, h * 0.58, 0), ROCK[1], STONE)
	blk(Vector3.new(w + 1, h * 0.08, d + 1), cf * CFrame.new(0, h * 0.32, 0), ROCK[4], STONE)
	blk(Vector3.new(w + 3, h * 0.1, d + 3), cf * CFrame.new(0, h * 0.95, 0), ROCK[3], STONE)
	-- talus: wedges sloping away from each face
	local th, td = h * 0.42, h * 0.38
	for _, side in { { Vector3.xAxis, d }, { -Vector3.xAxis, d }, { Vector3.zAxis, w }, { -Vector3.zAxis, w } } do
		local n: Vector3, len: number = side[1], side[2]
		local half = (n.X ~= 0) and w / 2 or d / 2
		local p = n * (half + td / 2 - 0.5) + Vector3.new(0, th / 2, 0)
		blk(Vector3.new(len + 0.5, th, td), cf * CFrame.lookAt(p, p + n), shade(base, -0.06), STONE, "WedgePart")
	end
	-- corners: a corner wedge whose peak sits against the core's corner
	local r0 = CFrame.fromMatrix(Vector3.zero, -Vector3.xAxis, Vector3.yAxis)
	local corners = { { 1, -1 }, { -1, -1 }, { -1, 1 }, { 1, 1 } }
	for k = 0, 3 do
		local c = corners[k + 1]
		local rot = CFrame.Angles(0, k * math.pi / 2, 0) * r0
		local p = Vector3.new(c[1] * (w / 2 + td / 2 - 0.5), th / 2, c[2] * (d / 2 + td / 2 - 0.5))
		blk(Vector3.new(td, th, td), cf * CFrame.new(p) * rot, shade(base, -0.06), STONE, "CornerWedgePart")
	end
	-- a stepped top and chunks
	if rng:NextNumber() < 0.5 then
		local h2 = h * rng:NextNumber(0.15, 0.3)
		blk(Vector3.new(w * 0.55, h2, d * 0.6), cf * CFrame.new(w * 0.15, h + h2 / 2, -d * 0.1) * CFrame.Angles(0, 0.3, 0), ROCK[1], STONE)
	end
	for _ = 1, 2 do
		local s = math.min(w, d) * rng:NextNumber(0.15, 0.25)
		blk(Vector3.new(s * 1.5, s, s), cf * CFrame.new(rng:NextNumber(-w, w) * 0.3, h + s * 0.3, rng:NextNumber(-d, d) * 0.3) * CFrame.Angles(0, rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)), ROCK[3], STONE, "WedgePart")
	end
	for _ = 1, rng:NextInteger(1, 3) do
		pine((cf * CFrame.new(rng:NextNumber(-w, w) * 0.4, h, rng:NextNumber(-d, d) * 0.4)).Position, rng:NextNumber(1.4, 2.2))
	end
end

-- a sagging line from a to b: returns the point at t in [0, 1]
local function sagAt(a: Vector3, b: Vector3, sag: number, t: number): Vector3
	return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
end

local function sagLine(a: Vector3, b: Vector3, sag: number, segs: number, t: number, color: Color3)
	for i = 1, segs do
		beam(sagAt(a, b, sag, (i - 1) / segs), sagAt(a, b, sag, i / segs), t, color, SMOOTH)
	end
end

-- string lights between two points
local function stringLights(a: Vector3, b: Vector3, sag: number)
	local n = math.max(4, math.floor((b - a).Magnitude / 3.2))
	sagLine(a, b, sag, 4, 0.12, Color3.fromRGB(40, 32, 28))
	for i = 1, n - 1 do
		local p = sagAt(a, b, sag, i / n)
		local bulb = glow(Vector3.new(0.7, 0.7, 0.7), CFrame.new(p - Vector3.new(0, 0.45, 0)), BULBS[i % #BULBS + 1])
		bulb.Shape = Enum.PartType.Ball
	end
end

-- bunting: pennants hanging from a sagging rope
local function bunting(a: Vector3, b: Vector3, sag: number)
	sagLine(a, b, sag, 3, 0.14, Color3.fromRGB(230, 220, 200))
	local n = math.max(3, math.floor((b - a).Magnitude / 2.6))
	local dir = (b - a) * Vector3.new(1, 0, 1)
	for i = 1, n - 1 do
		local p = sagAt(a, b, sag, i / n)
		local f = blk(Vector3.new(0.1, 1.5, 1.3), CFrame.lookAt(p, p + dir) * CFrame.new(0, -0.75, 0) * CFrame.Angles(math.pi, 0, 0), CLOTH[i % #CLOTH + 1], Enum.Material.Fabric, "WedgePart")
		f.CanCollide = false
		f.CastShadow = false
	end
end

-- a pole with a pennant flag
local function flagPole(pos: Vector3, h: number, color: Color3, yaw: number)
	blk(Vector3.new(0.4, h, 0.4), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(230, 230, 230), METAL)
	local f = blk(Vector3.new(0.15, 2.4, 4), CFrame.new(pos + Vector3.new(0, h - 1.4, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -2.1) * CFrame.Angles(0, math.pi, 0), color, Enum.Material.Fabric, "WedgePart")
	f.CanCollide = false
end

-- an A-frame tent: two wedges back to back, a door, a ridge pole and a flag
local function tent(pos: Vector3, yaw: number, color: Color3, len: number, w: number, h: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	blk(Vector3.new(len, h, w / 2), cf * CFrame.new(0, h / 2, -w / 4), color, Enum.Material.Fabric, "WedgePart")
	blk(Vector3.new(len, h, w / 2), cf * CFrame.new(0, h / 2, w / 4) * CFrame.Angles(0, math.pi, 0), shade(color, -0.12), Enum.Material.Fabric, "WedgePart")
	blk(Vector3.new(0.2, h * 0.5, w * 0.24), cf * CFrame.new(len / 2 + 0.05, h * 0.25, 0), Color3.fromRGB(50, 34, 26), SMOOTH)
	blk(Vector3.new(len + 1.2, 0.35, 0.35), cf * CFrame.new(0, h + 0.1, 0), WOOD_DARK, Enum.Material.Wood)
	for _, x in { -1, 1 } do
		blk(Vector3.new(0.35, h + 0.3, 0.35), cf * CFrame.new(x * (len / 2 + 0.4), h / 2, 0), WOOD_DARK, Enum.Material.Wood)
	end
	flagPole((cf * CFrame.new(len / 2 + 0.4, h, 0)).Position, 4.5, pick(CLOTH), yaw)
end

-- a striped awning on four poles over a table
local function canopy(pos: Vector3, yaw: number, a: Color3, b: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	for _, x in { -6, 6 } do
		for _, z in { -4.5, 4.5 } do
			blk(Vector3.new(0.5, 9, 0.5), cf * CFrame.new(x, 4.5, z), WOOD_DARK, Enum.Material.Wood)
		end
	end
	for i = 0, 5 do
		blk(Vector3.new(2.2, 0.3, 11), cf * CFrame.new(-5.5 + i * 2.2, 9.2, 0), i % 2 == 0 and a or b, Enum.Material.Fabric)
	end
	for _, z in { -5.6, 5.6 } do
		for i = 0, 5 do
			local f = blk(Vector3.new(2.2, 1.2, 0.15), cf * CFrame.new(-5.5 + i * 2.2, 8.5, z), i % 2 == 0 and a or b, Enum.Material.Fabric)
			f.CanCollide = false
		end
	end
	blk(Vector3.new(8, 0.5, 3.6), cf * CFrame.new(0, 3, 0), WOOD, PLANKS)
	for _, x in { -3.4, 3.4 } do
		blk(Vector3.new(0.6, 3, 3), cf * CFrame.new(x, 1.5, 0), WOOD_DARK, Enum.Material.Wood)
	end
end

-- a crate of glowstone: amber chunks heaped in an open wooden box
local function glowCrate(cf: CFrame, s: number)
	blk(Vector3.new(4, 3, 4) * s, cf * CFrame.new(0, 1.5 * s, 0), WOOD, PLANKS)
	blk(Vector3.new(4.3, 0.5, 4.3) * s, cf * CFrame.new(0, 2.8 * s, 0), WOOD_DARK, Enum.Material.Wood)
	blk(Vector3.new(4.3, 0.5, 4.3) * s, cf * CFrame.new(0, 0.3 * s, 0), WOOD_DARK, Enum.Material.Wood)
	local first
	for i = 1, 4 do
		local c = glow(Vector3.new(1.5, 1.5, 1.5) * s * rng:NextNumber(0.7, 1.15), cf * CFrame.new(rng:NextNumber(-1.1, 1.1) * s, (3 + rng:NextNumber(0, 0.6)) * s, rng:NextNumber(-1.1, 1.1) * s) * CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), 0), i % 2 == 0 and GLOW or GLOW_HOT)
		first = first or c
	end
	light(first, GLOW, 14 * s, 1.6)
end

-- a lantern post: a post with an arm and a hanging glowing lantern
local function lanternPost(pos: Vector3, yaw: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	blk(Vector3.new(0.8, 10, 0.8), cf * CFrame.new(0, 5, 0), WOOD_DARK, Enum.Material.Wood)
	blk(Vector3.new(0.5, 0.5, 3), cf * CFrame.new(0, 9.6, -1.2), WOOD_DARK, Enum.Material.Wood)
	blk(Vector3.new(1.4, 0.3, 1.4), cf * CFrame.new(0, 8.9, -2.3), Color3.fromRGB(40, 36, 34), METAL)
	local l = glow(Vector3.new(1, 1.4, 1), cf * CFrame.new(0, 8, -2.3), Color3.fromRGB(255, 196, 90))
	light(l, Color3.fromRGB(255, 190, 110), 18, 1.5)
end

-- a drill rig: tracked body, yellow cab, drill stack and a pyramid bit.
-- Returns the root part (the body) and every other part, unanchored and
-- welded to it, so moving the root moves the whole rig.
local function rig(cf: CFrame, hanging: boolean): (BasePart, { BasePart })
	local parts = {}
	local function add(p: BasePart): BasePart
		table.insert(parts, p)
		return p
	end
	local body = blk(Vector3.new(18, 7, 14), cf, RIG_RED, METAL)
	add(blk(Vector3.new(18.6, 0.8, 14.6), cf * CFrame.new(0, 3.9, 0), STEEL_DARK, Enum.Material.DiamondPlate))
	add(blk(Vector3.new(18.6, 1, 14.6), cf * CFrame.new(0, -1, 0), STEEL, METAL))
	for _, z in { -8.6, 8.6 } do
		add(blk(Vector3.new(21, 4.4, 3.4), cf * CFrame.new(0, -2.3, z), Color3.fromRGB(46, 42, 44), METAL))
		add(blk(Vector3.new(19, 0.5, 3.6), cf * CFrame.new(0, 0.1, z), Color3.fromRGB(90, 86, 90), Enum.Material.DiamondPlate))
		for _, x in { -7.5, 0, 7.5 } do
			local wheel = add(blk(Vector3.new(3.6, 3.6, 3.6), cf * CFrame.new(x, -2.3, z * 1.01) * CFrame.Angles(0, math.pi / 2, 0), STEEL, METAL))
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	-- the cab, facing the rig's front (-Z)
	add(blk(Vector3.new(8, 5.4, 6), cf * CFrame.new(-4, 7, -3.5), STEEL, METAL))
	add(blk(Vector3.new(8.6, 0.6, 6.6), cf * CFrame.new(-4, 10, -3.5), STEEL_DARK, METAL))
	add(glow(Vector3.new(6.6, 2.4, 0.3), cf * CFrame.new(-4, 7.8, -6.55), Color3.fromRGB(110, 210, 255)))
	add(glow(Vector3.new(0.3, 2.2, 4), cf * CFrame.new(-8.05, 7.8, -3.5), Color3.fromRGB(110, 210, 255)))
	local beacon = add(glow(Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(-4, 10.9, -3.5), GLOW_HOT))
	beacon.Shape = Enum.PartType.Ball
	-- tank, stacks, rails
	local tank = add(blk(Vector3.new(7, 3.6, 3.6), cf * CFrame.new(4.5, 6.1, 3), Color3.fromRGB(220, 220, 214), METAL))
	tank.Shape = Enum.PartType.Cylinder
	for _, x in { 6, 7.8 } do
		local stack = add(blk(Vector3.new(6, 1.1, 1.1), cf * CFrame.new(x, 7.3, -4.5) * CFrame.Angles(0, 0, math.pi / 2), STEEL_DARK, METAL))
		stack.Shape = Enum.PartType.Cylinder
	end
	for _, z in { -7, 7 } do
		add(blk(Vector3.new(18, 0.3, 0.3), cf * CFrame.new(0, 5.6, z), STEEL, METAL))
	end
	-- headlights
	for _, x in { -6.5, 6.5 } do
		local h = add(glow(Vector3.new(1.8, 1.1, 0.3), cf * CFrame.new(x, 1.6, -7.15), Color3.fromRGB(255, 244, 190)))
		if x > 0 then
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Range = 40
			spot.Angle = 70
			spot.Brightness = 2
			spot.Color = Color3.fromRGB(255, 236, 190)
			spot.Parent = h
		end
	end
	if hanging then
		-- the drill: collar, two stages and a faceted pyramid bit
		for i, st in { { 11, 2, -4.6 }, { 8.5, 3, -7.1 }, { 6.5, 3, -10.1 } } do
			local c = add(blk(Vector3.new(st[2], st[1], st[1]), cf * CFrame.new(0, st[3], 0) * CFrame.Angles(0, 0, math.pi / 2), i == 1 and STEEL or Color3.fromRGB(170, 172, 180), METAL))
			c.Shape = Enum.PartType.Cylinder
		end
		-- four corner wedges, peaks meeting in the middle, flipped to point down
		local tip = cf * CFrame.new(0, -14.6, 0) * CFrame.Angles(math.pi, 0, 0)
		for _, q in { { -1, 1, 0 }, { 1, 1, math.pi / 2 }, { 1, -1, math.pi }, { -1, -1, -math.pi / 2 } } do
			add(blk(Vector3.new(3, 6, 3), tip * CFrame.new(q[1] * 1.5, 0, q[2] * 1.5) * CFrame.Angles(0, q[3], 0), Color3.fromRGB(150, 152, 162), METAL, "CornerWedgePart"))
		end
		for k = 0, 2 do
			add(glow(Vector3.new(0.4, 2.6, 6.8), cf * CFrame.new(0, -10.1, 0) * CFrame.Angles(0, k * math.pi / 3, 0.5), GLOW))
		end
	end
	for _, p in parts do
		p.Anchored = false
		p.CanCollide = not hanging
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
	end
	return body, parts
end

---------------------------------------------------------------------------
-- lighting: a hot, hazy afternoon on the plateau
---------------------------------------------------------------------------

local function effect(class: string, name: string, props: { [string]: any })
	local old = Lighting:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local e = Instance.new(class)
	e.Name = name
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = Lighting
end

local function setupLighting()
	local props = {
		ClockTime = 15.6,
		GeographicLatitude = 24,
		Brightness = 3.2,
		Ambient = Color3.fromRGB(104, 80, 70),
		OutdoorAmbient = Color3.fromRGB(150, 116, 98),
		ColorShift_Top = Color3.fromRGB(255, 220, 178),
		ColorShift_Bottom = Color3.fromRGB(120, 60, 30),
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.35,
		ExposureCompensation = 0.1,
		GlobalShadows = true,
		FogEnd = 100000,
	}
	for k, v in props do
		pcall(function()
			(Lighting :: any)[k] = v
		end)
	end
	effect("Atmosphere", "Atmosphere", { Density = 0.3, Offset = 0.15, Color = Color3.fromRGB(255, 212, 160), Decay = Color3.fromRGB(236, 146, 90), Glare = 0.4, Haze = 1.1 })
	effect("ColorCorrectionEffect", "ColorCorrection", { Brightness = 0.02, Contrast = 0.12, Saturation = 0.25, TintColor = Color3.fromRGB(255, 240, 222) })
	effect("BloomEffect", "Bloom", { Intensity = 0.35, Size = 24, Threshold = 1.6 })
	effect("SunRaysEffect", "SunRays", { Intensity = 0.1, Spread = 0.6 })
end

---------------------------------------------------------------------------
-- the scenery, in chunks
---------------------------------------------------------------------------

-- the sinkhole sits in a shallow bowl: a sloping apron runs down from the
-- plateau to the lip, so from camp you look down into the hole
local R_RIM = 95 -- the hole's top radius
local APRON = 40 -- the bowl's width, lip to plateau
local R_OUT = R_RIM + APRON
local RIM_Y = -20 -- the lip's height below the plateau
local BENCH_H, BENCH_STEP, BENCHES = 10, 9, 5
local SHAFT_R, SHAFT_H, SHAFTS = 55, 30, 5
local SHAFT_TOP = RIM_Y - BENCH_H * BENCHES -- -70
local HIGH_LEVELS = 8 -- benches climbing the far side
local PIT_FLOOR = SHAFT_TOP - SHAFT_H * SHAFTS -- -220

-- is p inside the high wall that climbs the hole's far side?
local function inRidge(p: Vector3, H: Vector3): boolean
	return p.Z < H.Z and (p - H).Magnitude < 250
end

-- the ground's height at distance r from the hole's centre
local function apronY(r: number): number
	return RIM_Y * math.clamp(1 - (r - R_RIM) / APRON, 0, 1)
end

local function buildGround(O: Vector3, H: Vector3)
	-- the plateau: four slabs around a square hole, the rim ring fills the rest
	local top = -0.05
	local sq = R_OUT + 1
	local x0, x1, z0, z1 = O.X - 1000, O.X + 1000, O.Z - 1100, O.Z + 900
	local function slab(ax: number, bx: number, az: number, bz: number)
		blk(Vector3.new(bx - ax, 4, bz - az), CFrame.new((ax + bx) / 2, top - 2, (az + bz) / 2), DUST, Enum.Material.Sand)
	end
	slab(x0, x1, z0, H.Z - sq)
	slab(x0, x1, H.Z + sq, z1)
	slab(x0, H.X - sq, H.Z - sq, H.Z + sq)
	slab(H.X + sq, x1, H.Z - sq, H.Z + sq)
	-- a flat ring closes the square's corners, the apron slopes down inside it
	local N = 28
	for k = 0, N - 1 do
		local a = (k + 0.5) / N * TAU
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local t = 62
		local c = H + dir * (R_OUT + t / 2) + Vector3.new(0, -2, 0)
		blk(Vector3.new(2 * (R_OUT + t) * math.tan(math.pi / N) * 1.04, 4, t), CFrame.lookAt(c, c - dir), DUST, Enum.Material.Sand)
		local w = H + dir * (R_RIM + APRON / 2 - 1) + Vector3.new(0, RIM_Y / 2, 0)
		blk(Vector3.new(2 * R_OUT * math.tan(math.pi / N) * 1.05, -RIM_Y, APRON + 2), CFrame.lookAt(w, w - dir), shade(DUST, rng:NextNumber(-0.06, 0.02)), Enum.Material.Sand, "WedgePart")
	end
	-- the camp's grass clearing round spawn, in overlapping faceted patches
	for i, g in { { 0, 20, 120, 84, 0 }, { -40, 0, 70, 90, 0.5 }, { 40, 0, 70, 90, -0.5 }, { 0, 55, 90, 60, 0.8 }, { -70, 30, 50, 60, 0.3 }, { 70, 30, 50, 60, -0.3 }, { 0, -40, 110, 46, 0 } } do
		blk(Vector3.new(g[3], 0.2, g[4]), CFrame.new(O + Vector3.new(g[1], -0.05 + i * 0.008, g[2])) * CFrame.Angles(0, g[5], 0), shade(GRASS, (i % 3) * 0.03), Enum.Material.Grass)
	end
	-- grass tufts and dusty patches across the plateau
	for _ = 1, 40 do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(90, 420)
		local p = O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if (p - H).Magnitude > R_OUT + 20 then
			blk(Vector3.new(rng:NextNumber(14, 40), 0.2, rng:NextNumber(10, 30)), CFrame.new(p + Vector3.new(0, rng:NextNumber(-0.04, 0), 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), shade(GRASS, rng:NextNumber(-0.1, 0.05)), Enum.Material.Grass)
		end
	end
	-- dusty tracks: spawn to the rim, and out to the tents on each side
	blk(Vector3.new(9, 0.2, 80), CFrame.new(O + Vector3.new(0, 0.02, -30)), DUST_LIGHT, Enum.Material.Ground)
	blk(Vector3.new(8, 0.2, 70), CFrame.new(O + Vector3.new(-60, 0.03, -18)) * CFrame.Angles(0, math.rad(70), 0), DUST_LIGHT, Enum.Material.Ground)
	blk(Vector3.new(8, 0.2, 70), CFrame.new(O + Vector3.new(60, 0.03, -18)) * CFrame.Angles(0, math.rad(-70), 0), DUST_LIGHT, Enum.Material.Ground)
end

local function buildPit(H: Vector3)
	-- terraced benches stepping in, then a sheer shaft: rings of blocks whose
	-- inner faces make a faceted 28-gon
	local N = 28
	local layers = {}
	for i = 0, BENCHES - 1 do
		table.insert(layers, { y = RIM_Y - BENCH_H * i, h = BENCH_H, r = R_RIM - BENCH_STEP * i, t = i == 0 and 54 or 30, color = ROCK[(i % #ROCK) + 1] })
	end
	for j = 0, SHAFTS - 1 do
		table.insert(layers, { y = SHAFT_TOP - SHAFT_H * j, h = SHAFT_H, r = SHAFT_R, t = 26, color = SHAFT[j + 1] })
	end
	for li, L in layers do
		local off = (li % 2) * 0.5
		local n = L.r == SHAFT_R and 20 or N -- the shaft is seldom seen: fewer facets
		for k = 0, n - 1 do
			local a = (k + off) / n * TAU
			local r = L.r + rng:NextNumber(-1.2, 1.2)
			local w = 2 * (r + L.t) * math.tan(math.pi / n) * 1.04
			local c = H + Vector3.new(math.cos(a) * (r + L.t / 2), L.y - L.h / 2, math.sin(a) * (r + L.t / 2))
			blk(Vector3.new(w, L.h, L.t), CFrame.lookAt(c, Vector3.new(H.X, c.Y, H.Z)), shade(L.color, rng:NextNumber(-0.05, 0.05)), STONE)
		end
	end
	-- across the hole the ground climbs in benches to a high wall, like an
	-- open-pit mine's face, so the camp sees terraces glowing over the hole
	for k = 0, N - 1 do
		local a = (k + 0.5) / N * TAU
		local far = math.clamp(-math.sin(a), 0, 1) -- 1 straight across from camp
		local levels = math.floor(HIGH_LEVELS * far ^ 0.6 + 0.3)
		for m = 1, levels do
			local r = R_RIM + BENCH_STEP * m * 1.3 + rng:NextNumber(-1.2, 1.2)
			local t = 46
			local yTop = RIM_Y + BENCH_H * m
			local yBot = RIM_Y - 2
			local w = 2 * (r + t) * math.tan(math.pi / N) * 1.04
			local c = H + Vector3.new(math.cos(a) * (r + t / 2), (yTop + yBot) / 2, math.sin(a) * (r + t / 2))
			blk(Vector3.new(w, yTop - yBot, t), CFrame.lookAt(c, Vector3.new(H.X, c.Y, H.Z)), shade(ROCK[(m + 1) % #ROCK + 1], rng:NextNumber(-0.05, 0.05)), STONE)
			-- glowstone in the face, a pine or two on the ledge
			local face = H + Vector3.new(math.cos(a), 0, math.sin(a)) * (r - 0.3)
			if rng:NextNumber() < 0.8 then
				local p = face + Vector3.new(0, yTop - rng:NextNumber(3.5, BENCH_H - 3), 0)
				glow(Vector3.new(rng:NextNumber(1.4, 3), rng:NextNumber(5, 9), 1.4), CFrame.lookAt(p, Vector3.new(H.X, p.Y, H.Z)) * CFrame.Angles(0, 0, rng:NextNumber(-1.2, 1.2)), rng:NextNumber() < 0.5 and GLOW or GLOW_HOT, "WedgePart")
			end
			if m == levels and m >= 3 then
				for _ = 1, 2 do
					local rr = r + rng:NextNumber(6, t - 6)
					local aa = a + rng:NextNumber(-0.08, 0.08)
					tree(H + Vector3.new(math.cos(aa) * rr, yTop, math.sin(aa) * rr), rng:NextNumber(1.1, 1.7))
				end
			elseif rng:NextNumber() < 0.3 then
				pine(H + Vector3.new(math.cos(a) * (r + 4), yTop, math.sin(a) * (r + 4)), rng:NextNumber(0.7, 1))
			end
		end
	end
	-- the rim lip: faceted boulders round the edge
	for k = 0, 33 do
		local a = (k + rng:NextNumber(-0.3, 0.3)) / 34 * TAU
		local p = H + Vector3.new(math.cos(a), 0, math.sin(a)) * (R_RIM + rng:NextNumber(2, 6)) + Vector3.new(0, RIM_Y, 0)
		-- leave the near side open: that's the view from camp
		if math.sin(a) < 0.55 then
			rock(p, rng:NextNumber(2.5, 5), pick(ROCK))
		end
	end
	-- glowstone veins in the walls, more of them deeper down
	for _ = 1, 45 do
		local li = rng:NextInteger(2, #layers)
		local L = layers[li]
		local a = rng:NextNumber(0, TAU)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local y = L.y - rng:NextNumber(0.2, 0.8) * L.h
		local p = H + dir * (L.r - 0.3) + Vector3.new(0, y, 0)
		glow(Vector3.new(rng:NextNumber(0.8, 2), rng:NextNumber(4, 10), 1.2), CFrame.lookAt(p, Vector3.new(H.X, p.Y, H.Z)) * CFrame.Angles(0, 0, rng:NextNumber(-1.2, 1.2)), rng:NextNumber() < 0.5 and GLOW or GLOW_HOT, "WedgePart")
	end
	-- glowstone clusters on the bench ledges
	for _ = 1, 18 do
		local i = rng:NextInteger(1, BENCHES - 1)
		local a = rng:NextNumber(0, TAU)
		local r = R_RIM - BENCH_STEP * i + rng:NextNumber(1.5, 6)
		local p = H + Vector3.new(math.cos(a) * r, RIM_Y - BENCH_H * i, math.sin(a) * r)
		for _ = 1, 3 do
			glow(Vector3.new(1, 2.4, 1) * rng:NextNumber(0.7, 1.4), CFrame.new(p + Vector3.new(rng:NextNumber(-1.2, 1.2), 0.6, rng:NextNumber(-1.2, 1.2))) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, TAU), rng:NextNumber(-0.5, 0.5)), GLOW)
		end
	end
	-- the glow from below: a hot floor, layers of amber haze and lights
	local floor = glow(Vector3.new(2, SHAFT_R * 2 + 4, SHAFT_R * 2 + 4), CFrame.new(H + Vector3.new(0, PIT_FLOOR - 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), GLOW_HOT)
	floor.Shape = Enum.PartType.Cylinder
	floor.CanCollide = true
	for _, h in { { PIT_FLOOR + 35, 0.3 }, { PIT_FLOOR + 75, 0.55 }, { SHAFT_TOP - 38, 0.7 }, { SHAFT_TOP - 6, 0.82 } } do
		local d = glow(Vector3.new(1, SHAFT_R * 2 - 2, SHAFT_R * 2 - 2), CFrame.new(H + Vector3.new(0, h[1], 0)) * CFrame.Angles(0, 0, math.pi / 2), GLOW)
		d.Shape = Enum.PartType.Cylinder
		d.Transparency = h[2]
		d.CanQuery = false
		d.CanTouch = false
	end
	-- soft shafts of glow rising out of the hole, fading upward: camera-facing
	-- beams, so they read as light from any angle, even from camp
	local anchor = blk(Vector3.new(1, 1, 1), CFrame.new(H + Vector3.new(0, SHAFT_TOP, 0)), GLOW)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	for _, b in { { 120, 0.8, 110 }, { 96, 0.76, 130 }, { 72, 0.72, 150 }, { 50, 0.68, 165 }, { 28, 0.64, 180 } } do
		local a0 = Instance.new("Attachment")
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, b[3], 0)
		a1.Parent = anchor
		local beamGlow = Instance.new("Beam")
		beamGlow.Attachment0 = a0
		beamGlow.Attachment1 = a1
		beamGlow.FaceCamera = true
		beamGlow.Width0 = b[1]
		beamGlow.Width1 = b[1] * 0.8
		beamGlow.Segments = 1
		beamGlow.LightEmission = 1
		beamGlow.LightInfluence = 0
		beamGlow.Brightness = 2
		beamGlow.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 140, 40))
		beamGlow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, b[2]), NumberSequenceKeypoint.new(0.45, (1 + b[2]) / 2 + 0.06), NumberSequenceKeypoint.new(1, 1) })
		beamGlow.Parent = anchor
	end
	for _, y in { RIM_Y - 12, SHAFT_TOP - 4, SHAFT_TOP - 50, PIT_FLOOR + 30 } do
		local l = blk(Vector3.new(1, 1, 1), CFrame.new(H + Vector3.new(0, y, 0)), GLOW)
		l.Transparency = 1
		l.CanCollide = false
		light(l, GLOW, 60, y > SHAFT_TOP and 3 or 5)
	end
	for k = 0, 5 do
		local a = k / 6 * TAU
		local l = blk(Vector3.new(1, 1, 1), CFrame.new(H + Vector3.new(math.cos(a) * 64, RIM_Y - 28, math.sin(a) * 64)), GLOW)
		l.Transparency = 1
		l.CanCollide = false
		light(l, GLOW_HOT, 40, 2)
	end
	-- embers drifting up out of the hole
	local src = blk(Vector3.new(SHAFT_R * 1.6, 1, SHAFT_R * 1.6), CFrame.new(H + Vector3.new(0, PIT_FLOOR + 90, 0)), GLOW)
	src.Transparency = 1
	src.CanCollide = false
	src.CanQuery = false
	local pe = Instance.new("ParticleEmitter")
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Rate = 45
	pe.Lifetime = NumberRange.new(7, 11)
	pe.Speed = NumberRange.new(16, 28)
	pe.SpreadAngle = Vector2.new(12, 12)
	pe.LightEmission = 1
	pe.Brightness = 3
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 110, 30))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = src
	-- anyone who falls in is sent back up to camp
	local catch = blk(Vector3.new(SHAFT_R * 2, 6, SHAFT_R * 2), CFrame.new(H + Vector3.new(0, PIT_FLOOR + 6, 0)), GLOW)
	catch.Name = "PitReturn"
	catch.Transparency = 1
	catch.CanCollide = false
	catch.CanQuery = false
	return catch
end

local function buildCrane(H: Vector3, folderRef: Instance)
	local span = R_RIM + 18
	local top = 112
	-- two tapering lattice towers on the rim
	for _, sx in { -1, 1 } do
		local base = apronY(span + 13) - 1
		local c = H + Vector3.new(sx * span, base, 0)
		local th = top - base
		local b, t = 13, 6
		local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
		local function at(k: number, y: number): Vector3
			local s = b + (t - b) * (y / th)
			return c + Vector3.new(corners[k][1] * s, y, corners[k][2] * s)
		end
		for k = 1, 4 do
			beam(at(k, 0), at(k, th + 4), 2.2, STEEL)
			local foot = at(k, 0)
			local fy = apronY((Vector3.new(foot.X, 0, foot.Z) - Vector3.new(H.X, 0, H.Z)).Magnitude)
			blk(Vector3.new(5, 8, 5), CFrame.new(foot.X, fy - 2.5, foot.Z), Color3.fromRGB(180, 172, 160), Enum.Material.Concrete)
		end
		local levels = 6
		for l = 1, levels do
			local y0, y1 = (l - 1) / levels * th, l / levels * th
			for k = 1, 4 do
				local k2 = k % 4 + 1
				beam(at(k, y1), at(k2, y1), 1.2, STEEL)
				beam(at(k, y0), at(k2, y1), 0.7, STEEL_DARK)
				beam(at(k2, y0), at(k, y1), 0.7, STEEL_DARK)
			end
		end
		-- red warning lamps on top
		for k = 1, 4 do
			local lamp = glow(Vector3.new(1.4, 1.4, 1.4), CFrame.new(at(k, th + 5)), Color3.fromRGB(255, 50, 40))
			lamp.Shape = Enum.PartType.Ball
		end
	end
	-- the truss across the hole
	local yb, yt, zw = top - 8, top + 4, 5.5
	for _, y in { yb, yt } do
		for _, z in { -zw, zw } do
			beam(H + Vector3.new(-span - 6, y, z), H + Vector3.new(span + 6, y, z), 2, STEEL)
		end
	end
	local panels = 16
	for p = 0, panels do
		local x = -span + 2 * span * p / panels
		for _, z in { -zw, zw } do
			beam(H + Vector3.new(x, yb, z), H + Vector3.new(x, yt, z), 0.9, STEEL)
			if p < panels then
				local x2 = -span + 2 * span * (p + 1) / panels
				local ya, yc = yb, yt
				if p % 2 == 1 then
					ya, yc = yt, yb
				end
				beam(H + Vector3.new(x, ya, z), H + Vector3.new(x2, yc, z), 0.7, STEEL_DARK)
			end
		end
		beam(H + Vector3.new(x, yt, -zw), H + Vector3.new(x, yt, zw), 0.8, STEEL_DARK)
	end
	-- the sheave head: an A-frame on the truss with two big wheels
	local hy = yt + 14
	for _, z in { -zw, zw } do
		beam(H + Vector3.new(-14, yt, z), H + Vector3.new(-1, hy, z), 1.6, STEEL)
		beam(H + Vector3.new(14, yt, z), H + Vector3.new(1, hy, z), 1.6, STEEL)
	end
	blk(Vector3.new(4, 3, zw * 2 + 3), CFrame.new(H + Vector3.new(0, hy, 0)), RIG_RED, METAL)
	local wheels = {}
	for _, sx in { -1, 1 } do
		local base = CFrame.new(H + Vector3.new(sx * 7, hy - 1, 0)) * CFrame.Angles(0, math.pi / 2, 0)
		local wheel = blk(Vector3.new(1.4, 15, 15), base, RIG_RED, METAL)
		wheel.Shape = Enum.PartType.Cylinder
		local parts = {}
		for k = 0, 2 do
			table.insert(parts, blk(Vector3.new(2, 14.4, 1.1), base * CFrame.Angles(k * math.pi / 3, 0, 0), STEEL, METAL))
		end
		local hub = blk(Vector3.new(2.4, 3, 3), base, STEEL_DARK, METAL)
		hub.Shape = Enum.PartType.Cylinder
		table.insert(parts, hub)
		for _, p in parts do
			p.Anchored = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = wheel
			w.Part1 = p
			w.Parent = p
		end
		table.insert(wheels, { wheel = wheel, base = base, dir = sx })
	end
	-- the rig, hanging over the hole on cables, its cab facing the camp
	local rigCF = CFrame.lookAt(H + Vector3.new(0, 36, 0), H + Vector3.new(0, 36, 50))
	local body, parts = rig(rigCF, true)
	local hook = blk(Vector3.new(3.4, 4, 3.4), rigCF * CFrame.new(0, 17, 0), STEEL, METAL)
	hook.Anchored = false
	hook.Massless = true
	hook.CanCollide = false
	local hw = Instance.new("WeldConstraint")
	hw.Part0 = body
	hw.Part1 = hook
	hw.Parent = hook
	table.insert(parts, hook)
	local function att(p: BasePart, at: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Position = p.CFrame:PointToObjectSpace(at)
		a.Parent = p
		return a
	end
	local head = blk(Vector3.new(1, 1, 1), CFrame.new(H + Vector3.new(0, hy - 1, 0)), STEEL)
	head.Transparency = 1
	head.CanCollide = false
	local function cable(a0: Attachment, a1: Attachment, slack: number, t: number)
		local rope = Instance.new("RopeConstraint")
		rope.Attachment0 = a0
		rope.Attachment1 = a1
		rope.Length = (a0.WorldPosition - a1.WorldPosition).Magnitude + slack
		rope.Visible = true
		rope.Thickness = t
		rope.Color = BrickColor.new("Really black")
		rope.Parent = a0.Parent
	end
	for _, sx in { -1, 1 } do
		cable(att(head, H + Vector3.new(sx * 0.8, hy - 1, 0)), att(hook, (rigCF * CFrame.new(sx * 0.8, 19, 0)).Position), 6, 0.7)
	end
	for _, c in { { -8, -6 }, { 8, -6 }, { 8, 6 }, { -8, 6 } } do
		cable(att(hook, (rigCF * CFrame.new(0, 15, 0)).Position), att(body, (rigCF * CFrame.new(c[1], 4.3, c[2])).Position), 0, 0.45)
	end
	-- constant small motion: the rig sways down and back, the wheels turn
	task.defer(function()
		if not folderRef.Parent then
			return
		end
		TweenService:Create(body, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = rigCF * CFrame.new(0, -5, 0) * CFrame.Angles(0, 0.18, 0) }):Play()
		for _, w in wheels do
			task.spawn(function()
				local a = 0
				while folderRef.Parent do
					a += TAU / 3
					local t = TweenService:Create(w.wheel, TweenInfo.new(4, Enum.EasingStyle.Linear), { CFrame = w.base * CFrame.Angles(a * w.dir, 0, 0) })
					t:Play()
					t.Completed:Wait()
				end
			end)
		end
	end)
end

-- a rope bridge out to a rock pinnacle inside the hole
local function buildBridge(H: Vector3)
	local dir = Vector3.new(-0.62, 0, 0.78).Unit
	local side = Vector3.new(dir.Z, 0, -dir.X)
	local pc = H + dir * 66
	-- the pinnacle stands on the deepest bench ledge and rises to near the rim
	local top = RIM_Y - 2
	local yb = RIM_Y - BENCH_H * (BENCHES - 1)
	local hh = (top - yb) / 3
	for i = 0, 2 do
		local s = 17 - i * 1.5
		blk(Vector3.new(s, hh + 0.5, s), CFrame.new(pc + Vector3.new(0, yb + hh * (i + 0.5), 0)) * CFrame.Angles(0, i * 0.45 + 0.2, 0), ROCK[(i % 3) + 1], STONE)
	end
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.3
		local n = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = pc + n * 10 + Vector3.new(0, yb + 6, 0)
		blk(Vector3.new(12, 12, 6), CFrame.lookAt(p, p + n), ROCK[2], STONE, "WedgePart")
	end
	blk(Vector3.new(15, 1, 15), CFrame.new(pc + Vector3.new(0, top + 0.5, 0)) * CFrame.Angles(0, 0.2, 0), WOOD, PLANKS)
	flagPole(pc + Vector3.new(-3, top + 1, -3), 14, CLOTH[1], 0.4)
	glowCrate(CFrame.new(pc + Vector3.new(3.5, top + 1, 2.5)) * CFrame.Angles(0, 0.5, 0), 0.8)
	lanternPost(pc + Vector3.new(-4, top + 1, 4), 2.4)
	-- the bridge: planks on a sag from rim to pinnacle, rope handrails
	local a = H + dir * (R_RIM + 6) + Vector3.new(0, apronY(R_RIM + 6) + 0.3, 0)
	local b = pc + dir * 7.5 + Vector3.new(0, top + 1.1, 0)
	local len = (b - a).Magnitude
	local n = math.floor(len / 1.5)
	for i = 0, n do
		local t = i / n
		local p = sagAt(a, b, 2.4, t)
		local tangent = sagAt(a, b, 2.4, t + 0.01) - sagAt(a, b, 2.4, t - 0.01)
		local f = CFrame.lookAt(p, p + tangent)
		blk(Vector3.new(5.6, 0.35, 1.15), f * CFrame.new(0, -0.2, 0), i % 3 == 0 and WOOD_DARK or WOOD, PLANKS)
	end
	for _, s in { -1, 1 } do
		for _, e in { a, b } do
			blk(Vector3.new(0.6, 4.6, 0.6), CFrame.new(e + side * s * 3 + Vector3.new(0, 1.8, 0)), WOOD_DARK, Enum.Material.Wood)
		end
		sagLine(a + side * s * 3 + Vector3.new(0, 3.6, 0), b + side * s * 3 + Vector3.new(0, 3.6, 0), 1.8, 8, 0.22, Color3.fromRGB(220, 196, 150))
		for i = 1, 7 do
			local t = i / 8
			local lo = sagAt(a, b, 2.4, t) + side * s * 2.9
			local hi = sagAt(a + Vector3.new(0, 3.6, 0), b + Vector3.new(0, 3.6, 0), 1.8, t) + side * s * 3
			beam(lo, hi, 0.14, Color3.fromRGB(220, 196, 150), SMOOTH)
		end
	end
	-- string lights from the rim along the bridge
	stringLights(a + Vector3.new(0, 6.5, 0), b + Vector3.new(0, 5.5, 0), 2.5)
	blk(Vector3.new(0.5, 7, 0.5), CFrame.new(a + Vector3.new(0, 3.5, 0)), WOOD_DARK, Enum.Material.Wood)
	blk(Vector3.new(0.5, 7, 0.5), CFrame.new(b + Vector3.new(0, 3, 0)), WOOD_DARK, Enum.Material.Wood)
end

-- a wooden overlook jutting out over the hole, with struts and a railing
local function buildOverlook(H: Vector3)
	local dir = Vector3.new(0.62, 0, 0.78).Unit
	local y = Vector3.new(0, apronY(R_RIM + 6), 0)
	local start = H + dir * (R_RIM + 6) + y
	local tip = H + dir * (R_RIM - 14) + y
	local mid = (start + tip) / 2
	local cf = CFrame.lookAt(mid + Vector3.new(0, 0.3, 0), tip + Vector3.new(0, 0.3, 0))
	local L = (tip - start).Magnitude
	blk(Vector3.new(10, 0.6, L), cf, WOOD, PLANKS)
	for _, x in { -4.6, 4.6 } do
		blk(Vector3.new(0.8, 0.8, L), cf * CFrame.new(x, -0.6, 0), WOOD_DARK, Enum.Material.Wood)
		for i = 0, 4 do
			local z = -L / 2 + 2 + i * (L - 4) / 4
			blk(Vector3.new(0.5, 3.6, 0.5), cf * CFrame.new(x, 2, z), WOOD_DARK, Enum.Material.Wood)
		end
		blk(Vector3.new(0.4, 0.4, L - 3), cf * CFrame.new(x, 3.6, 0), WOOD, Enum.Material.Wood)
		-- struts down to the bench below
		beam((cf * CFrame.new(x, -0.8, -L / 2 + 1)).Position, (cf * CFrame.new(x, -14, 3)).Position, 0.8, WOOD_DARK, Enum.Material.Wood)
		beam((cf * CFrame.new(x, -0.8, -L / 2 + 5)).Position, (cf * CFrame.new(x, -14, 3)).Position, 0.8, WOOD_DARK, Enum.Material.Wood)
	end
	blk(Vector3.new(9.6, 0.4, 0.4), cf * CFrame.new(0, 3.6, -L / 2 + 0.2), WOOD, Enum.Material.Wood)
	-- a telescope on a tripod
	local tcf = cf * CFrame.new(0, 0.6, -L / 2 + 3)
	for k = 0, 2 do
		local a = k / 3 * TAU
		beam((tcf * CFrame.new(math.cos(a) * 1.4, 0, math.sin(a) * 1.4)).Position, (tcf * CFrame.new(0, 3.6, 0)).Position, 0.25, STEEL_DARK)
	end
	local scope = blk(Vector3.new(4, 0.9, 0.9), tcf * CFrame.new(0, 4.1, -0.6) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, -0.35), Color3.fromRGB(200, 160, 60), METAL)
	scope.Shape = Enum.PartType.Cylinder
	glowCrate(cf * CFrame.new(-2.6, 0.3, L / 2 - 4) * CFrame.Angles(0, 0.3, 0), 0.8)
	lanternPost((cf * CFrame.new(4.2, 0.3, L / 2 - 1.5)).Position, math.atan2(-dir.X, -dir.Z) + math.pi)
end

-- the near rim: a post-and-rope fence with bunting, a sign and lamps
local function buildRimFence(H: Vector3)
	local a0, a1 = math.rad(58), math.rad(122)
	local n = 12
	local prev
	for i = 0, n do
		local a = a0 + (a1 - a0) * i / n
		local p = H + Vector3.new(math.cos(a), 0, math.sin(a)) * (R_OUT + 3)
		blk(Vector3.new(0.8, 4.4, 0.8), CFrame.new(p + Vector3.new(0, 2.2, 0)), WOOD_DARK, Enum.Material.Wood)
		if prev then
			sagLine(prev + Vector3.new(0, 3.6, 0), p + Vector3.new(0, 3.6, 0), 0.8, 2, 0.25, Color3.fromRGB(214, 188, 140))
			bunting(prev + Vector3.new(0, 4.3, 0), p + Vector3.new(0, 4.3, 0), 1)
		end
		prev = p
	end
	-- DIG SITE sign at the end of the track
	local sp = H + Vector3.new(0, 0, R_OUT + 7)
	local cf = CFrame.lookAt(sp, sp + Vector3.new(0, 0, 1))
	for _, x in { -3.6, 3.6 } do
		blk(Vector3.new(0.6, 7, 0.6), cf * CFrame.new(x, 3.5, 0.3), WOOD_DARK, Enum.Material.Wood)
	end
	local board = blk(Vector3.new(9, 3.4, 0.4), cf * CFrame.new(0, 5.4, 0), Color3.fromRGB(250, 200, 40), SMOOTH)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(450, 170)
	gui.LightInfluence = 0.4
	gui.Parent = board
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = FONT
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(30, 24, 20)
	t.Text = "DIG SITE\nKEEP BACK"
	t.Parent = gui
	for _, x in { -1, 1 } do
		local d = blk(Vector3.new(2.6, 2.6, 0.3), cf * CFrame.new(x * 7, 5.4, 0) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(250, 200, 40), SMOOTH)
		d.CanCollide = false
		blk(Vector3.new(0.5, 6, 0.5), cf * CFrame.new(x * 7, 3, 0.3), WOOD_DARK, Enum.Material.Wood)
	end
end

-- a timber lookout: splayed legs, braces, a railed deck, a roof and a flag
local function lookout(pos: Vector3, yaw: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local h = 30
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	local function at(k: number, y: number): Vector3
		local s = 6 - 2.5 * (y / h)
		return (cf * CFrame.new(corners[k][1] * s, y, corners[k][2] * s)).Position
	end
	for k = 1, 4 do
		local k2 = k % 4 + 1
		beam(at(k, 0), at(k, h + 5), 1.2, WOOD_DARK, Enum.Material.Wood)
		beam(at(k, 2), at(k2, h * 0.5), 0.6, WOOD, Enum.Material.Wood)
		beam(at(k, h * 0.5), at(k2, h), 0.6, WOOD, Enum.Material.Wood)
	end
	blk(Vector3.new(10, 0.8, 10), cf * CFrame.new(0, h, 0), WOOD, PLANKS)
	for i = 0, 3 do
		blk(Vector3.new(10, 1.6, 0.4), cf * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, h + 1.8, 4.8), WOOD_DARK, PLANKS)
	end
	for _, side in { -1, 1 } do
		blk(Vector3.new(12, 2.4, 6.2), cf * CFrame.new(0, h + 6.2, side * 3) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), Color3.fromRGB(176, 36, 36), Enum.Material.Wood, "WedgePart")
	end
	flagPole((cf * CFrame.new(0, h + 7.4, 0)).Position, 6, CLOTH[3], yaw)
	local lamp = glow(Vector3.new(1.2, 1.6, 1.2), cf * CFrame.new(0, h + 3.4, 0), Color3.fromRGB(255, 200, 100))
	light(lamp, Color3.fromRGB(255, 190, 110), 20, 1.5)
end

-- a water tank on stilts
local function waterTank(pos: Vector3)
	for _, c in { { -4, -4 }, { 4, -4 }, { 4, 4 }, { -4, 4 } } do
		beam(pos + Vector3.new(c[1], 0, c[2]), pos + Vector3.new(c[1] * 0.8, 20, c[2] * 0.8), 1, WOOD_DARK, Enum.Material.Wood)
	end
	beam(pos + Vector3.new(-4, 3, -4), pos + Vector3.new(3.2, 18, 3.2), 0.5, WOOD, Enum.Material.Wood)
	beam(pos + Vector3.new(4, 3, -4), pos + Vector3.new(-3.2, 18, 3.2), 0.5, WOOD, Enum.Material.Wood)
	blk(Vector3.new(9, 0.8, 9), CFrame.new(pos + Vector3.new(0, 20, 0)), WOOD, PLANKS)
	local tank = blk(Vector3.new(10, 9, 9), CFrame.new(pos + Vector3.new(0, 25.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 140, 200), METAL)
	tank.Shape = Enum.PartType.Cylinder
	for _, y in { 22.5, 28.3 } do
		local band = blk(Vector3.new(0.6, 9.3, 9.3), CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), STEEL_DARK, METAL)
		band.Shape = Enum.PartType.Cylinder
	end
	-- a pyramid roof: four corner wedges, peaks meeting in the middle
	for _, q in { { -1, 1, 0 }, { 1, 1, math.pi / 2 }, { 1, -1, math.pi }, { -1, -1, -math.pi / 2 } } do
		blk(Vector3.new(5, 3, 5), CFrame.new(pos + Vector3.new(q[1] * 2.5, 31.6, q[2] * 2.5)) * CFrame.Angles(0, q[3], 0), RIG_RED, METAL, "CornerWedgePart")
	end
end

local function buildCamp(O: Vector3)
	-- tents round the clearing, cab doors facing in
	local tents = {
		{ -92, -22, 7, 9, 6.5 },
		{ -106, 6, 8, 10, 7 },
		{ -96, 36, 7, 9, 6.5 },
		{ -126, -36, 9, 11, 7.5 },
		{ 94, -26, 7, 9, 6.5 },
		{ 108, 4, 8, 10, 7 },
		{ 98, 38, 7, 9, 6.5 },
		{ 128, -34, 9, 11, 7.5 },
		{ -40, 84, 8, 10, 7 },
		{ 42, 84, 8, 10, 7 },
		{ -10, 96, 7, 9, 6.5 },
	}
	for i, t in tents do
		local p = O + Vector3.new(t[1], 0, t[2])
		local look = O + Vector3.new(0, 0, 8)
		local yaw = math.atan2(-(look.Z - p.Z), look.X - p.X)
		tent(p, yaw, CLOTH[(i - 1) % #CLOTH + 1], t[3] * 1.3, t[4] * 1.3, t[5] * 1.3)
	end
	canopy(O + Vector3.new(-82, 0, -52), 0.35, Color3.fromRGB(230, 60, 50), Color3.fromRGB(250, 240, 220))
	canopy(O + Vector3.new(118, 0, 62), -0.5, Color3.fromRGB(40, 130, 220), Color3.fromRGB(250, 240, 220))
	-- a campfire on the right, with log seats
	local fire = O + Vector3.new(80, 0, -54)
	for k = 0, 7 do
		local a = k / 8 * TAU
		blk(Vector3.new(1.6, 1, 1.4), CFrame.new(fire + Vector3.new(math.cos(a) * 3, 0.4, math.sin(a) * 3)) * CFrame.Angles(0.2, a, 0.1), Color3.fromRGB(130, 120, 116), STONE)
	end
	for k = 0, 2 do
		local l = blk(Vector3.new(4, 0.8, 0.8), CFrame.new(fire + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, k * math.pi / 3, 0.25), TRUNK, Enum.Material.Wood)
		l.Shape = Enum.PartType.Cylinder
	end
	local flame = glow(Vector3.new(1.6, 2.4, 1.6), CFrame.new(fire + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0.6, 0), GLOW_HOT, "WedgePart")
	glow(Vector3.new(1.1, 1.8, 1.1), CFrame.new(fire + Vector3.new(0.3, 1.4, 0.2)) * CFrame.Angles(0, 2.4, 0), Color3.fromRGB(255, 220, 90), "WedgePart")
	local f = Instance.new("Fire")
	f.Size = 4
	f.Heat = 6
	f.Parent = flame
	light(flame, GLOW_HOT, 20, 2)
	for k = 0, 2 do
		local a = k / 3 * TAU + 0.5
		local l = blk(Vector3.new(6, 1.6, 1.6), CFrame.new(fire + Vector3.new(math.cos(a) * 7.5, 0.8, math.sin(a) * 7.5)) * CFrame.Angles(0, -a + math.pi / 2, 0), TRUNK, Enum.Material.Wood)
		l.Shape = Enum.PartType.Cylinder
	end
	-- string lights strung pole to pole round the camp
	local poles = {
		O + Vector3.new(-72, 0, -36),
		O + Vector3.new(-84, 0, -6),
		O + Vector3.new(-82, 0, 26),
		O + Vector3.new(-66, 0, 52),
		O + Vector3.new(72, 0, -38),
		O + Vector3.new(86, 0, -8),
		O + Vector3.new(84, 0, 26),
		O + Vector3.new(68, 0, 54),
	}
	for _, p in poles do
		blk(Vector3.new(0.6, 11, 0.6), CFrame.new(p + Vector3.new(0, 5.5, 0)), WOOD_DARK, Enum.Material.Wood)
	end
	for _, pair in { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 5, 6 }, { 6, 7 }, { 7, 8 } } do
		stringLights(poles[pair[1]] + Vector3.new(0, 10.6, 0), poles[pair[2]] + Vector3.new(0, 10.6, 0), 2)
	end
	-- the long strand behind the boards
	stringLights(poles[4] + Vector3.new(0, 10.6, 0), O + Vector3.new(0, 12, 70), 2.5)
	stringLights(O + Vector3.new(0, 12, 70), poles[8] + Vector3.new(0, 10.6, 0), 2.5)
	blk(Vector3.new(0.6, 12.5, 0.6), CFrame.new(O + Vector3.new(0, 6.25, 70)), WOOD_DARK, Enum.Material.Wood)
	-- lantern posts behind the bay arc, between bays
	for k = 0, 4 do
		local a = math.rad(-50 + k * 25)
		local p = O + Vector3.new(math.sin(a) * 65, 0, -math.cos(a) * 65)
		lanternPost(p, math.atan2(p.X - O.X, p.Z - O.Z))
	end
	-- glowstone crates: by the bay ends, the tents and the track
	for _, c in { { -70, -20, 1 }, { -74, -14, 0.7 }, { 70, -18, 1 }, { 66, -24, 0.8 }, { -9, -66, 1 }, { 9, -68, 0.8 }, { -112, 26, 1 }, { 116, -14, 1 }, { -30, 70, 0.9 }, { 32, 72, 0.9 }, { -64, -66, 1 }, { 60, -70, 1.1 } } do
		glowCrate(CFrame.new(O + Vector3.new(c[1], 0, c[2])) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0), c[3])
	end
	-- plain supply crates and barrels
	for _, c in { { -100, -48 }, { 104, -48 }, { -120, 40 }, { 122, 30 }, { 52, 90 } } do
		local p = O + Vector3.new(c[1], 0, c[2])
		blk(Vector3.new(4, 4, 4), CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), WOOD, PLANKS)
		blk(Vector3.new(3, 3, 3), CFrame.new(p + Vector3.new(0.4, 5.5, 0.2)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), WOOD_DARK, PLANKS)
		local barrel = blk(Vector3.new(3.4, 2.6, 2.6), CFrame.new(p + Vector3.new(3.8, 1.7, 1.6)) * CFrame.Angles(0, 0, math.pi / 2), pick({ RIG_RED, STEEL, Color3.fromRGB(40, 120, 200) }), METAL)
		barrel.Shape = Enum.PartType.Cylinder
	end
	-- a parked rig you can climb onto, with a ramp
	local pr = CFrame.lookAt(O + Vector3.new(-132, 4.5, -80), O + Vector3.new(-60, 4.5, -60))
	local body = rig(pr, false)
	body.Anchored = true
	blk(Vector3.new(6, 8.6, 14), pr * CFrame.new(0, -0.2, 14.5) * CFrame.Angles(0, math.pi, 0), WOOD, PLANKS, "WedgePart")
	glowCrate(pr * CFrame.new(5, 4.3, 3), 0.7)
	-- tall silhouettes framing the camp: a lookout tower and a water tank
	lookout(O + Vector3.new(-150, 0, 18), 0.4)
	waterTank(O + Vector3.new(150, 0, 12))
end

local function buildWoods(O: Vector3, H: Vector3)
	local function clear(p: Vector3): boolean
		local rel = p - O
		if rel.Magnitude < 80 then
			return false
		end
		if (p - H).Magnitude < R_OUT + 10 or inRidge(p, H) then
			return false
		end
		-- keep the view from camp to the hole and the camp's tents open
		if math.abs(rel.X) < 140 and rel.Z < 20 and rel.Z > H.Z - O.Z then
			return false
		end
		if math.abs(rel.X) < 140 and rel.Z > -60 and rel.Z < 110 then
			return false
		end
		return true
	end
	local placed = 0
	-- woods: clusters on both flanks, behind the boards and past the hole
	local clusters = {
		{ -200, -10, 70, 22 },
		{ 200, -20, 70, 22 },
		{ -170, 150, 60, 15 },
		{ 170, 150, 60, 15 },
		{ 0, 180, 70, 15 },
		{ -170, -260, 70, 18 },
		{ 170, -260, 70, 18 },
		{ 0, -470, 90, 14 },
		{ -260, -120, 50, 12 },
		{ 260, -120, 50, 12 },
	}
	for _, c in clusters do
		for _ = 1, c[4] do
			local a, r = rng:NextNumber(0, TAU), c[3] * math.sqrt(rng:NextNumber())
			local p = O + Vector3.new(c[1] + math.cos(a) * r, 0, c[2] + math.sin(a) * r)
			if clear(p) then
				tree(p, rng:NextNumber(0.9, 1.6))
				placed += 1
			end
		end
	end
	-- a few strays and bushes everywhere else
	for _ = 1, 40 do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(90, 330)
		local p = O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if clear(p) then
			if rng:NextNumber() < 0.5 then
				tree(p, rng:NextNumber(0.8, 1.3))
			else
				bush(p, rng:NextNumber(0.8, 1.6))
			end
		end
	end
	-- bushes tucked round the clearing's edge
	for _ = 1, 30 do
		local a = rng:NextNumber(0, TAU)
		local p = O + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(110, 150)
		if (p - H).Magnitude > R_OUT + 8 and not (math.abs(p.X - O.X) < 70 and p.Z < O.Z) then
			bush(p, rng:NextNumber(0.8, 1.4))
		end
	end
	return placed
end

local function buildRocks(O: Vector3, H: Vector3)
	for _ = 1, 40 do
		local a, r = rng:NextNumber(0, TAU), rng:NextNumber(100, 340)
		local p = O + Vector3.new(math.cos(a) * r, -0.5, math.sin(a) * r)
		if (p - H).Magnitude > R_OUT + 8 and not inRidge(p, H) and not (math.abs(p.X - O.X) < 60 and p.Z < O.Z and p.Z > H.Z) then
			rock(p, rng:NextNumber(2, 7), pick(ROCK))
		end
	end
end

local function buildMesas(O: Vector3)
	-- a ring of mesas on the horizon, the biggest behind the hole
	local n = 20
	for i = 0, n - 1 do
		local a = (i + rng:NextNumber(-0.3, 0.3)) / n * TAU
		local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
		local behind = dir.Z < -0.6
		local r = behind and rng:NextNumber(560, 700) or rng:NextNumber(480, 640)
		local p = O + dir * r
		local h = behind and rng:NextNumber(110, 160) or rng:NextNumber(60, 120)
		mesa(p, rng:NextNumber(60, 120), rng:NextNumber(50, 90), h, rng:NextNumber(0, TAU))
	end
	-- buttes and spires closer in, framing the hole
	for _, b in { { -230, -300, 26, 70 }, { 240, -320, 22, 86 }, { -330, -150, 30, 54 }, { 330, -170, 28, 60 }, { -300, 80, 24, 46 }, { 310, 90, 26, 50 } } do
		mesa(O + Vector3.new(b[1], 0, b[2]), b[3], b[3] * 0.8, b[4], rng:NextNumber(0, TAU))
	end
end

---------------------------------------------------------------------------

function Camp.build()
	local old = Workspace:FindFirstChild("TopsideCamp")
	if old then
		old:Destroy()
	end
	local camp = Instance.new("Folder")
	camp.Name = "TopsideCamp"
	camp.Parent = Workspace
	folder = camp

	setupLighting()

	-- the plateau replaces the template's baseplate
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		baseplate.CanQuery = false
		baseplate.CanTouch = false
		baseplate.CFrame = CFrame.new(0, -400, 0)
	end

	local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
	local O = spawn and Vector3.new(spawn.Position.X, 0, spawn.Position.Z) or Vector3.zero
	if spawn then
		spawn.CFrame = CFrame.new(O + Vector3.new(0, 0.5, 8)) -- facing -Z: the bays
		spawn.Transparency = 1
		spawn.CanCollide = false
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal.Transparency = 1
		end
	end
	local H = O + Vector3.new(0, 0, -(R_OUT + 75)) -- the sinkhole, right behind the bays

	-- party bays: an arc of glass boxes facing spawn, like the reference's pads
	local bays = {}
	local angles = { -62.5, -37.5, -12.5, 12.5, 37.5, 62.5 }
	for i, a in angles do
		local r = math.rad(a)
		local pos = O + Vector3.new(math.sin(r) * 58, 0, -math.cos(r) * 58)
		local cf = CFrame.lookAt(pos, Vector3.new(O.X, 0, O.Z))
		local model = Instance.new("Model")
		model.Name = "Bay" .. i
		model.Parent = folder
		local floor = part({ Name = "Floor", Size = Vector3.new(14, 0.4, 14), CFrame = cf * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(200, 230, 240), Material = Enum.Material.Glass, Transparency = 0.4, Parent = model })
		for e = 0, 3 do
			local ecf = cf * CFrame.Angles(0, math.rad(90 * e), 0)
			part({ Name = "Edge", Size = Vector3.new(14.6, 0.6, 0.7), CFrame = ecf * CFrame.new(0, 0.5, 7), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
			part({ Name = "Wall", Size = Vector3.new(14, 7, 0.15), CFrame = ecf * CFrame.new(0, 3.9, 7), Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.82, CanCollide = false, CastShadow = false, Parent = model })
		end
		local anchor = part({ Name = "Sign", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 12, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
		local bb = Instance.new("BillboardGui")
		bb.Name = "Board"
		bb.Size = UDim2.fromScale(17, 7) -- studs, so it shrinks with distance like the reference
		bb.LightInfluence = 0
		bb.MaxDistance = 160
		bb.Parent = anchor
		local list = Instance.new("Frame")
		list.BackgroundTransparency = 1
		list.Size = UDim2.fromScale(1, 1)
		list.Parent = bb
		label(list, { Name = "Line1", Text = "PLAY", Size = UDim2.fromScale(1, 0.42), Stroke = 4 })
		label(list, { Name = "Line2", Text = "Step In to make a party", Position = UDim2.fromScale(0, 0.44), Size = UDim2.fromScale(1, 0.2) })
		label(list, { Name = "Line3", Text = "", Position = UDim2.fromScale(0, 0.65), Size = UDim2.fromScale(1, 0.18) })
		label(list, { Name = "Line4", Text = "", TextColor3 = Color3.fromRGB(110, 190, 255), Position = UDim2.fromScale(0, 0.84), Size = UDim2.fromScale(1, 0.14), Stroke = 2 })
		bays[i] = { model = model, floor = floor, cf = cf, board = list }
	end

	-- leaderboards behind spawn, facing the camp
	local boards = {}
	for i, b in { { "Fastest", -30, 44 }, { "Deepstones", 0, 50 }, { "Miles", 30, 44 } } do
		local screen = signFrame("Leaderboard" .. b[1], O + Vector3.new(b[2], 0, b[3]), O, 16, 19)
		screen:SetAttribute("Board", b[1])
		boards[i] = screen
	end

	-- the Free Revive board
	local revive = signFrame("FreeRevive", O + Vector3.new(56, 0, 22), O, 12, 14)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(360, 420)
	gui.LightInfluence = 0.3
	gui.Parent = revive
	label(gui, { Text = "♥", TextColor3 = Color3.fromRGB(230, 30, 50), Position = UDim2.fromScale(0.3, 0.02), Size = UDim2.fromScale(0.4, 0.24) })
	label(gui, { Text = "FREE REVIVE", Position = UDim2.fromScale(0.05, 0.27), Size = UDim2.fromScale(0.9, 0.16), Rotation = -4 })
	label(gui, { Text = "Join the group!", TextColor3 = Color3.fromRGB(255, 220, 90), Position = UDim2.fromScale(0.1, 0.46), Size = UDim2.fromScale(0.8, 0.11) })
	label(gui, { Text = "Get a free\nRevive Flare", Position = UDim2.fromScale(0.1, 0.6), Size = UDim2.fromScale(0.8, 0.24) })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FreeRevivePrompt"
	prompt.ActionText = "Free Revive"
	prompt.ObjectText = ""
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = revive

	-- the Classes hut: a red-roofed stall with a big sign
	local hcf = CFrame.lookAt(O + Vector3.new(-56, 0, 20), Vector3.new(O.X, 0, O.Z))
	local hut = Instance.new("Model")
	hut.Name = "ClassesHut"
	hut.Parent = folder
	part({ Name = "Floor", Size = Vector3.new(16, 1, 12), CFrame = hcf * CFrame.new(0, 0.5, 2), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = hut })
	for _, x in { -7.3, 7.3 } do
		for _, z in { -3.3, 7.3 } do
			part({ Name = "Post", Size = Vector3.new(1.2, 10, 1.2), CFrame = hcf * CFrame.new(x, 6, z), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = hut })
		end
	end
	part({ Name = "BackWall", Size = Vector3.new(15, 9, 0.6), CFrame = hcf * CFrame.new(0, 5.5, 7.4), Color = Color3.fromRGB(150, 40, 40), Material = Enum.Material.WoodPlanks, Parent = hut })
	for _, side in { -1, 1 } do
		part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(17, 3.6, 7.4), CFrame = hcf * CFrame.new(0, 12.4, 2 + side * 3.6) * CFrame.Angles(0, side > 0 and math.pi or 0, 0), Color = Color3.fromRGB(176, 36, 36), Material = Enum.Material.Wood, Parent = hut })
	end
	local counter = part({ Name = "Counter", Size = Vector3.new(14, 3.4, 1.6), CFrame = hcf * CFrame.new(0, 2.7, -3), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = hut })
	local cp = Instance.new("ProximityPrompt")
	cp.Name = "ClassesPrompt"
	cp.ActionText = "Classes"
	cp.MaxActivationDistance = 14
	cp.RequiresLineOfSight = false
	cp.Parent = counter
	local signPart = part({ Name = "Sign", Size = Vector3.new(16, 4, 0.4), CFrame = hcf * CFrame.new(0, 16.4, -1.4), Transparency = 1, CanCollide = false, Parent = hut })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(640, 160)
	sg.LightInfluence = 0
	sg.Parent = signPart
	label(sg, { Text = "CLASSES", TextColor3 = Color3.fromRGB(255, 205, 60), Size = UDim2.fromScale(1, 1), Stroke = 6 })

	-- the scenery, a chunk at a time: each is built outside the world, then
	-- dropped in whole before the next frame
	local backdrop = Instance.new("Folder")
	backdrop.Name = "Backdrop"
	backdrop.Parent = camp
	local function chunk(name: string, fn: () -> ())
		local f = Instance.new("Folder")
		f.Name = name
		folder = f
		fn()
		f.Parent = backdrop
		folder = camp
		task.wait()
	end
	chunk("Ground", function()
		buildGround(O, H)
	end)
	local catch: BasePart
	chunk("Sinkhole", function()
		catch = buildPit(H)
	end)
	chunk("Headframe", function()
		buildCrane(H, camp)
	end)
	chunk("Rim", function()
		buildBridge(H)
		buildOverlook(H)
		buildRimFence(H)
	end)
	chunk("Camp", function()
		buildCamp(O)
	end)
	chunk("Woods", function()
		buildWoods(O, H)
	end)
	chunk("Rocks", function()
		buildRocks(O, H)
	end)
	chunk("Mesas", function()
		buildMesas(O)
	end)

	-- anyone who falls into the hole comes back up at spawn
	local returning: { [Model]: boolean } = {}
	catch.Touched:Connect(function(hit)
		local char = hit.Parent
		if char and char:IsA("Model") and Players:GetPlayerFromCharacter(char) and not returning[char] then
			returning[char] = true
			char:PivotTo(CFrame.new(O + Vector3.new(0, 4, 8)))
			task.delay(1, function()
				returning[char] = nil
			end)
		end
	end)

	return { origin = O, bays = bays, boards = boards }
end

return Camp
