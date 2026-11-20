--[[
	The Drill Rig (GDD 5.2, 6; docs/match-spec.md). An open deck on two
	treads that follows the planned route by itself and never stops on its
	own, except at stops, where it brakes to a dead stop like the reference's
	raft. Cranking a side's tread speeds it up and steers it toward the
	OPPOSITE side. Both sides within 0.4 s give +15%.

	No health bar: hits break pieces off the model (Break* parts). At a stop
	the missing pieces show as ghosts and the crew repairs them with glowstone.

	The look comes from the Blender model (tools/blender/drill_rig.py), once
	Starport has uploaded it to src/shared/Models/Rig/DrillRig.rbxm. Until then
	a greybox stand-in with the same piece names is built here.

	Moved by physics constraints (not CFrame) so players on the deck ride along.
]]

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)

local C = Config.Rig

local Rig = {}
Rig.__index = Rig

local STEEL = Color3.fromRGB(92, 98, 108)
local STEEL_DARK = Color3.fromRGB(52, 56, 62)
local WOOD = Color3.fromRGB(168, 112, 66)
local BRASS = Color3.fromRGB(226, 168, 54)
local RED = Color3.fromRGB(196, 58, 44)

function Rig.new(route, onEvent: (string, any) -> ())
	local self = setmetatable({}, Rig)
	self.route = route
	self.onEvent = onEvent
	self.s = 40
	self.x = 0
	self.latVel = 0
	self.speed = 0
	self.pL, self.pR = 0, 0
	self.lastL, self.lastR = -10, -10
	self.synced = false
	self.moving = false
	self.stopAt = nil -- s of the stop we're braking for
	self.slowUntil = 0
	self.hazardHit = {} :: { [number]: number }
	self.broken = {} :: { BasePart }
	self:build()
	return self
end

-- the greybox stand-in, laid out like the Blender model (14 x 18 deck, +Z back, -Z front)
local function greybox(model: Model, deck: BasePart)
	local W, L = C.DECK_W, C.DECK_L
	local function add(name, size, offset, color, material, extra)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		for k, v in extra or {} do
			(p :: any)[k] = v
		end
		p.CFrame = deck.CFrame * offset
		p.Parent = model
		return p
	end
	for i = 0, 9 do
		add("Plank", Vector3.new(W / 10 - 0.12, 0.2, L - 0.4), CFrame.new(-W / 2 + W / 10 * (i + 0.5), 0.86, 0), i % 3 == 0 and Color3.fromRGB(150, 98, 58) or WOOD, Enum.Material.WoodPlanks)
	end
	for _, s in { -1, 1 } do
		add("Trim", Vector3.new(0.5, 1.2, L + 0.2), CFrame.new(s * W / 2, 0.4, 0), STEEL, Enum.Material.Metal)
		add(s < 0 and "TreadL" or "TreadR", Vector3.new(3.4, 3.2, L + 1.5), CFrame.new(s * (W / 2 + 1.9), -1.9, 0), Color3.fromRGB(38, 38, 42), Enum.Material.Rubber)
		for k = 0, 4 do
			add("Wheel", Vector3.new(0.6, 2.3, 2.3), CFrame.new(s * (W / 2 + 3.75), -1.9, -L / 2 + 2.5 + k * (L - 5) / 4), STEEL, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		end
		add("BreakFender" .. (s < 0 and "L" or "R"), Vector3.new(3.8, 0.35, L * 0.55), CFrame.new(s * (W / 2 + 1.9), 0.05, -L * 0.18), RED, Enum.Material.Metal)
		add("CrankBase" .. (s < 0 and "L" or "R"), Vector3.new(1.6, 3, 1.6), CFrame.new(s * W / 4, 2.4, 1), STEEL_DARK, Enum.Material.Metal)
		add("CrankLever" .. (s < 0 and "L" or "R"), Vector3.new(0.5, 0.5, 6), CFrame.new(s * W / 4, 4.2, 1), BRASS, Enum.Material.Metal)
	end
	for i, c in { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } } do
		add("BreakLantern" .. i, Vector3.new(0.6, 6, 0.6), CFrame.new(c[1] * (W / 2 - 0.8), 3.4, c[2] * (L / 2 - 0.8)), Color3.fromRGB(112, 72, 42), Enum.Material.Wood)
		local glow = add("LanternGlow" .. i, Vector3.new(1, 1.2, 1), CFrame.new(c[1] * (W / 2 - 0.8), 5.6, c[2] * (L / 2 - 2.1)), Color3.fromRGB(220, 160, 80), Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Range = 18
		l.Brightness = 0.7
		l.Color = Color3.fromRGB(255, 196, 120)
		l.Parent = glow
	end
	-- the engine at the back with its glowing furnace, and cargo
	add("EngineBlock", Vector3.new(6.4, 4.2, 4.2), CFrame.new(0, 3, L / 2 - 2.8), STEEL_DARK, Enum.Material.Metal)
	add("EngineHood", Vector3.new(6.9, 0.6, 4.6), CFrame.new(0, 5.3, L / 2 - 2.8), RED, Enum.Material.Metal)
	add("Furnace", Vector3.new(3.8, 2, 0.4), CFrame.new(0, 2.9, L / 2 - 4.95), Color3.fromRGB(200, 110, 40), Enum.Material.Neon)
	for _, x in { -2.2, 2.2 } do
		add("Exhaust", Vector3.new(1, 3.6, 1), CFrame.new(x, 7, L / 2 - 1.6), STEEL, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CFrame = deck.CFrame * CFrame.new(x, 7, L / 2 - 1.6) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	add("BreakCrate1", Vector3.new(2, 2, 2), CFrame.new(W / 2 - 1.8, 1.9, L / 2 - 6.4), WOOD, Enum.Material.WoodPlanks)
	add("BreakCrate2", Vector3.new(1.5, 1.5, 1.5), CFrame.new(W / 2 - 1.9, 1.65, L / 2 - 8.4), Color3.fromRGB(130, 86, 52), Enum.Material.WoodPlanks)
	add("BreakBarrel", Vector3.new(2, 1.8, 1.8), CFrame.new(W / 2 - 1.8, 1.9, L / 2 - 10.4), WOOD, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	-- the drill head at the front: collar, cone and a brass flute
	add("DrillCollar", Vector3.new(2, 8.4, 8.4), CFrame.new(0, 1, -L / 2 - 1) * CFrame.Angles(0, math.rad(90), 0), STEEL_DARK, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local bit = add("DrillBit", Vector3.new(6, 6, 6), CFrame.new(0, 1, -L / 2 - 4.5), Color3.fromRGB(200, 206, 214), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	add("DrillTip", Vector3.new(3, 3, 3), CFrame.new(0, 1, -L / 2 - 7.5), BRASS, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	add("Headlight", Vector3.new(1.1, 1.1, 0.4), CFrame.new(0, 5.8, -L / 2 - 1.4), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	return bit
end

-- the uploaded Blender model, if Starport has brought it back (src/shared/Models/Rig)
local function meshModel(): Model?
	local models = Shared:FindFirstChild("Models")
	local rigFolder = models and models:FindFirstChild("Rig")
	return rigFolder and rigFolder:FindFirstChild("DrillRig") :: Model?
end

function Rig:build()
	local old = Workspace:FindFirstChild("DrillRig")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "DrillRig"
	local W, L = C.DECK_W, C.DECK_L

	-- the deck is the physics root players stand on (invisible under the planks)
	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(W, 1.5, L)
	deck.Transparency = 1
	deck.CustomPhysicalProperties = PhysicalProperties.new(2, 1, 0, 1, 1)
	deck.Parent = model
	model.PrimaryPart = deck

	local bit
	local mesh = meshModel()
	if mesh then
		-- the Blender model faces +Z with its left at +X: turn it round onto our
		-- deck (front -Z), lined up by its own deck so the planks sit under your feet
		local m = mesh:Clone()
		local meshDeck = m:FindFirstChild("Deck", true) :: BasePart
		local base = meshDeck.CFrame
		local place = deck.CFrame * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, math.pi, 0)
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CFrame = place * base:ToObjectSpace(p.CFrame)
				p.CanCollide = false
				if p == meshDeck then
					p.Name = "DeckMesh"
				end
				p.Parent = model
			end
		end
		m:Destroy()
		-- the FBX's colours don't survive the import, so paint by piece
		local LOOK = {
			DeckMesh = { WOOD, Enum.Material.WoodPlanks },
			DeckTrim = { STEEL, Enum.Material.Metal },
			Chassis = { STEEL_DARK, Enum.Material.Metal },
			Tread = { Color3.fromRGB(42, 42, 46), Enum.Material.Rubber },
			Wheels = { STEEL, Enum.Material.Metal },
			BreakFender = { RED, Enum.Material.Metal },
			CrankBase = { STEEL_DARK, Enum.Material.Metal },
			CrankLever = { BRASS, Enum.Material.Metal },
			EngineBlock = { STEEL_DARK, Enum.Material.Metal },
			EngineHood = { RED, Enum.Material.Metal },
			FurnaceGrill = { STEEL, Enum.Material.Metal },
			Furnace = { Color3.fromRGB(230, 130, 50), Enum.Material.Neon },
			ExhaustCap = { BRASS, Enum.Material.Metal },
			Exhaust = { STEEL, Enum.Material.Metal },
			HopperGlow = { Color3.fromRGB(255, 180, 70), Enum.Material.Neon },
			Hopper = { Color3.fromRGB(112, 72, 42), Enum.Material.WoodPlanks },
			Brace = { STEEL_DARK, Enum.Material.Metal },
			BreakLantern = { Color3.fromRGB(112, 72, 42), Enum.Material.Wood },
			LanternGlow = { Color3.fromRGB(240, 170, 80), Enum.Material.Neon },
			BreakCrate = { WOOD, Enum.Material.WoodPlanks },
			BreakBarrel = { Color3.fromRGB(150, 98, 58), Enum.Material.Wood },
			DrillBit = { Color3.fromRGB(196, 202, 212), Enum.Material.Metal },
			DrillCollar = { STEEL_DARK, Enum.Material.Metal },
			HeadlightGlow = { Color3.fromRGB(255, 244, 210), Enum.Material.Neon },
			Headlight = { BRASS, Enum.Material.Metal },
		}
		for _, p in model:GetChildren() do
			if p:IsA("MeshPart") then
				for prefix, look in LOOK do
					if p.Name:sub(1, #prefix) == prefix and (#prefix > #(p:GetAttribute("LookKey") or "")) then
						p.Color = look[1]
						p.Material = look[2]
						p:SetAttribute("LookKey", prefix)
					end
				end
				if p.Name:sub(1, 11) == "LanternGlow" or p.Name == "Furnace" or p.Name == "HopperGlow" then
					local l = Instance.new("PointLight")
					l.Range = p.Name == "Furnace" and 14 or 18
					l.Brightness = 0.7
					l.Color = Color3.fromRGB(255, 196, 120)
					l.Parent = p
				end
			end
		end
		local glow = model:FindFirstChild("HeadlightGlow")
		if glow then
			glow.Name = "HeadlightLens"
			local head = model:FindFirstChild("Headlight")
			if head then
				head.Name = "HeadlightBody"
			end
			glow.Name = "Headlight"
		end
		bit = model:FindFirstChild("DrillBit")
	else
		bit = greybox(model, deck)
	end

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Rig"
			p.Anchored = false
			if p ~= deck then
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = deck
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	-- the crank levers rock on Motor6Ds, so pumping never changes the assembly
	for _, side in { "L", "R" } do
		local lever = model:FindFirstChild("CrankLever" .. side) :: BasePart?
		if lever then
			lever:FindFirstChildOfClass("WeldConstraint"):Destroy()
			local motor = Instance.new("Motor6D")
			motor.Name = "CrankMotor" .. side
			motor.Part0 = deck
			motor.Part1 = lever
			motor.C0 = deck.CFrame:ToObjectSpace(lever.CFrame)
			motor.Parent = deck
		end
	end
	-- the drill bit spins on its own motor
	if bit then
		bit:FindFirstChildOfClass("WeldConstraint"):Destroy()
		local motor = Instance.new("Motor6D")
		motor.Name = "BitMotor"
		motor.Part0 = deck
		motor.Part1 = bit
		motor.C0 = deck.CFrame:ToObjectSpace(bit.CFrame)
		motor.Parent = deck
		self.bitMotor = motor
		-- dust and sparks where the bit meets the rock
		local att = Instance.new("Attachment")
		att.Name = "BitFX"
		-- (the Blender bit points along its own +Z; the greybox ball doesn't care)
		att.Position = Vector3.new(0, 0, mesh and 4 or -3)
		att.Parent = bit
		local dust = Instance.new("ParticleEmitter")
		dust.Name = "Dust"
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(Color3.fromRGB(190, 150, 120))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.8, 1.6)
		dust.Speed = NumberRange.new(6, 14)
		dust.SpreadAngle = Vector2.new(70, 70)
		dust.Rate = 0
		dust.Parent = att
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.4, 0)
		sparks.Lifetime = NumberRange.new(0.3, 0.6)
		sparks.Speed = NumberRange.new(18, 34)
		sparks.SpreadAngle = Vector2.new(60, 60)
		sparks.Acceleration = Vector3.new(0, -60, 0)
		sparks.Rate = 0
		sparks.Parent = att
		self.dust, self.sparks = dust, sparks
	end
	local head = model:FindFirstChild("Headlight") :: BasePart?
	if head then
		local spot = Instance.new("SpotLight")
		spot.Face = mesh and Enum.NormalId.Back or Enum.NormalId.Front
		spot.Range = 60
		spot.Angle = 70
		spot.Brightness = 1.8
		spot.Color = Color3.fromRGB(255, 236, 200)
		spot.Parent = head
	end
	self.pieces = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name:sub(1, 5) == "Break" then
			table.insert(self.pieces, p)
		end
	end

	local att = Instance.new("Attachment")
	att.Name = "Drive"
	att.Parent = deck
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e9
	ap.MaxVelocity = math.huge
	ap.Responsiveness = 70
	ap.Parent = deck
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e10
	ao.MaxAngularVelocity = math.huge
	ao.Responsiveness = 45
	ao.Parent = deck

	self.model = model
	self.deck = deck
	self.align = ap
	self.orient = ao
	local start = self:targetCFrame()
	model:PivotTo(start)
	ap.Position = start.Position
	ao.CFrame = start.Rotation
	model.Parent = Workspace
	deck:SetNetworkOwner(nil)
end

function Rig:laneLimit(w: number): number
	return math.max(0, w / 2 - C.DECK_W / 2 - 4)
end

function Rig:targetCFrame(): CFrame
	local cf = self.route:sample(self.s)
	local pos = cf.Position + cf.RightVector * self.x + Vector3.yAxis * C.HEIGHT
	local turn = math.atan2(self.latVel, math.max(self.speed, 6)) * 0.7
	return CFrame.new(pos) * cf.Rotation * CFrame.Angles(0, -turn, 0)
end

function Rig:deckPosition(pos: Vector3): Vector3?
	local rel = self.deck.CFrame:PointToObjectSpace(pos)
	if math.abs(rel.X) <= C.DECK_W / 2 + 1.5 and math.abs(rel.Z) <= C.DECK_L / 2 + 1.5 and rel.Y > -1 and rel.Y < 9 then
		return rel
	end
	return nil
end

function Rig:crank(rel: Vector3): string
	local now = os.clock()
	local side = rel.X < 0 and "L" or "R"
	if side == "L" then
		self.pL = math.min(1, self.pL + C.PUMP)
		self.lastL = now
	else
		self.pR = math.min(1, self.pR + C.PUMP)
		self.lastR = now
	end
	local motor = self.deck:FindFirstChild("CrankMotor" .. side) :: Motor6D?
	if motor then
		motor.Transform = CFrame.Angles(math.rad(22), 0, 0)
		task.delay(0.12, function()
			if motor.Parent then
				motor.Transform = CFrame.Angles(math.rad(-22), 0, 0)
				task.delay(0.12, function()
					motor.Transform = CFrame.new()
				end)
			end
		end)
	end
	return side
end

-- a hit breaks a piece off the model: it tumbles away, and comes back on repair
function Rig:breakPiece(): BasePart?
	local intact = {}
	for _, p in self.pieces do
		if p.Transparency < 1 and not p:GetAttribute("Broken") then
			table.insert(intact, p)
		end
	end
	if #intact == 0 then
		return nil
	end
	local p = intact[math.random(1, #intact)]
	p:SetAttribute("Broken", true)
	local flying = p:Clone()
	flying:ClearAllChildren()
	flying.Anchored = false
	flying.CanCollide = true
	flying.CollisionGroup = "Default"
	flying.Parent = Workspace
	flying.AssemblyLinearVelocity = self.deck.AssemblyLinearVelocity * 0.3 + Vector3.new(math.random(-20, 20), 30, math.random(-10, 10))
	flying.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
	Debris:AddItem(flying, 6)
	p:SetAttribute("Look", p.Transparency)
	p.Transparency = 1
	for _, d in p:GetDescendants() do
		if d:IsA("Light") then
			d.Enabled = false
		end
	end
	table.insert(self.broken, p)
	return p
end

function Rig:brokenCount(): number
	return #self.broken
end

-- at a stop: show the missing pieces as white ghosts until repaired
function Rig:showGhosts(on: boolean)
	for _, p in self.broken do
		if on then
			p.Transparency = 0.55
			p.Material = Enum.Material.ForceField
			p.Color = Color3.new(1, 1, 1)
		else
			p.Transparency = 1
		end
	end
end

function Rig:repairAll()
	for _, p in self.broken do
		p:SetAttribute("Broken", nil)
		p.Transparency = p:GetAttribute("Look") or 0
		p.Material = Enum.Material.SmoothPlastic
		for _, d in p:GetDescendants() do
			if d:IsA("Light") then
				d.Enabled = true
			end
		end
	end
	self.broken = {}
end

function Rig:stopFor(s: number)
	self.stopAt = s
end

function Rig:step(dt: number)
	local now = os.clock()
	if now - (self.lastOwnerCheck or 0) > 1 then
		self.lastOwnerCheck = now
		if self.deck:GetNetworkOwner() ~= nil then
			self.deck:SetNetworkOwner(nil)
		end
	end
	self.pL = math.max(0, self.pL - C.DECAY * dt)
	self.pR = math.max(0, self.pR - C.DECAY * dt)
	self.synced = math.abs(self.lastL - self.lastR) <= C.SYNC_WINDOW and now - math.max(self.lastL, self.lastR) < 1
	local _, w, slope = self.route:sample(self.s)

	local target = 0
	if self.moving then
		local power = (self.pL + self.pR) / 2
		target = C.IDLE_SPEED + (C.CRANK_SPEED - C.IDLE_SPEED) * power
		if self.synced then
			target *= C.SYNC_BONUS
		end
		target += math.max(0, -slope - C.CHUTE_SLOPE) * C.CHUTE_BONUS
		if now < self.slowUntil then
			target *= 0.25 -- grinding through hard rock
		end
		target = math.min(target, C.MAX_SPEED)
		if self.stopAt then
			-- brake so we stop dead at the stop, like the raft at a dock
			local left = self.stopAt - self.s
			target = math.min(target, math.sqrt(math.max(0, 2 * C.BRAKE * left)))
			if left <= 0.5 then
				target = 0
				self.speed = 0
				self.moving = false
				self.stopAt = nil
				self.onEvent("Arrived", nil)
			end
		end
	end
	local rate = target > self.speed and 1.6 or 3
	self.speed += (target - self.speed) * math.min(1, dt * rate)
	self.s = math.min(self.route.length, self.s + self.speed * dt)

	local latTarget = self.moving and C.LAT_SPEED * (self.pL - self.pR) or 0
	self.latVel += (latTarget - self.latVel) * math.min(1, dt * 3)
	local lim = self:laneLimit(w)
	self.x = math.clamp(self.x + self.latVel * dt, -lim, lim)

	-- hazards: boulders shove the rig aside; rock bands grind it down. Neither stops it.
	local halfL, halfW = C.DECK_L / 2, C.DECK_W / 2 + 3.5
	for i, h in self.route.hazards do
		if self.s + halfL + 6 > h.s - h.len / 2 and self.s - halfL < h.s + h.len / 2 then
			local gap = self.x - h.offset
			if math.abs(gap) < h.radius + halfW then
				if h.kind == "Boulder" then
					local dir = gap >= 0 and 1 or -1
					self.x = math.clamp(h.offset + dir * (h.radius + halfW + 0.5), -lim - 6, lim + 6)
					self.latVel = dir * 6
				else
					self.slowUntil = now + 0.6
				end
				if now - (self.hazardHit[i] or -10) > 3 then
					self.hazardHit[i] = now
					self:breakPiece()
					self.onEvent("Hit", h)
				end
			end
		end
	end

	local target = self:targetCFrame()
	self.align.Position = target.Position
	self.orient.CFrame = target.Rotation
	if self.bitMotor then
		self.bitAngle = ((self.bitAngle or 0) + self.speed * dt * 0.6) % (math.pi * 2)
		self.bitMotor.Transform = CFrame.Angles(0, 0, self.bitAngle)
	end
end

-- drill effects while boring through rock (called by Main with what World.carve did)
function Rig:drilling(kind: string?)
	if not self.dust then
		return
	end
	local boring = kind ~= nil and self.speed > 1
	self.dust.Rate = boring and 40 or 0
	self.sparks.Rate = boring and 30 or 0
	if kind == "breakthrough" then
		self.dust:Emit(60)
	end
end

return Rig
