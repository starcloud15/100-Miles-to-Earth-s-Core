--[[
	The planned route (GDD 5.1, docs/match-spec.md §4): a steep downhill dig
	that bends every 10-20 s at speed, built from pieces shuffled by a seed.
	Server and client build the same route from the same seed.

	Zone 1: an open gorge at the surface, The Drop (a spiral down a sinkhole
	shaft), then enclosed tunnels with chutes, caverns, rock bands and named
	stop chambers at fixed miles. Nothing to pick up along the way: glowstone
	is mined at stops (owner, like the reference's trees at camps).

	"s" is the distance along the route in studs; "x" is the sideways offset
	(positive = right when facing down the route).
]]

local Config = require(script.Parent.Config)

local Route = {}
Route.__index = Route
Route.STEP = 4

local function forwardOf(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

function Route.new(seed: number, miles: number)
	local rng = Random.new(seed)
	local self = setmetatable({}, Route)
	self.seed = seed
	self.nodes = {} -- { p, yaw, w, h, kind }
	self.hazards = {} -- { s, len, offset, radius, kind }
	self.signs = {} -- { s, kind, text }
	self.pieces = {} -- { s0, s1, kind }
	self.stops = {} -- { s, name, kind }
	self.caverns = {} -- { s0, s1 }

	local STEP = Route.STEP
	local SPM = Config.STUDS_PER_MILE
	local total = miles * SPM
	local T = Config.Tunnel
	local pos, yaw = Vector3.zero, 0
	local width, height = 64, 0
	table.insert(self.nodes, { p = pos, yaw = yaw, w = width, h = height, kind = "Gorge" })

	local function length()
		return (#self.nodes - 1) * STEP
	end

	local function run(len: number, turnDeg: number, slope: number, toWidth: number, toHeight: number, kind: string)
		local n = math.max(1, math.floor(len / STEP + 0.5))
		local w0, h0 = width, height
		local s0 = length()
		for i = 1, n do
			-- ease the turn in and out so bends feel like curves, not kinks
			local t = (i - 0.5) / n
			yaw += math.rad(turnDeg) / n * (1 - math.cos(t * math.pi * 2)) * 1
			pos += forwardOf(yaw) * STEP + Vector3.new(0, slope * STEP, 0)
			local k = math.min(1, i / math.min(n, 10))
			width = w0 + (toWidth - w0) * k
			height = h0 + (toHeight - h0) * k
			table.insert(self.nodes, { p = pos, yaw = yaw, w = width, h = height, kind = kind })
		end
		local s1 = length()
		table.insert(self.pieces, { s0 = s0, s1 = s1, kind = kind })
		return s0, s1
	end

	local function sign(s: number, kind: string, text: string)
		table.insert(self.signs, { s = s, kind = kind, text = text })
	end

	local function boulder(s: number, offset: number)
		table.insert(self.hazards, { s = s, len = 8, offset = offset, radius = 4, kind = "Boulder" })
		sign(s - 520, "Warning", "ROCK!")
	end

	-- the surface: an open red-rock gorge, gentle bends, already going down
	while length() < Config.SURFACE_MILES * SPM - 300 do
		local turn = rng:NextNumber(18, 36) * (rng:NextNumber() < 0.5 and -1 or 1)
		local a, b = run(rng:NextInteger(320, 460), turn, -0.12, 64, 0, "Gorge")
		if b - a > 300 then
			boulder(a + rng:NextNumber(150, b - a - 60), rng:NextNumber(-0.25, 0.25) * 64)
		end
	end
	run(260, 0, -0.18, 52, 0, "Gorge")

	-- The Drop: one and a half turns down the inside of the sinkhole shaft
	sign(length() - 300, "Drop", "THE DROP")
	local dropDir = rng:NextNumber() < 0.5 and -1 or 1
	local d0, d1 = run(1150, 540 * dropDir, -0.3, T.WIDTH, T.HEIGHT, "Drop")
	self.drop = { s0 = d0, s1 = d1, dir = dropDir }

	-- zone structure (GDD 9.0): a short dig, then the zone's giant cavern for most
	-- of the zone, then a short dig out to the Waystation
	local hallStart = length() + Config.DIG_IN
	local hallEnd = Config.HALL_UNTIL_MILE * SPM
	local stopIndex = 1
	local sinceCavern = 0
	while length() < total do
		local s = length()
		local stop = Config.STOPS[stopIndex]
		if s >= hallStart and s < hallEnd then
			-- the cavern: the route runs on bridges and ledges through the open space
			if not self.hall then
				self.hall = { s0 = s }
			end
			if stop and stop.kind ~= "waystation" and s >= stop.mile * SPM - 140 then
				-- a stop on an outcrop platform looking out over the cavern
				stopIndex += 1
				local a, b = run(220, rng:NextNumber(-10, 10), 0, 110, 0, "HallStop")
				table.insert(self.stops, { s = (a + b) / 2, name = stop.name, kind = stop.kind, hall = true })
				run(40, 0, -0.05, 54, 0, "Hall")
			elseif rng:NextNumber() < 0.16 then
				-- a ramp down to a lower level of the cavern
				sign(s - 600, "Chute", "STEEP DROP!")
				run(rng:NextInteger(180, 260), rng:NextNumber(-20, 20), -0.38, 54, 0, "HallRamp")
			else
				local turn = rng:NextNumber(25, 60) * (rng:NextNumber() < 0.5 and -1 or 1)
				local a, b = run(rng:NextInteger(420, 680), turn, -rng:NextNumber(0.05, 0.12), 54, 0, "Hall")
				if rng:NextNumber() < 0.4 then
					boulder(a + rng:NextNumber(100, b - a - 60), rng:NextNumber(-0.3, 0.3) * 54)
				end
			end
			if length() >= hallEnd then
				self.hall.s1 = length()
			end
		elseif stop and s >= stop.mile * SPM - 260 then
			-- a stop chamber: wide, high and flat; the rig stops dead in the middle
			stopIndex += 1
			run(60, 0, -0.04, 110, 46, "StopIn")
			local a, b = run(200, rng:NextNumber(-12, 12), 0, 110, 46, "Stop")
			table.insert(self.stops, { s = (a + b) / 2, name = stop.name, kind = stop.kind })
			run(60, 0, -0.04, T.WIDTH, T.HEIGHT, "StopOut")
			sinceCavern = 0
		elseif sinceCavern > 1500 and rng:NextNumber() < 0.5 then
			-- a cavern breaks up the enclosure, like the reference's wide pools
			local a, b = run(rng:NextInteger(300, 380), rng:NextNumber(-20, 20), -0.06, 120, 64, "Cavern")
			table.insert(self.caverns, { s0 = a, s1 = b })
			run(50, 0, -0.12, T.WIDTH, T.HEIGHT, "Tunnel")
			sinceCavern = 0
		else
			local r = rng:NextNumber()
			local a, b
			if r < 0.22 then
				-- a chute: steep and fast, signposted well ahead
				local L = rng:NextInteger(160, 260)
				sign(s - 650, "Chute", "STEEP DROP!")
				a, b = run(L, rng:NextNumber(-25, 25), -0.45, T.WIDTH, T.HEIGHT, "Chute")
			else
				local turn = rng:NextNumber(25, 65) * (rng:NextNumber() < 0.5 and -1 or 1)
				a, b = run(rng:NextInteger(420, 720), turn, -rng:NextNumber(0.15, 0.25), T.WIDTH + rng:NextNumber(-6, 12), T.HEIGHT + rng:NextNumber(-4, 10), "Tunnel")
				if rng:NextNumber() < 0.45 then
					-- a hard rock band across the bore: grinding, shake, a hit
					local hs = a + rng:NextNumber(120, b - a - 80)
					table.insert(self.hazards, { s = hs, len = 10, offset = 0, radius = 99, kind = "RockBand" })
					sign(hs - 560, "Warning", "HARD ROCK!")
				end
				if rng:NextNumber() < 0.5 then
					boulder(a + rng:NextNumber(100, b - a - 60), rng:NextNumber(-0.3, 0.3) * T.WIDTH)
				end
			end
			sinceCavern += b - a
		end
	end
	self.length = length()
	return self
end

-- the route's frame at distance s: position on the floor's centre line,
-- facing down the route (pitched with the slope), the lane width and height there
function Route:sample(s: number): (CFrame, number, number, number)
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
	local h = a.h + (b.h - a.h) * t
	local d = b.p - a.p
	local slope = d.Y / math.max(0.001, Vector3.new(d.X, 0, d.Z).Magnitude)
	return CFrame.lookAt(p, p + d.Unit), w, slope, h
end

function Route:kindAt(s: number): string
	local i = math.clamp(math.floor(s / Route.STEP) + 1, 1, #self.nodes)
	return self.nodes[i].kind
end

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

function Route:nextStop(s: number)
	for _, st in self.stops do
		if st.s > s + 1 then
			return st
		end
	end
	return nil
end

return Route
