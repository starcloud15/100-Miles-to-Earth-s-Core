--[[
	The planned route (GDD 5.1): a spline that always trends downward, built
	from modular pieces shuffled by a seed. Server and client build the same
	route from the same seed.

	Distances along the route are "s" in studs; sideways offsets are "x"
	(positive = to the right when facing down the route).
]]

local Config = require(script.Parent.Config)

local Route = {}
Route.__index = Route
Route.STEP = 4 -- studs between nodes

export type Node = { p: Vector3, yaw: number, w: number }

local function forwardOf(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

function Route.new(seed: number, miles: number)
	local rng = Random.new(seed)
	local self = setmetatable({}, Route)
	self.seed = seed
	self.nodes = {} :: { Node }
	self.hazards = {} -- { s, len, offset, radius, kind }
	self.pickups = {} -- { id, s, offset, amount }
	self.signs = {} -- { s, kind, text }
	self.pieces = {} -- { s0, s1, kind }

	local STEP = Route.STEP
	local total = miles * Config.STUDS_PER_MILE
	local pos, yaw, width = Vector3.zero, 0, 80
	table.insert(self.nodes, { p = pos, yaw = yaw, w = width })

	local function length()
		return (#self.nodes - 1) * STEP
	end

	-- one piece: `len` studs turning `turnDeg` in total, dropping `slope` studs per stud
	local function run(len: number, turnDeg: number, slope: number, toWidth: number, kind: string)
		local n = math.max(1, math.floor(len / STEP + 0.5))
		local dyaw = math.rad(turnDeg) / n
		local w0 = width
		local s0 = length()
		for i = 1, n do
			yaw += dyaw
			pos += forwardOf(yaw) * STEP + Vector3.new(0, slope * STEP, 0)
			width = w0 + (toWidth - w0) * math.min(1, i / math.min(n, 12))
			table.insert(self.nodes, { p = pos, yaw = yaw, w = width })
		end
		local s1 = length()
		table.insert(self.pieces, { s0 = s0, s1 = s1, kind = kind })
		return s0, s1
	end

	local nextId = 0
	local function trail(s: number, offset: number, count: number, spacing: number, drift: number)
		for i = 0, count - 1 do
			nextId += 1
			table.insert(self.pickups, {
				id = nextId,
				s = s + i * spacing,
				offset = offset + drift * i,
				amount = rng:NextInteger(1, 3),
			})
		end
	end

	local function pillar(s: number, offset: number)
		table.insert(self.hazards, { s = s, len = 8, offset = offset, radius = 4, kind = "Pillar" })
		table.insert(self.signs, { s = s - 150, kind = "Warning", offset = offset })
	end

	-- hazards and loot inside an ordinary piece: something to steer for and around
	local function dress(a: number, b: number, w: number)
		local span = b - a
		if span < 160 then
			return
		end
		local count = rng:NextInteger(0, 2)
		local lastS = -math.huge
		for _ = 1, count do
			local s = a + rng:NextNumber(80, span - 40)
			if math.abs(s - lastS) > 120 then
				pillar(s, rng:NextNumber(-0.3, 0.3) * w)
				lastS = s
			end
		end
		local side = rng:NextNumber(-0.3, 0.3) * w
		trail(a + rng:NextNumber(30, math.max(40, span - 160)), side, rng:NextInteger(4, 6), 28, rng:NextNumber(-3, 3))
	end

	-- the surface quarry, then pieces until the zone is long enough
	run(160, 0, -0.02, 80, "Start")
	trail(90, 0, 4, 24, 0)
	local dropAt = 1 * Config.STUDS_PER_MILE
	local forkAt = 5 * Config.STUDS_PER_MILE
	local dropDone, forkDone = false, false
	while length() < total do
		local s = length()
		if not dropDone and s >= dropAt then
			-- The Drop (GDD 9.1): spiralling down the sinkhole wall into the first cavern
			dropDone = true
			table.insert(self.signs, { s = s - 120, kind = "Drop", text = "THE DROP" })
			local a = run(960, 540 * (rng:NextNumber() < 0.5 and -1 or 1), -0.16, 70, "Drop")
			trail(a + 220, 0, 5, 30, 0)
			trail(a + 620, 0, 5, 30, 0)
		elseif not forkDone and s >= forkAt then
			-- a fork (GDD 5.4): steer left for loot, right for calm
			forkDone = true
			run(80, 0, -0.04, 120, "ForkOpen")
			local a, b = run(320, 0, -0.04, 120, "Fork")
			table.insert(self.hazards, { s = (a + b) / 2, len = b - a - 40, offset = 0, radius = 8, kind = "Divider" })
			table.insert(self.signs, { s = a - 220, kind = "Fork", text = "FORK AHEAD", left = "Glowstone", right = "Calm" })
			trail(a + 40, -32, 9, 30, 0)
			run(80, 0, -0.04, 80, "ForkClose")
		else
			local r = rng:NextNumber()
			local a, b
			if r < 0.3 then
				a, b = run(rng:NextInteger(200, 320), 0, -rng:NextNumber(0.03, 0.08), 80, "Straight")
			elseif r < 0.6 then
				local turn = rng:NextNumber(35, 70) * (rng:NextNumber() < 0.5 and -1 or 1)
				a, b = run(rng:NextInteger(220, 300), turn, -0.05, 80, "Bend")
			elseif r < 0.75 then
				local turn = rng:NextNumber(30, 50) * (rng:NextNumber() < 0.5 and -1 or 1)
				a = run(160, turn, -0.05, 80, "S")
				local _
				_, b = run(160, -turn, -0.05, 80, "S")
			elseif r < 0.88 then
				a, b = run(rng:NextInteger(140, 200), 0, -0.16, 70, "Chute")
			else
				a, b = run(rng:NextInteger(220, 300), rng:NextNumber(-20, 20), -0.03, 110, "Cavern")
				trail(a + 60, -25, 5, 26, 2)
			end
			dress(a, b, width)
		end
	end
	self.length = length()
	return self
end

-- the route's frame at distance s: position on the centre line, facing down
-- the route (pitched with the slope), and the lane width there
function Route:sample(s: number): (CFrame, number, number)
	local n = self.nodes
	s = math.clamp(s, 0, self.length)
	local f = s / Route.STEP
	local i = math.floor(f) + 1
	if i >= #n then
		i = #n - 1
	end
	local t = f - (i - 1)
	local a, b = n[i], n[i + 1]
	local p = a.p:Lerp(b.p, t)
	local w = a.w + (b.w - a.w) * t
	local d = b.p - a.p
	local slope = d.Y / math.max(0.001, Vector3.new(d.X, 0, d.Z).Magnitude)
	return CFrame.lookAt(p, p + d.Unit), w, slope
end

-- where a point is relative to the route: distance along it, sideways offset
-- and height above it. Searches around `guess` (spiral loops stack up, so a
-- global search could pick the wrong loop).
function Route:locate(pos: Vector3, guess: number, window: number): (number, number, number)
	local n = self.nodes
	local i0 = math.max(1, math.floor((guess - window) / Route.STEP) + 1)
	local i1 = math.min(#n, math.floor((guess + window) / Route.STEP) + 1)
	local best, bi = math.huge, i0
	for i = i0, i1, 2 do
		local d = (n[i].p - pos).Magnitude
		if d < best then
			best, bi = d, i
		end
	end
	local s = (bi - 1) * Route.STEP
	local cf = self:sample(s)
	local rel = cf:PointToObjectSpace(pos)
	return s - rel.Z, rel.X, rel.Y
end

return Route
