--[[
	Topside Camp's world (GDD 14.1), laid out like the reference's lobby:
	a row of glass party bays in an arc facing spawn, three leaderboards
	behind, the Free Revive board, the Classes hut, and the sinkhole in view
	beyond the bays. Greybox; the backdrop around it is still a proposal.
]]

local Workspace = game:GetService("Workspace")

local Camp = {}

local FONT = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
local WOOD = Color3.fromRGB(124, 84, 52)
local WOOD_DARK = Color3.fromRGB(86, 56, 34)

local folder: Folder

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

local function tree(pos: Vector3, size: number)
	part({ Name = "Trunk", Size = Vector3.new(2 * size, 14 * size, 2 * size), Position = pos + Vector3.new(0, 7 * size, 0), Color = Color3.fromRGB(96, 64, 40), Material = Enum.Material.Wood })
	part({ Name = "Leaves", Size = Vector3.new(11 * size, 9 * size, 11 * size), Position = pos + Vector3.new(0, 16 * size, 0), Color = Color3.fromRGB(58, 132, 58), Material = Enum.Material.Grass })
	part({ Name = "Leaves", Size = Vector3.new(7 * size, 6 * size, 7 * size), Position = pos + Vector3.new(0, 22 * size, 0), Color = Color3.fromRGB(70, 150, 66), Material = Enum.Material.Grass })
end

function Camp.build()
	local old = Workspace:FindFirstChild("TopsideCamp")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "TopsideCamp"
	folder.Parent = Workspace

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

	-- the clearing
	part({ Name = "Ground", Size = Vector3.new(520, 1, 520), Position = O + Vector3.new(0, -0.45, 0), Color = Color3.fromRGB(86, 160, 66), Material = Enum.Material.Grass })
	part({ Name = "Path", Size = Vector3.new(16, 0.1, 120), Position = O + Vector3.new(0, 0.1, -70), Color = Color3.fromRGB(150, 116, 78), Material = Enum.Material.Ground })

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

	-- the sinkhole beyond the bays: the hole they're about to go down
	local hole = O + Vector3.new(0, 0, -150)
	part({ Name = "Sinkhole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 92, 92), CFrame = CFrame.new(hole + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(20, 14, 10), Material = Enum.Material.Slate })
	part({ Name = "SinkholeGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 50, 50), CFrame = CFrame.new(hole + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 150, 40), Material = Enum.Material.Neon, Transparency = 0.55 })
	for i = 1, 22 do
		local a = i / 22 * math.pi * 2
		local r = 47 + (i % 3)
		part({ Name = "Rim", Size = Vector3.new(10 + i % 4 * 2, 3 + i % 3 * 2, 9), CFrame = CFrame.new(hole + Vector3.new(math.cos(a) * r, 1, math.sin(a) * r)) * CFrame.Angles(0.2 * (i % 2), a, 0.15), Color = Color3.fromRGB(150 + i % 3 * 10, 96, 66), Material = Enum.Material.Sandstone })
	end

	-- quarry walls far around, and trees
	for i = 0, 31 do
		local a = i / 32 * math.pi * 2
		local p = O + Vector3.new(math.cos(a) * 230, 0, math.sin(a) * 230)
		local h = 50 + (i * 37 % 30)
		part({ Name = "QuarryWall", Size = Vector3.new(50, h, 16), CFrame = CFrame.lookAt(p + Vector3.new(0, h / 2 - 2, 0), O + Vector3.new(0, h / 2 - 2, 0)), Color = Color3.fromRGB(178, 104 + i % 3 * 8, 70), Material = Enum.Material.Sandstone })
	end
	local rng = Random.new(7)
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(85, 200)
		local p = O + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if (p - hole).Magnitude > 70 then
			tree(p, rng:NextNumber(0.8, 1.4))
		end
	end

	return { origin = O, bays = bays, boards = boards }
end

return Camp
