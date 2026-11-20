--[[
	The Drill Rig (GDD 5.2, 6): an open deck on two treads. It follows the
	planned route by itself and never stops on its own; cranking a side's
	tread speeds it up and steers it toward the OPPOSITE side, like paddling.
	Both sides within 0.4 s of each other give a +15% sync bonus.

	Moved by physics constraints (not CFrame) so players standing on the deck
	are carried along with it.
]]

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)

local C = Config.Rig

local Rig = {}
Rig.__index = Rig

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

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
	self.health = C.MAX_HEALTH
	self.glowstone = 0
	self.moving = false
	self.hazardHit = {} :: { [number]: number }
	self.taken = {} :: { [number]: boolean }
	self.lastScrape = 0
	self:build()
	return self
end

function Rig:build()
	local old = Workspace:FindFirstChild("DrillRig")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "DrillRig"
	local W, L = C.DECK_W, C.DECK_L

	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(W, 1.5, L)
	deck.Material = Enum.Material.WoodPlanks
	deck.Color = Color3.fromRGB(150, 104, 62)
	deck.TopSurface = Enum.SurfaceType.Smooth
	deck.CustomPhysicalProperties = PhysicalProperties.new(2, 1, 0, 1, 1)
	deck.Parent = model
	model.PrimaryPart = deck

	local function add(props: { [string]: any }, offset: CFrame): BasePart
		local p = Instance.new(props.ClassName or "Part")
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props do
			if k ~= "ClassName" then
				(p :: any)[k] = v
			end
		end
		p.CFrame = deck.CFrame * offset
		weld(deck, p)
		p.Parent = model
		return p
	end

	-- the two halves of the deck read as two sides: warm left, cool right
	for _, side in { -1, 1 } do
		add({ Name = side < 0 and "LeftHalf" or "RightHalf", Size = Vector3.new(W / 2 - 0.4, 0.1, L - 0.8), Color = side < 0 and Color3.fromRGB(178, 120, 70) or Color3.fromRGB(130, 112, 98), Material = Enum.Material.WoodPlanks, CanCollide = false }, CFrame.new(side * W / 4, 0.8, 0))
		-- treads
		add({ Name = side < 0 and "TreadL" or "TreadR", Size = Vector3.new(3, 3.6, L + 2), Color = Color3.fromRGB(40, 40, 44), Material = Enum.Material.DiamondPlate }, CFrame.new(side * (W / 2 + 1.5), -1.6, 0))
		-- the crank pump: a handcar handle on a post, one per side
		add({ Name = "CrankPost" .. (side < 0 and "L" or "R"), Size = Vector3.new(1, 4, 1), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Metal, CanCollide = false }, CFrame.new(side * W / 4, 2.7, 0))
		add({ Name = "CrankHandle" .. (side < 0 and "L" or "R"), Size = Vector3.new(0.6, 0.6, 5), Color = Color3.fromRGB(240, 180, 40), Material = Enum.Material.Metal, CanCollide = false }, CFrame.new(side * W / 4, 4.9, 0))
	end
	-- lantern posts at the corners (always open: no walls or roof)
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			add({ Name = "LanternPost", Size = Vector3.new(0.6, 5, 0.6), Color = Color3.fromRGB(60, 44, 30), Material = Enum.Material.Wood }, CFrame.new(cx * (W / 2 - 0.6), 3.2, cz * (L / 2 - 0.6)))
			local lamp = add({ Name = "Lantern", Size = Vector3.new(1.2, 1.4, 1.2), Color = Color3.fromRGB(255, 196, 80), Material = Enum.Material.Neon, CanCollide = false }, CFrame.new(cx * (W / 2 - 0.6), 6.1, cz * (L / 2 - 0.6)))
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 1.2
			light.Color = Color3.fromRGB(255, 200, 120)
			light.Parent = lamp
		end
	end
	-- the drill head at the front
	add({ Name = "DrillHousing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 10, 10), Color = Color3.fromRGB(90, 90, 98), Material = Enum.Material.Metal }, CFrame.new(0, 0.5, -L / 2 - 1.5) * CFrame.Angles(0, math.rad(90), 0))
	self.bit = add({ Name = "DrillBit", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.DiamondPlate }, CFrame.new(0, 0.5, -L / 2 - 4.5))

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Rig"
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
	ap.Responsiveness = 60
	ap.Parent = deck
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e10
	ao.MaxAngularVelocity = math.huge
	ao.Responsiveness = 40
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
	return math.max(0, math.min(w * C.LANE_FRACTION, w / 2 - C.DECK_W / 2 - 2))
end

function Rig:targetCFrame(): CFrame
	local cf = self.route:sample(self.s)
	local pos = cf.Position + cf.RightVector * self.x + Vector3.yAxis * C.HEIGHT
	local turn = math.atan2(self.latVel, math.max(self.speed, 6)) * 0.7
	return CFrame.new(pos) * cf.Rotation * CFrame.Angles(0, -turn, 0)
end

-- where a player stands relative to the deck, or nil if not on it
function Rig:deckPosition(pos: Vector3): Vector3?
	local rel = self.deck.CFrame:PointToObjectSpace(pos)
	if math.abs(rel.X) <= C.DECK_W / 2 + 1.5 and math.abs(rel.Z) <= C.DECK_L / 2 + 1.5 and rel.Y > -1 and rel.Y < 9 then
		return rel
	end
	return nil
end

-- one pump from a player standing on the deck: their half picks the tread
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
	local handle = self.model:FindFirstChild("CrankHandle" .. side) :: BasePart?
	if handle then
		-- rock the handle: re-weld it at a tilt, then back
		local w = handle:FindFirstChildOfClass("WeldConstraint")
		if w then
			w.Enabled = false
			local x = (side == "L" and -1 or 1) * C.DECK_W / 4
			handle.CFrame = self.deck.CFrame * CFrame.new(x, 4.9, 0) * CFrame.Angles(math.rad(25), 0, 0)
			w.Enabled = true
			task.delay(0.12, function()
				if handle.Parent then
					w.Enabled = false
					handle.CFrame = self.deck.CFrame * CFrame.new(x, 4.9, 0)
					w.Enabled = true
				end
			end)
		end
	end
	return side
end

function Rig:damage(amount: number, why: string)
	self.health = math.max(1, self.health - amount) -- M0: no stall yet (GDD 6.2)
	self.onEvent("Damage", { amount = amount, why = why })
end

function Rig:step(dt: number)
	local now = os.clock()
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
		target += math.max(0, -slope - 0.06) * C.CHUTE_BONUS -- downhill chutes run faster
	end
	self.speed += (target - self.speed) * math.min(1, dt * 1.5)
	self.s = math.min(self.route.length, self.s + self.speed * dt)

	-- steering: the left tread pushes the rig right, the right tread pushes it left
	local latTarget = self.moving and C.LAT_SPEED * (self.pL - self.pR) or 0
	self.latVel += (latTarget - self.latVel) * math.min(1, dt * 3)
	local lim = self:laneLimit(w)
	self.x += self.latVel * dt
	if math.abs(self.x) >= lim then
		self.x = math.clamp(self.x, -lim, lim)
		if math.abs(latTarget) > 2 and math.sign(latTarget) == math.sign(self.x) and now - self.lastScrape > 1 then
			self.lastScrape = now
			self:damage(C.SCRAPE_DAMAGE, "Scrape")
		end
	end

	-- hazards cost health and shove the rig aside; they never stop it
	local halfL, halfW = C.DECK_L / 2, C.DECK_W / 2
	for i, h in self.route.hazards do
		if self.s + halfL > h.s - h.len / 2 and self.s - halfL < h.s + h.len / 2 then
			local gap = self.x - h.offset
			if math.abs(gap) < h.radius + halfW then
				local dir = gap >= 0 and 1 or -1
				self.x = math.clamp(h.offset + dir * (h.radius + halfW + 0.5), -lim - 6, lim + 6)
				self.latVel = dir * 6
				if now - (self.hazardHit[i] or -10) > 2 then
					self.hazardHit[i] = now
					self:damage(C.HAZARD_DAMAGE, h.kind)
					self.onEvent("Hit", h)
				end
			end
		end
	end

	-- steer over loose glowstone to scoop it up
	for _, p in self.route.pickups do
		if not self.taken[p.id] and math.abs(p.s - self.s) < halfL and math.abs(p.offset - self.x) < halfW + 1.5 then
			self.taken[p.id] = true
			self.glowstone += p.amount
			self.onEvent("Pickup", p)
		end
	end

	local target = self:targetCFrame()
	self.align.Position = target.Position
	self.orient.CFrame = target.Rotation
	if self.bit then
		self.bit.Color = self.speed > C.IDLE_SPEED + 4 and Color3.fromRGB(255, 220, 140) or Color3.fromRGB(200, 200, 210)
	end
end

return Rig
