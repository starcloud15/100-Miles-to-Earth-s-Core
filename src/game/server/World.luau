--[[
	Builds the cavern around the route as the rig moves: floor, walls,
	hazards, loose glowstone and warning signs, in chunks streamed in ahead of
	the rig and removed far behind it. Greybox parts for M0; route models from
	Starport (src/shared/Models/Route) replace them later.
]]

local Workspace = game:GetService("Workspace")

local Route = require(game:GetService("ReplicatedStorage").Shared.Route)

local World = {}

local CHUNK_NODES = 6
local CHUNK_LEN = Route.STEP * CHUNK_NODES
local AHEAD, BEHIND = 900, 900
local SHOULDER = 18 -- walkable ground beside the lane, for players who fall off
local WALL_H = 70

local route
local folder: Folder
local chunks: { [number]: Model } = {}
local pickupParts: { [number]: BasePart } = {}
local collected: { [number]: boolean } = {}

local SURFACE_UNTIL = 1000 -- the quarry and forest track before The Drop

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = "World"
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function signBoard(model: Model, cf: CFrame, w: number, sign)
	local side = -1
	local base = cf * CFrame.new(side * (w / 2 + 8), 0, 0)
	part({ Name = "SignPost", Size = Vector3.new(1, 12, 1), CFrame = base * CFrame.new(0, 6, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood, Parent = model })
	local board = part({
		Name = "Sign",
		Size = Vector3.new(14, 10, 0.6),
		CFrame = base * CFrame.new(0, 14, 0) * CFrame.Angles(0, math.rad(20), 0) * CFrame.Angles(0, 0, math.rad(45 * (sign.kind == "Warning" and 1 or 0))),
		Color = Color3.fromRGB(255, 200, 30),
		Parent = model,
	})
	if sign.kind == "Warning" then
		board.Size = Vector3.new(9, 9, 0.6)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(280, 200)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)
	label.TextScaled = true
	label.TextColor3 = Color3.new(0, 0, 0)
	label.Rotation = sign.kind == "Warning" and -45 or 0
	if sign.kind == "Fork" then
		label.Text = "FORK AHEAD\n< " .. sign.left .. "   " .. sign.right .. " >"
	elseif sign.kind == "Drop" then
		label.Text = "THE DROP\nhold on!"
	else
		label.Text = "!"
	end
	label.Parent = gui
end

local function buildChunk(k: number)
	local nodes = route.nodes
	local a = k * CHUNK_NODES + 1
	local b = math.min(a + CHUNK_NODES, #nodes)
	if a >= #nodes then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Chunk" .. k
	local pa, pb = nodes[a].p, nodes[b].p
	local mid = (pa + pb) / 2
	local len = (pb - pa).Magnitude
	local w = math.max(nodes[a].w, nodes[b].w)
	local cf = CFrame.lookAt(mid, pb)
	local s0 = (a - 1) * Route.STEP
	local surface = s0 < SURFACE_UNTIL
	local floorW = w + SHOULDER * 2

	local floorMat = surface and Enum.Material.Grass or Enum.Material.Ground
	local floorCol = surface and Color3.fromRGB(96, 158, 72) or Color3.fromRGB(150, 92, 62)
	local laneMat = surface and Enum.Material.Ground or Enum.Material.Slate
	local laneCol = surface and Color3.fromRGB(140, 104, 70) or Color3.fromRGB(110, 70, 50)
	local wallCol = surface and Color3.fromRGB(178, 98, 64) or Color3.fromRGB(128, 76, 56)
	part({ Name = "Floor", Size = Vector3.new(floorW, 4, len + 1), CFrame = cf * CFrame.new(0, -2, 0), Material = floorMat, Color = floorCol, Parent = model })
	-- a darker lane so the crew can read the route
	part({ Name = "Lane", Size = Vector3.new(w, 0.2, len + 1), CFrame = cf * CFrame.new(0, 0.05, 0), Material = laneMat, Color = laneCol, CanCollide = false, Parent = model })
	for _, side in { -1, 1 } do
		part({ Name = "Wall", Size = Vector3.new(8, WALL_H, len + 1), CFrame = cf * CFrame.new(side * (floorW / 2 + 4), WALL_H / 2 - 4, 0), Material = Enum.Material.Sandstone, Color = wallCol, Parent = model })
	end
	-- round joints where this chunk meets the next, so bends have no gaps or steps
	local jcf = CFrame.lookAt(pb, pb + (pb - pa).Unit)
	local wb = nodes[b].w
	local fw = wb + SHOULDER * 2
	local up = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis is X: stand it up
	part({ Name = "FloorJoint", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, fw, fw), CFrame = jcf * CFrame.new(0, -2, 0) * up, Material = floorMat, Color = floorCol, Parent = model })
	part({ Name = "LaneJoint", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, wb, wb), CFrame = jcf * CFrame.new(0, 0.05, 0) * up, Material = laneMat, Color = laneCol, CanCollide = false, Parent = model })
	for _, side in { -1, 1 } do
		part({ Name = "WallJoint", Shape = Enum.PartType.Cylinder, Size = Vector3.new(WALL_H, 8, 8), CFrame = CFrame.new(jcf * Vector3.new(side * (fw / 2 + 4), WALL_H / 2 - 4, 0)) * up, Material = Enum.Material.Sandstone, Color = wallCol, Parent = model })
	end

	local s1 = s0 + CHUNK_LEN
	for _, h in route.hazards do
		if h.s >= s0 and h.s < s1 then
			local hcf = route:sample(h.s)
			local pos = hcf.Position + hcf.RightVector * h.offset
			if h.kind == "Divider" then
				part({ Name = "Divider", Size = Vector3.new(h.radius * 2, 40, h.len), CFrame = hcf * CFrame.new(h.offset, 20, 0), Material = Enum.Material.Rock, Color = Color3.fromRGB(120, 110, 100), Parent = model })
			else
				part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, h.radius * 2, h.radius * 2), CFrame = CFrame.new(pos + Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Rock, Color = Color3.fromRGB(140, 120, 100), Parent = model })
			end
		end
	end
	for _, sign in route.signs do
		if sign.s >= s0 and sign.s < s1 then
			local scf, sw = route:sample(sign.s)
			signBoard(model, scf, sw, sign)
		end
	end
	for _, p in route.pickups do
		if p.s >= s0 and p.s < s1 and not collected[p.id] then
			local pcf = route:sample(p.s)
			local chunk = part({
				Name = "Glowstone",
				Size = Vector3.new(2.2, 2.2, 2.2),
				CFrame = CFrame.new(pcf.Position + pcf.RightVector * p.offset + Vector3.new(0, 1.4, 0)) * CFrame.Angles(math.rad(p.id * 37 % 90), math.rad(p.id * 53 % 90), 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 196, 64),
				CanCollide = false,
				Parent = model,
			})
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 190, 80)
			light.Range = 10
			light.Brightness = 1.5
			light.Parent = chunk
			pickupParts[p.id] = chunk
		end
	end
	model.Parent = folder
	chunks[k] = model
end

function World.init(r)
	route = r
	folder = Workspace:FindFirstChild("Cavern") :: Folder
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Cavern"
	folder.Parent = Workspace
end

-- builds what's near the rig, at most `budget` chunks per call
function World.update(s: number, budget: number?)
	local last = math.min(math.floor(route.length / CHUNK_LEN), math.floor((s + AHEAD) / CHUNK_LEN))
	local first = math.max(0, math.floor((s - BEHIND) / CHUNK_LEN))
	local built = 0
	for k = first, last do
		if not chunks[k] then
			buildChunk(k)
			built += 1
			if budget and built >= budget then
				break
			end
		end
	end
	for k, m in chunks do
		if k < first or k > last + 4 then
			m:Destroy()
			chunks[k] = nil
		end
	end
end

function World.collect(id: number)
	collected[id] = true
	local p = pickupParts[id]
	pickupParts[id] = nil
	if p and p.Parent then
		p:Destroy()
	end
end

return World
